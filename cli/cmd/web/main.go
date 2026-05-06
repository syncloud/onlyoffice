package main

import (
	"context"
	"fmt"
	"hooks/installer"
	"hooks/web"
	"os"
	"path"

	"github.com/spf13/cobra"
	"github.com/syncloud/golib/log"
)

func main() {
	logger := log.Logger()

	cmd := &cobra.Command{
		Use:          "web",
		SilenceUsage: true,
		RunE: func(cmd *cobra.Command, args []string) error {
			inst := installer.New(logger)
			secret, err := inst.JwtSecret()
			if err != nil {
				return err
			}
			oidcSecret, err := inst.OIDCClientSecret()
			if err != nil {
				return err
			}
			baseURL := os.Getenv("ONLYOFFICE_BASE_URL")
			cfg := web.Config{
				Listen:      path.Join(installer.DataDir, "run", "web.sock"),
				BaseURL:     baseURL,
				JwtSecret:   secret,
				FilesDir:    path.Join("/data", installer.App, "files"),
				TemplateDir: path.Join(installer.AppDir, "samples"),
				OIDC: web.OIDCConfig{
					Issuer:       os.Getenv("ONLYOFFICE_OIDC_ISSUER"),
					ClientID:     os.Getenv("ONLYOFFICE_OIDC_CLIENT_ID"),
					ClientSecret: oidcSecret,
					RedirectURL:  baseURL + installer.AppOIDCRedirect,
					BaseURL:      baseURL,
				},
			}
			s, err := web.NewServer(context.Background(), cfg, nil, logger)
			if err != nil {
				return err
			}
			return s.Listen()
		},
	}

	if err := cmd.Execute(); err != nil {
		fmt.Print(err)
		os.Exit(1)
	}
}
