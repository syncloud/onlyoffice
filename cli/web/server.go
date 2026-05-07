package web

import (
	"context"
	"crypto/tls"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net"
	"net/http"
	"os"
	"strings"

	"go.uber.org/zap"
)

type Config struct {
	Listen      string
	BaseURL     string
	JwtSecret   string
	FilesDir    string
	TemplateDir string
	OIDC        OIDCConfig
}

type Server struct {
	cfg      Config
	files    *FileStore
	assets   fs.FS
	logger   *zap.Logger
	auth     *OIDCAuth
	sessions *SessionStore
}

func NewServer(ctx context.Context, cfg Config, assets fs.FS, logger *zap.Logger) (*Server, error) {
	files, err := NewFileStore(cfg.FilesDir, cfg.TemplateDir)
	if err != nil {
		return nil, err
	}
	sessions := NewSessionStore(sessionTTL)
	auth, err := NewOIDCAuth(ctx, cfg.OIDC, sessions, logger)
	if err != nil {
		return nil, err
	}
	return &Server{cfg: cfg, files: files, assets: assets, logger: logger, auth: auth, sessions: sessions}, nil
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/oidc/start", s.auth.StartHandler)
	mux.HandleFunc("/oidc/callback", s.auth.CallbackHandler)
	mux.HandleFunc("/oidc/logout", s.auth.LogoutHandler)
	mux.HandleFunc("/api/file/", s.handleFileBytes)
	mux.HandleFunc("/api/callback/", s.handleCallback)
	mux.Handle("/api/files", s.auth.JSONMiddleware(http.HandlerFunc(s.handleFiles)))
	mux.Handle("/api/files/", s.auth.JSONMiddleware(http.HandlerFunc(s.handleFile)))
	mux.Handle("/api/secret", s.auth.JSONMiddleware(http.HandlerFunc(s.handleSecret)))
	mux.Handle("/api/editor-config", s.auth.JSONMiddleware(http.HandlerFunc(s.handleEditorConfig)))
	mux.Handle("/", s.auth.Middleware(s.spaHandler()))
	return mux
}

func (s *Server) Listen() error {
	if strings.HasPrefix(s.cfg.Listen, "/") {
		_ = os.Remove(s.cfg.Listen)
		l, err := net.Listen("unix", s.cfg.Listen)
		if err != nil {
			return err
		}
		_ = os.Chmod(s.cfg.Listen, 0o660)
		s.logger.Info("web listening on unix", zap.String("path", s.cfg.Listen))
		return http.Serve(l, s.Routes())
	}
	s.logger.Info("web listening on tcp", zap.String("addr", s.cfg.Listen))
	return http.ListenAndServe(s.cfg.Listen, s.Routes())
}

func (s *Server) user(r *http.Request) string {
	if sess, ok := SessionFromContext(r.Context()); ok && sess.Username != "" {
		return sess.Username
	}
	if u := r.Header.Get("Remote-User"); u != "" {
		return u
	}
	return "user"
}

type errResp struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, errResp{Error: msg})
}

func (s *Server) handleFiles(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		list, err := s.files.List()
		if err != nil {
			writeErr(w, 500, err.Error())
			return
		}
		writeJSON(w, 200, list)
	case http.MethodPost:
		var req struct {
			Name string `json:"name"`
			Kind string `json:"kind"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeErr(w, 400, err.Error())
			return
		}
		if err := s.files.NewFromTemplate(req.Name, req.Kind); err != nil {
			writeErr(w, 400, err.Error())
			return
		}
		writeJSON(w, 201, map[string]string{"name": req.Name})
	default:
		w.WriteHeader(405)
	}
}

func (s *Server) handleFile(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(r.URL.Path, "/api/files/")
	switch r.Method {
	case http.MethodPut, http.MethodPost:
		if err := s.files.Upload(name, r.Body); err != nil {
			writeErr(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]string{"name": name})
	case http.MethodDelete:
		if err := s.files.Delete(name); err != nil {
			writeErr(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]string{"name": name})
	default:
		w.WriteHeader(405)
	}
}

func (s *Server) handleSecret(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(405)
		return
	}
	writeJSON(w, 200, map[string]string{"jwt_secret": s.cfg.JwtSecret})
}

func (s *Server) handleEditorConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		w.WriteHeader(405)
		return
	}
	file := r.URL.Query().Get("file")
	if file == "" {
		writeErr(w, 400, "file required")
		return
	}
	viewport := r.URL.Query().Get("type")
	if viewport == "" {
		viewport = "desktop"
	}
	info, err := s.files.Stat(file)
	if err != nil {
		writeErr(w, 404, err.Error())
		return
	}
	cfg, err := BuildEditorConfig(s.cfg.JwtSecret, s.cfg.BaseURL, file, s.user(r), viewport, info.ModTime().UnixNano())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, cfg)
}

func (s *Server) handleFileBytes(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(r.URL.Path, "/api/file/")
	token := r.URL.Query().Get("token")
	if err := VerifyFileToken(s.cfg.JwtSecret, token, name); err != nil {
		writeErr(w, 403, "invalid token")
		return
	}
	f, err := s.files.Open(name)
	if err != nil {
		writeErr(w, 404, err.Error())
		return
	}
	defer f.Close()
	w.Header().Set("Content-Type", "application/octet-stream")
	_, _ = io.Copy(w, f)
}

func (s *Server) handleCallback(w http.ResponseWriter, r *http.Request) {
	name := strings.TrimPrefix(r.URL.Path, "/api/callback/")
	token := r.URL.Query().Get("token")
	if err := VerifyFileToken(s.cfg.JwtSecret, token, name); err != nil {
		writeErr(w, 403, "invalid token")
		return
	}
	var body struct {
		Status int    `json:"status"`
		URL    string `json:"url"`
		Key    string `json:"key"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, 200, map[string]int{"error": 0})
		return
	}
	if body.Status == 2 || body.Status == 3 || body.Status == 6 || body.Status == 7 {
		if body.URL != "" {
			if err := s.fetchAndSave(body.URL, name); err != nil {
				s.logger.Error("save failed", zap.String("file", name), zap.Error(err))
				writeJSON(w, 200, map[string]int{"error": 1})
				return
			}
		}
	}
	writeJSON(w, 200, map[string]int{"error": 0})
}

var insecureClient = &http.Client{
	Transport: &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}},
}

func (s *Server) fetchAndSave(url, name string) error {
	resp, err := insecureClient.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("download status %d", resp.StatusCode)
	}
	return s.files.Save(name, resp.Body)
}

//go:embed all:assets
var defaultAssets embed.FS

func (s *Server) spaHandler() http.Handler {
	root := s.assets
	if root == nil {
		sub, _ := fs.Sub(defaultAssets, "assets")
		root = sub
	}
	if root == nil {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "no frontend assets bundled", 404)
		})
	}
	fileServer := http.FileServer(http.FS(root))
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p := strings.TrimPrefix(r.URL.Path, "/")
		if p == "" {
			p = "index.html"
		}
		if _, err := fs.Stat(root, p); err != nil {
			r2 := r.Clone(r.Context())
			r2.URL.Path = "/"
			fileServer.ServeHTTP(w, r2)
			return
		}
		fileServer.ServeHTTP(w, r)
	})
}
