local name = 'onlyoffice';
local version = '9.3.1.2';
local source_branch = 'master';
local node = '20-bookworm-slim';
local postgresql = '16-bookworm';
local redis = '7.4.6';
local rabbitmq = '4.1.1';
local nginx = '1.29.3-alpine3.22';
local debian = 'bookworm-slim';
local platform = '26.04.10';
local python = '3.12-slim-bookworm';
local go = '1.25';
local deployer = 'https://github.com/syncloud/store/releases/download/4/syncloud-release';
local distros = ['bookworm', 'buster'];
local archs = ['amd64', 'arm64'];

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
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
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
        './upstream/build.sh ' + source_branch,
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
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
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
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
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
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
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
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
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
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
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
        'npm install --no-audit --no-fund',
        'npm run build',
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
        'cd test',
        './deps.sh',
        'py.test -x -s test.py --distro=' + distro + ' --ver=$DRONE_BUILD_NUMBER --app=' + name,
      ],
    }
    for distro in distros
  ] + [
    {
      name: 'e2e',
      image: 'mcr.microsoft.com/playwright:v1.48.2-jammy',
      environment: {
        PLAYWRIGHT_FULL_DOMAIN: 'bookworm.com',
        PLAYWRIGHT_APP_DOMAIN: 'onlyoffice.bookworm.com',
        PLAYWRIGHT_AUTH_DOMAIN: 'auth.bookworm.com',
        PLAYWRIGHT_DEVICE_HOST: 'bookworm.com',
        PLAYWRIGHT_ARTIFACT_DIR: '/drone/src/artifact',
      },
      commands: [
        'apt-get update -qq && apt-get install -y -qq sshpass openssh-client unzip',
        'IP=$(getent hosts onlyoffice.bookworm.com | awk \'{print $1}\')',
        'echo "$IP bookworm.com auth.bookworm.com" >> /etc/hosts',
        'cd web/e2e',
        'npm ci --no-audit --no-fund',
        'npx playwright test --project=desktop',
        'npx playwright test --project=mobile',
      ],
    },
  ] + [
    {
      name: 'upload',
      image: 'debian:' + debian,
      environment: {
        AWS_ACCESS_KEY_ID: { from_secret: 'AWS_ACCESS_KEY_ID' },
        AWS_SECRET_ACCESS_KEY: { from_secret: 'AWS_SECRET_ACCESS_KEY' },
        SYNCLOUD_TOKEN: { from_secret: 'SYNCLOUD_TOKEN' },
      },
      commands: [
        'PACKAGE=$(cat package.name)',
        'apt update && apt install -y wget',
        'wget ' + deployer + '-' + arch + ' -O release --progress=dot:giga',
        'chmod +x release',
        './release publish -f $PACKAGE -b $DRONE_BRANCH',
      ],
      when: {
        branch: ['stable', 'master'],
        event: ['push'],
      },
    },
    {
      name: 'promote',
      image: 'debian:' + debian,
      environment: {
        AWS_ACCESS_KEY_ID: { from_secret: 'AWS_ACCESS_KEY_ID' },
        AWS_SECRET_ACCESS_KEY: { from_secret: 'AWS_SECRET_ACCESS_KEY' },
        SYNCLOUD_TOKEN: { from_secret: 'SYNCLOUD_TOKEN' },
      },
      commands: [
        'apt update && apt install -y wget',
        'wget ' + deployer + '-' + arch + ' -O release --progress=dot:giga',
        'chmod +x release',
        './release promote -n ' + name + ' -a $(dpkg --print-architecture)',
      ],
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
      'pull_request',
    ],
  },
  services: [
    {
      name: name + '.' + distro + '.com',
      image: 'syncloud/platform-' + distro + '-' + arch + ':' + platform,
      privileged: true,
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
