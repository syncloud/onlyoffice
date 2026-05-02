# onlyoffice

[ONLYOFFICE Document Server](https://github.com/ONLYOFFICE/DocumentServer) packaged as a [Syncloud](https://syncloud.org) app.

ONLYOFFICE Document Server is an open-source online office suite providing collaborative editing of text documents, spreadsheets and presentations. This package bundles the Community Edition together with PostgreSQL, Redis, RabbitMQ and nginx, and exposes a JWT-secured endpoint that other apps (Nextcloud, generic web integrations) can point at.

## Build

```
./build.sh
```

CI: [![Build Status](https://ci.syncloud.org/api/badges/syncloud/onlyoffice/status.svg)](https://ci.syncloud.org/syncloud/onlyoffice)
