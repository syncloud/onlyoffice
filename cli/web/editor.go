package web

import (
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

type EditorConfig struct {
	Document      Document      `json:"document"`
	DocumentType  string        `json:"documentType"`
	EditorConfig  InnerConfig   `json:"editorConfig"`
	Token         string        `json:"token"`
	Type          string        `json:"type"`
	Width         string        `json:"width,omitempty"`
	Height        string        `json:"height,omitempty"`
}

type Document struct {
	FileType   string             `json:"fileType"`
	Key        string             `json:"key"`
	Title      string             `json:"title"`
	URL        string             `json:"url"`
	Permissions DocumentPermissions `json:"permissions"`
}

type DocumentPermissions struct {
	Edit     bool `json:"edit"`
	Download bool `json:"download"`
	Print    bool `json:"print"`
}

type InnerConfig struct {
	CallbackURL string     `json:"callbackUrl"`
	Lang        string     `json:"lang,omitempty"`
	Mode        string     `json:"mode"`
	User        EditorUser `json:"user"`
	Customization Customization `json:"customization,omitempty"`
}

type EditorUser struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type Customization struct {
	Autosave   bool `json:"autosave"`
	ForceSave  bool `json:"forcesave"`
}

func BuildEditorConfig(secret, baseURL, file, user, viewport string, mtimeNanos int64) (map[string]any, error) {
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(file), "."))
	docType := DocType(file)

	fileToken, err := SignFileToken(secret, file, time.Hour)
	if err != nil {
		return nil, err
	}

	docKey := docKey(file, mtimeNanos)
	fileURL := fmt.Sprintf("%s/api/file/%s?token=%s", baseURL, file, fileToken)
	cbURL := fmt.Sprintf("%s/api/callback/%s?token=%s", baseURL, file, fileToken)

	cfg := map[string]any{
		"document": map[string]any{
			"fileType": ext,
			"key":      docKey,
			"title":    file,
			"url":      fileURL,
			"permissions": map[string]any{
				"edit":     true,
				"download": true,
				"print":    true,
			},
		},
		"documentType": docType,
		"editorConfig": map[string]any{
			"callbackUrl": cbURL,
			"mode":        "edit",
			"user": map[string]any{
				"id":   user,
				"name": user,
			},
			"customization": map[string]any{
				"autosave":  true,
				"forcesave": true,
			},
		},
		"type": viewport,
	}

	signed, err := SignDocServerJwt(secret, cfg, 5*time.Minute)
	if err != nil {
		return nil, err
	}
	cfg["token"] = signed
	return cfg, nil
}

func docKey(file string, mtimeNanos int64) string {
	h := sha1.Sum([]byte(fmt.Sprintf("%s:%d", file, mtimeNanos)))
	return hex.EncodeToString(h[:])
}
