local name = 'onlyoffice';
local version = '10.0.0';
local node = '20-bookworm-slim';
local postgresql = '16-bookworm';
local redis = '7.4.6';
local rabbitmq = '4.1.1';
local nginx = '1.29.3-alpine3.22';
local debian = 'bookworm-slim';
local platform = '26.10.02';
local python = '3.12-slim-bookworm';
local go = '1.25';
local store_publisher = 'stable-346';
local distros = ['bookworm', 'buster'];
local archs = ['amd64', 'arm64'];

local platform_image(distro) = 'syncloud/platform-' + distro + ':' + platform;

local snapd_hold = "mkdir -p /etc/systemd/system/snapd.service.d && printf '[Service]\\nExecStartPost=/bin/sh -c \"/usr/bin/snap set system refresh.hold=2099-01-01T00:00:00Z\"\\n' > /etc/systemd/system/snapd.service.d/disable-refresh.conf && exec /sbin/init";

local build(arch) = [{
  kind: 'pipeline',
  type: 'docker',
  name: arch,
  platform: {
    os: 'linux',
    arch: arch,
  },
  steps: [
    {
      name: 'version',
      image: 'debian:' + debian,
      commands: [
        'echo $DRONE_BUILD_NUMBER > version',
      ],
    },
    {
      name: 'node',
      image: 'node:' + node,
      commands: [
        './node/build.sh',
      ],
    },
  ] + [
    {
      name: 'node test ' + distro,
      image: platform_image(distro),
      commands: [
        './node/test.sh',
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'upstream',
      image: 'node:' + node,
      commands: [
        './upstream/build.sh ' + version,
      ],
    },
    {
      name: 'documentserver',
      image: 'onlyoffice/documentserver:' + version,
      commands: [
        './documentserver/build.sh',
      ],
    },
  ] + [
    {
      name: 'documentserver test ' + distro,
      image: platform_image(distro),
      commands: [
        './documentserver/test.sh',
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'postgresql',
      image: 'postgres:' + postgresql,
      commands: [
        './postgresql/build.sh',
      ],
    },
  ] + [
    {
      name: 'postgresql test ' + distro,
      image: platform_image(distro),
      commands: [
        './postgresql/test.sh',
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'redis',
      image: 'redis:' + redis,
      commands: [
        './redis/build.sh',
      ],
    },
  ] + [
    {
      name: 'redis test ' + distro,
      image: platform_image(distro),
      commands: [
        './redis/test.sh',
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'rabbitmq',
      image: 'debian:' + debian,
      commands: [
        './rabbitmq/build.sh',
      ],
    },
  ] + [
    {
      name: 'rabbitmq test ' + distro,
      image: platform_image(distro),
      commands: [
        './rabbitmq/test.sh',
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'nginx',
      image: 'nginx:' + nginx,
      commands: [
        './nginx/build.sh',
      ],
    },
  ] + [
    {
      name: 'nginx test ' + distro,
      image: platform_image(distro),
      commands: [
        './nginx/test.sh',
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'web',
      image: 'node:' + node,
      commands: [
        'cd web',
        'timeout 300 npm ci --prefer-offline --no-audit --no-fund',
        'timeout 300 npm run build',
      ],
    },
    {
      name: 'cli',
      image: 'golang:' + go,
      commands: [
        './cli/build.sh',
      ],
    },
    {
      name: 'package',
      image: 'debian:' + debian,
      commands: [
        'VERSION=$(cat version)',
        './package.sh ' + name + ' $VERSION ',
      ],
    },
  ] + [
    {
      name: 'test ' + distro,
      image: 'python:' + python,
      commands: [
        './ci/test.sh ' + distro + ' ' + name,
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'e2e',
      image: 'mcr.microsoft.com/playwright:v1.59.1-jammy',
      environment: {
        PLAYWRIGHT_FULL_DOMAIN: 'bookworm.com',
        PLAYWRIGHT_APP_DOMAIN: 'onlyoffice.bookworm.com',
        PLAYWRIGHT_AUTH_DOMAIN: 'auth.bookworm.com',
        PLAYWRIGHT_DEVICE_HOST: 'bookworm.com',
        PLAYWRIGHT_ARTIFACT_DIR: '/drone/src/artifact',
      },
      commands: [
        './ci/e2e.sh',
      ],
    },
  ] + [
    {
      name: 'publish',
      image: 'syncloud/store-publisher:' + store_publisher,
      environment: {
        SYNCLOUD_TOKEN: { from_secret: 'SYNCLOUD_TOKEN' },
      },
      command: ['snap', '-c', '${DRONE_BRANCH}'],
      when: {
        branch: ['stable'],
        event: ['push'],
      },
    },
    {
      name: 'artifact',
      image: 'appleboy/drone-scp:1.6.4',
      settings: {
        host: { from_secret: 'artifact_host' },
        username: 'artifact',
        key: { from_secret: 'artifact_key' },
        timeout: '2m',
        command_timeout: '2m',
        target: '/home/artifact/repo/' + name + '/${DRONE_BUILD_NUMBER}-' + arch,
        source: 'artifact/*',
        strip_components: 1,
      },
      when: {
        status: ['failure', 'success'],
        event: ['push'],
      },
    },
  ],
  trigger: {
    event: [
      'push',
    ],
  },
  services: [
    {
      name: name + '.' + distro + '.com',
      image: platform_image(distro),
      privileged: true,
      entrypoint: ['/bin/sh', '-c', snapd_hold],
      volumes: [
        { name: 'dbus', path: '/var/run/dbus' },
        { name: 'dev', path: '/dev' },
      ],
    }
    for distro in distros
  ],
  volumes: [
    { name: 'dbus', host: { path: '/var/run/dbus' } },
    { name: 'dev', host: { path: '/dev' } },
  ],
}];

std.flattenArrays([build(arch) for arch in archs])
