package web

import (
	"crypto/rand"
	"encoding/hex"
	"sync"
	"time"
)

type Session struct {
	ID        string
	Username  string
	Email     string
	Name      string
	ExpiresAt time.Time
}

type SessionStore struct {
	mu       sync.Mutex
	sessions map[string]Session
	ttl      time.Duration
}

func NewSessionStore(ttl time.Duration) *SessionStore {
	return &SessionStore{sessions: map[string]Session{}, ttl: ttl}
}

func (s *SessionStore) Create(username, email, name string) (Session, error) {
	id, err := randomID(32)
	if err != nil {
		return Session{}, err
	}
	sess := Session{
		ID:        id,
		Username:  username,
		Email:     email,
		Name:      name,
		ExpiresAt: time.Now().Add(s.ttl),
	}
	s.mu.Lock()
	s.sessions[id] = sess
	s.mu.Unlock()
	return sess, nil
}

func (s *SessionStore) Get(id string) (Session, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	sess, ok := s.sessions[id]
	if !ok {
		return Session{}, false
	}
	if time.Now().After(sess.ExpiresAt) {
		delete(s.sessions, id)
		return Session{}, false
	}
	return sess, true
}

func (s *SessionStore) Delete(id string) {
	s.mu.Lock()
	delete(s.sessions, id)
	s.mu.Unlock()
}

func randomID(n int) (string, error) {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
