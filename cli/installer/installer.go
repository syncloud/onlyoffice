package installer

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"path"
	"strconv"

	cp "github.com/otiai10/copy"
	"github.com/syncloud/golib/config"
	"github.com/syncloud/golib/linux"
	"github.com/syncloud/golib/platform"
	"go.uber.org/zap"
)

const (
	App       = "onlyoffice"
	AppDir    = "/snap/onlyoffice/current"
	DataDir   = "/var/snap/onlyoffice/current"
	CommonDir = "/var/snap/onlyoffice/common"
)

type Variables struct {
	Domain           string
	Url              string
	DataDir          string
	AppDir           string
	CommonDir        string
	DatabaseDir      string
	JwtSecret        string
	DbName           string
	DbUser           string
	DbPassword       string
	AuthUrl          string
	OIDCClientID     string
	OIDCClientSecret string
	OIDCRedirect     string
	RabbitPort       int
	RabbitDistPort   int
	RabbitEpmdPort   int
}

type Installer struct {
	newVersionFile     string
	currentVersionFile string
	configDir          string
	platformClient     *platform.Client
	database           *Database
	installFile        string
	executor           *Executor
	logger             *zap.Logger
}

func New(logger *zap.Logger) *Installer {
	configDir := path.Join(DataDir, "config")
	executor := NewExecutor(logger)
	return &Installer{
		newVersionFile:     path.Join(AppDir, "version"),
		currentVersionFile: path.Join(DataDir, "version"),
		configDir:          configDir,
		platformClient:     platform.New(),
		database:           NewDatabase(AppDir, DataDir, configDir, App, executor, logger),
		installFile:        path.Join(CommonDir, "installed"),
		executor:           executor,
		logger:             logger,
	}
}

func (i *Installer) Install() error {
	if err := i.UpdateConfigs(); err != nil {
		return err
	}
	if err := i.database.Init(); err != nil {
		return err
	}
	if err := i.database.InitConfig(); err != nil {
		return err
	}
	return nil
}

func (i *Installer) Configure() error {
	if i.IsInstalled() {
		if err := i.Upgrade(); err != nil {
			return err
		}
	} else {
		if err := i.Initialize(); err != nil {
			return err
		}
	}

	if err := linux.CreateMissingDirs(path.Join(DataDir, "tmp")); err != nil {
		return err
	}

	if err := i.FixPermissions(); err != nil {
		return err
	}

	return i.UpdateVersion()
}

func (i *Installer) IsInstalled() bool {
	_, err := os.Stat(i.installFile)
	return err == nil
}

func (i *Installer) Initialize() error {
	if err := i.StorageChange(); err != nil {
		return err
	}

	if err := i.database.Execute(
		"postgres",
		fmt.Sprintf("ALTER USER %s WITH PASSWORD '%s'", App, App),
	); err != nil {
		return err
	}
	if err := i.database.createDbIfMissing(App); err != nil {
		return err
	}
	if err := i.database.Execute("postgres", fmt.Sprintf("GRANT CREATE ON SCHEMA public TO %s", App)); err != nil {
		return err
	}

	return i.MarkInstalled()
}

func (i *Installer) MarkInstalled() error {
	return os.WriteFile(i.installFile, []byte("installed"), 0644)
}

func (i *Installer) Upgrade() error {
	if err := i.StorageChange(); err != nil {
		return err
	}
	if err := i.database.createDbIfMissing(App); err != nil {
		return err
	}
	return nil
}

func (i *Installer) PreRefresh() error {
	if err := i.database.Backup(); err != nil {
		i.logger.Warn("database backup failed, refresh will proceed without it", zap.Error(err))
	}
	return nil
}

func (i *Installer) PostRefresh() error {
	if err := i.UpdateConfigs(); err != nil {
		return err
	}
	if err := i.ClearVersion(); err != nil {
		return err
	}
	return i.FixPermissions()
}

func (i *Installer) AccessChange() error {
	return i.UpdateConfigs()
}

func (i *Installer) StorageChange() error {
	storageDir, err := i.platformClient.InitStorage(App, App)
	if err != nil {
		return err
	}
	if err := linux.CreateMissingDirs(
		path.Join(storageDir, "data"),
		path.Join(storageDir, "log"),
		path.Join(storageDir, "cache"),
	); err != nil {
		return err
	}
	return linux.Chown(storageDir, App)
}

func (i *Installer) ClearVersion() error {
	return os.RemoveAll(i.currentVersionFile)
}

func (i *Installer) UpdateVersion() error {
	return cp.Copy(i.newVersionFile, i.currentVersionFile)
}

func (i *Installer) JwtSecret() (string, error) {
	return getOrCreateSecret(path.Join(DataDir, "secret", "jwt"))
}

func (i *Installer) OIDCClientSecret() (string, error) {
	data, err := os.ReadFile(path.Join(DataDir, "secret", "oidc-client-secret"))
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func (i *Installer) StorageDir() (string, error) {
	return i.platformClient.InitStorage(App, App)
}

func (i *Installer) BaseURL() string {
	url, err := i.platformClient.GetAppUrl(App)
	if err != nil {
		return ""
	}
	return url
}

func (i *Installer) UpdateConfigs() error {
	if err := linux.CreateUser(App); err != nil {
		return err
	}
	if err := i.StorageChange(); err != nil {
		return err
	}
	if err := linux.CreateMissingDirs(
		path.Join(DataDir, "secret"),
		path.Join(DataDir, "run"),
		path.Join(DataDir, "tmp"),
		path.Join(DataDir, "cache"),
		path.Join(DataDir, "cache", "files"),
		path.Join(DataDir, "rabbitmq"),
		path.Join(DataDir, "rabbitmq", "log"),
		path.Join(DataDir, "rabbitmq", "mnesia"),
	); err != nil {
		return err
	}

	domain, err := i.platformClient.GetAppDomainName(App)
	if err != nil {
		return err
	}
	url, err := i.platformClient.GetAppUrl(App)
	if err != nil {
		return err
	}
	jwtSecret, err := i.JwtSecret()
	if err != nil {
		return err
	}

	authUrl, err := i.platformClient.GetAppUrl("auth")
	if err != nil {
		return err
	}

	oidcSecret, err := i.platformClient.RegisterOIDCClient(App, AppOIDCRedirect, false, TokenEndpointAuthMethod)
	if err != nil {
		return fmt.Errorf("OIDC client registration: %w", err)
	}
	if err := os.WriteFile(path.Join(DataDir, "secret", "oidc-client-secret"), []byte(oidcSecret), 0600); err != nil {
		return fmt.Errorf("persist OIDC client secret: %w", err)
	}

	rabbitPort, err := getOrCreatePort(path.Join(DataDir, "secret", "rabbit-port"))
	if err != nil {
		return err
	}
	rabbitDistPort, err := getOrCreatePort(path.Join(DataDir, "secret", "rabbit-dist-port"))
	if err != nil {
		return err
	}
	rabbitEpmdPort, err := getOrCreatePort(path.Join(DataDir, "secret", "rabbit-epmd-port"))
	if err != nil {
		return err
	}

	variables := Variables{
		Domain:           domain,
		Url:              url,
		DataDir:          DataDir,
		AppDir:           AppDir,
		CommonDir:        CommonDir,
		DatabaseDir:      i.database.DatabaseDir(),
		JwtSecret:        jwtSecret,
		DbName:           App,
		DbUser:           App,
		DbPassword:       App,
		AuthUrl:          authUrl,
		OIDCClientID:     App,
		OIDCClientSecret: oidcSecret,
		OIDCRedirect:     url + AppOIDCRedirect,
		RabbitPort:       rabbitPort,
		RabbitDistPort:   rabbitDistPort,
		RabbitEpmdPort:   rabbitEpmdPort,
	}

	if err := config.Generate(
		path.Join(AppDir, "config"),
		path.Join(DataDir, "config"),
		variables,
	); err != nil {
		return err
	}

	return i.FixPermissions()
}

func (i *Installer) FixPermissions() error {
	storageDir, err := i.platformClient.InitStorage(App, App)
	if err != nil {
		return err
	}
	if err := linux.Chown(DataDir, App); err != nil {
		return err
	}
	if err := linux.Chown(CommonDir, App); err != nil {
		return err
	}
	return linux.Chown(storageDir, App)
}

func (i *Installer) BackupPreStop() error {
	return i.PreRefresh()
}

func (i *Installer) RestorePreStart() error {
	return i.PostRefresh()
}

func (i *Installer) RestorePostStart() error {
	return i.Configure()
}

func getOrCreateSecret(file string) (string, error) {
	if _, err := os.Stat(file); err == nil {
		content, err := os.ReadFile(file)
		if err != nil {
			return "", err
		}
		return string(content), nil
	}
	if err := os.MkdirAll(path.Dir(file), 0750); err != nil {
		return "", err
	}
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	secret := hex.EncodeToString(buf)
	if err := os.WriteFile(file, []byte(secret), 0600); err != nil {
		return "", err
	}
	return secret, nil
}

func getOrCreatePort(file string) (int, error) {
	if data, err := os.ReadFile(file); err == nil {
		port, err := strconv.Atoi(string(data))
		if err == nil {
			return port, nil
		}
	}
	if err := os.MkdirAll(path.Dir(file), 0750); err != nil {
		return 0, err
	}
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}
	port := l.Addr().(*net.TCPAddr).Port
	_ = l.Close()
	if err := os.WriteFile(file, []byte(strconv.Itoa(port)), 0600); err != nil {
		return 0, err
	}
	return port, nil
}
