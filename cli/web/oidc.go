package web

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/coreos/go-oidc/v3/oidc"
	"go.uber.org/zap"
	"golang.org/x/oauth2"
)

const (
	sessionCookie = "onlyoffice_session"
	stateCookie   = "onlyoffice_oidc_state"
	stateMaxAge   = 10 * 60
	sessionTTL    = 12 * time.Hour
)

type OIDCConfig struct {
	Issuer       string
	ClientID     string
	ClientSecret string
	RedirectURL  string
	BaseURL      string
}

type OIDCAuth struct {
	cfg      OIDCConfig
	provider *oidc.Provider
	verifier *oidc.IDTokenVerifier
	oauth2   *oauth2.Config
	sessions *SessionStore
	logger   *zap.Logger
}

func NewOIDCAuth(ctx context.Context, cfg OIDCConfig, sessions *SessionStore, logger *zap.Logger) (*OIDCAuth, error) {
	provider, err := oidc.NewProvider(ctx, cfg.Issuer)
	if err != nil {
		return nil, fmt.Errorf("oidc discovery: %w", err)
	}
	oauth2cfg := &oauth2.Config{
		ClientID:     cfg.ClientID,
		ClientSecret: cfg.ClientSecret,
		Endpoint:     provider.Endpoint(),
		RedirectURL:  cfg.RedirectURL,
		Scopes:       []string{oidc.ScopeOpenID, "email", "profile", "groups"},
	}
	verifier := provider.Verifier(&oidc.Config{ClientID: cfg.ClientID})
	return &OIDCAuth{
		cfg:      cfg,
		provider: provider,
		verifier: verifier,
		oauth2:   oauth2cfg,
		sessions: sessions,
		logger:   logger,
	}, nil
}

func (a *OIDCAuth) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sess, ok := a.sessionFromRequest(r)
		if !ok {
			a.startLogin(w, r)
			return
		}
		ctx := context.WithValue(r.Context(), sessionContextKey{}, sess)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (a *OIDCAuth) JSONMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sess, ok := a.sessionFromRequest(r)
		if !ok {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		ctx := context.WithValue(r.Context(), sessionContextKey{}, sess)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

type sessionContextKey struct{}

func SessionFromContext(ctx context.Context) (Session, bool) {
	v := ctx.Value(sessionContextKey{})
	if v == nil {
		return Session{}, false
	}
	s, ok := v.(Session)
	return s, ok
}

func (a *OIDCAuth) sessionFromRequest(r *http.Request) (Session, bool) {
	c, err := r.Cookie(sessionCookie)
	if err != nil {
		return Session{}, false
	}
	return a.sessions.Get(c.Value)
}

type stateBlob struct {
	State        string `json:"state"`
	Nonce        string `json:"nonce"`
	CodeVerifier string `json:"verifier"`
	Return       string `json:"return"`
}

func (a *OIDCAuth) startLogin(w http.ResponseWriter, r *http.Request) {
	state, err := randomID(16)
	if err != nil {
		http.Error(w, "state gen failed", 500)
		return
	}
	nonce, err := randomID(16)
	if err != nil {
		http.Error(w, "nonce gen failed", 500)
		return
	}
	verifier, err := randomID(32)
	if err != nil {
		http.Error(w, "verifier gen failed", 500)
		return
	}
	returnTo := r.URL.RequestURI()
	if r.Method != http.MethodGet || strings.HasPrefix(returnTo, "/oidc/") {
		returnTo = "/"
	}
	blob := stateBlob{State: state, Nonce: nonce, CodeVerifier: verifier, Return: returnTo}
	encoded, err := encodeState(blob)
	if err != nil {
		http.Error(w, "state encode failed", 500)
		return
	}
	http.SetCookie(w, &http.Cookie{
		Name:     stateCookie,
		Value:    encoded,
		Path:     "/oidc",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   stateMaxAge,
	})
	challenge := codeChallenge(verifier)
	authURL := a.oauth2.AuthCodeURL(state,
		oidc.Nonce(nonce),
		oauth2.SetAuthURLParam("code_challenge", challenge),
		oauth2.SetAuthURLParam("code_challenge_method", "S256"),
	)
	http.Redirect(w, r, authURL, http.StatusFound)
}

func (a *OIDCAuth) StartHandler(w http.ResponseWriter, r *http.Request) {
	a.startLogin(w, r)
}

func (a *OIDCAuth) CallbackHandler(w http.ResponseWriter, r *http.Request) {
	c, err := r.Cookie(stateCookie)
	if err != nil {
		http.Error(w, "missing state cookie", http.StatusBadRequest)
		return
	}
	blob, err := decodeState(c.Value)
	if err != nil {
		http.Error(w, "bad state cookie", http.StatusBadRequest)
		return
	}
	if r.URL.Query().Get("state") != blob.State {
		http.Error(w, "state mismatch", http.StatusBadRequest)
		return
	}
	code := r.URL.Query().Get("code")
	if code == "" {
		errParam := r.URL.Query().Get("error")
		http.Error(w, "missing code: "+errParam, http.StatusBadRequest)
		return
	}
	token, err := a.oauth2.Exchange(r.Context(), code,
		oauth2.SetAuthURLParam("code_verifier", blob.CodeVerifier),
	)
	if err != nil {
		a.logger.Warn("token exchange failed", zap.Error(err))
		http.Error(w, "token exchange failed", http.StatusBadGateway)
		return
	}
	rawID, ok := token.Extra("id_token").(string)
	if !ok {
		http.Error(w, "no id_token", http.StatusBadGateway)
		return
	}
	idToken, err := a.verifier.Verify(r.Context(), rawID)
	if err != nil {
		a.logger.Warn("id_token verification failed", zap.Error(err))
		http.Error(w, "id_token verification failed", http.StatusBadGateway)
		return
	}
	if idToken.Nonce != blob.Nonce {
		http.Error(w, "nonce mismatch", http.StatusBadRequest)
		return
	}
	var claims struct {
		PreferredUsername string `json:"preferred_username"`
		Email             string `json:"email"`
		Name              string `json:"name"`
		Sub               string `json:"sub"`
	}
	if err := idToken.Claims(&claims); err != nil {
		http.Error(w, "claims parse failed", http.StatusBadGateway)
		return
	}
	username := claims.PreferredUsername
	if username == "" {
		username = claims.Sub
	}
	sess, err := a.sessions.Create(username, claims.Email, claims.Name)
	if err != nil {
		http.Error(w, "session create failed", http.StatusInternalServerError)
		return
	}
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    sess.ID,
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   int(sessionTTL.Seconds()),
	})
	http.SetCookie(w, &http.Cookie{
		Name:     stateCookie,
		Value:    "",
		Path:     "/oidc",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
	returnTo := blob.Return
	if returnTo == "" || !strings.HasPrefix(returnTo, "/") {
		returnTo = "/"
	}
	http.Redirect(w, r, returnTo, http.StatusFound)
}

func (a *OIDCAuth) LogoutHandler(w http.ResponseWriter, r *http.Request) {
	c, err := r.Cookie(sessionCookie)
	if err == nil {
		a.sessions.Delete(c.Value)
	}
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Secure:   true,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
	})
	target := strings.TrimRight(a.cfg.Issuer, "/") + "/logout?rd=" + url.QueryEscape(a.cfg.BaseURL+"/")
	http.Redirect(w, r, target, http.StatusFound)
}

func encodeState(b stateBlob) (string, error) {
	raw, err := json.Marshal(b)
	if err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(raw), nil
}

func decodeState(s string) (stateBlob, error) {
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return stateBlob{}, err
	}
	var b stateBlob
	if err := json.Unmarshal(raw, &b); err != nil {
		return stateBlob{}, err
	}
	if b.State == "" || b.Nonce == "" || b.CodeVerifier == "" {
		return stateBlob{}, errors.New("incomplete state")
	}
	return b, nil
}

func codeChallenge(verifier string) string {
	sum := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(sum[:])
}
