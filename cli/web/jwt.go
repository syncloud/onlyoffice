package web

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type FileClaims struct {
	File string `json:"file"`
	jwt.RegisteredClaims
}

func SignFileToken(secret, file string, ttl time.Duration) (string, error) {
	claims := FileClaims{
		File: file,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString([]byte(secret))
}

func VerifyFileToken(secret, tokenStr, expectedFile string) error {
	t, err := jwt.ParseWithClaims(tokenStr, &FileClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil {
		return err
	}
	claims, ok := t.Claims.(*FileClaims)
	if !ok || !t.Valid {
		return errors.New("invalid token")
	}
	if claims.File != expectedFile {
		return errors.New("token file mismatch")
	}
	return nil
}

func SignDocServerJwt(secret string, payload map[string]any, ttl time.Duration) (string, error) {
	claims := jwt.MapClaims{}
	for k, v := range payload {
		claims[k] = v
	}
	claims["exp"] = time.Now().Add(ttl).Unix()
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return t.SignedString([]byte(secret))
}
