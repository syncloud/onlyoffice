package main

import (
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
			cfg := web.Config{
				Listen:      path.Join(installer.DataDir, "run", "web.sock"),
				BaseURL:     os.Getenv("ONLYOFFICE_BASE_URL"),
				JwtSecret:   secret,
				FilesDir:    path.Join("/data", installer.App, "files"),
				TemplateDir: path.Join(installer.AppDir, "samples"),
			}
			s, err := web.NewServer(cfg, nil, logger)
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
