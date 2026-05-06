package web

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type FileInfo struct {
	Name    string    `json:"name"`
	Size    int64     `json:"size"`
	ModTime time.Time `json:"mtime"`
	Type    string    `json:"type"`
}

type FileStore struct {
	Root        string
	TemplateDir string
}

func NewFileStore(root, templateDir string) (*FileStore, error) {
	if err := os.MkdirAll(root, 0o770); err != nil {
		return nil, err
	}
	return &FileStore{Root: root, TemplateDir: templateDir}, nil
}

func (fs *FileStore) safe(name string) (string, error) {
	if name == "" || strings.ContainsAny(name, "/\\") || name == "." || name == ".." {
		return "", errors.New("invalid file name")
	}
	return filepath.Join(fs.Root, name), nil
}

func (fs *FileStore) List() ([]FileInfo, error) {
	entries, err := os.ReadDir(fs.Root)
	if err != nil {
		return nil, err
	}
	out := make([]FileInfo, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		out = append(out, FileInfo{
			Name:    e.Name(),
			Size:    info.Size(),
			ModTime: info.ModTime(),
			Type:    DocType(e.Name()),
		})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ModTime.After(out[j].ModTime) })
	return out, nil
}

func (fs *FileStore) Upload(name string, src io.Reader) error {
	p, err := fs.safe(name)
	if err != nil {
		return err
	}
	f, err := os.Create(p)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, src)
	return err
}

func (fs *FileStore) Delete(name string) error {
	p, err := fs.safe(name)
	if err != nil {
		return err
	}
	return os.Remove(p)
}

func (fs *FileStore) Open(name string) (*os.File, error) {
	p, err := fs.safe(name)
	if err != nil {
		return nil, err
	}
	return os.Open(p)
}

func (fs *FileStore) Save(name string, src io.Reader) error {
	return fs.Upload(name, src)
}

func (fs *FileStore) NewFromTemplate(name, kind string) error {
	p, err := fs.safe(name)
	if err != nil {
		return err
	}
	if _, err := os.Stat(p); err == nil {
		return errors.New("file already exists")
	}
	tmpl := filepath.Join(fs.TemplateDir, "blank."+kind)
	src, err := os.Open(tmpl)
	if err != nil {
		return err
	}
	defer src.Close()
	dst, err := os.Create(p)
	if err != nil {
		return err
	}
	defer dst.Close()
	_, err = io.Copy(dst, src)
	return err
}

func DocType(name string) string {
	ext := strings.ToLower(filepath.Ext(name))
	switch ext {
	case ".docx", ".doc", ".odt", ".rtf", ".txt":
		return "word"
	case ".xlsx", ".xls", ".ods", ".csv":
		return "cell"
	case ".pptx", ".ppt", ".odp":
		return "slide"
	case ".pdf":
		return "pdf"
	}
	return "unknown"
}
