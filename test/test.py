import os
import time
from os.path import dirname, join
from subprocess import check_output

import pytest
import requests
from requests.packages.urllib3.exceptions import InsecureRequestWarning
from syncloudlib.http import wait_for_rest
from syncloudlib.integration.hosts import add_host_alias
from syncloudlib.integration.installer import local_install

DIR = dirname(__file__)
TMP_DIR = '/tmp/syncloud'

requests.packages.urllib3.disable_warnings(InsecureRequestWarning)


@pytest.fixture(scope="session")
def module_setup(request, device, app_dir, artifact_dir):
    def module_teardown():
        device.run_ssh('top -bn 1 -w 500 -c > {0}/top.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ps auxfw > {0}/ps.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ss -tnlp > {0}/ss.log'.format(TMP_DIR), throw=False)
        device.run_ssh('netstat -nlp > {0}/netstat.log'.format(TMP_DIR), throw=False)
        device.run_ssh('journalctl | tail -2000 > {0}/journalctl.log'.format(TMP_DIR), throw=False)
        for svc in ['rabbitmq', 'docservice', 'converter', 'postgresql', 'redis', 'nginx', 'web']:
            device.run_ssh('journalctl -u snap.onlyoffice.{0} --no-pager > {1}/svc.{0}.log'.format(svc, TMP_DIR), throw=False)
        device.run_ssh('ls -la /snap/onlyoffice > {0}/snap.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/onlyoffice > {0}/var.snap.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -laR /var/snap/onlyoffice/current/secret > {0}/secret.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('grep -aH . /var/snap/onlyoffice/current/secret/rabbit-* > {0}/rabbit-ports.log'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -laR /var/snap/onlyoffice/current/cache > {0}/cache.ls.log 2>&1'.format(TMP_DIR), throw=False)
        device.run_ssh('find /var/log/onlyoffice -type f -exec ls -la {{}} \\; > {0}/oo.logs.ls.log 2>&1'.format(TMP_DIR), throw=False)
        device.run_ssh('tail -n 500 /var/log/onlyoffice/documentserver/docservice/out.log /var/log/onlyoffice/documentserver/docservice/err.log /var/log/onlyoffice/documentserver/converter/out.log /var/log/onlyoffice/documentserver/converter/err.log > {0}/oo.logs.tail.log 2>&1'.format(TMP_DIR), throw=False)
        device.run_ssh('ls -la /var/snap/onlyoffice/current/config > {0}/config.ls.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/onlyoffice/current/config/local.json > {0}/local.json.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/onlyoffice/current/config/rabbitmq.conf > {0}/rabbitmq.conf.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /var/snap/onlyoffice/current/config/nginx.conf > {0}/nginx.conf.log'.format(TMP_DIR), throw=False)
        device.run_ssh('cat /etc/hosts > {0}/hosts.log'.format(TMP_DIR), throw=False)
        device.run_ssh('dmesg | tail -300 > {0}/dmesg.log 2>&1'.format(TMP_DIR), throw=False)
        device.run_ssh('iptables -L -n -v > {0}/iptables.log 2>&1; nft list ruleset >> {0}/iptables.log 2>&1'.format(TMP_DIR), throw=False)
        device.run_ssh(
            'P=$(cat /var/snap/onlyoffice/current/secret/rabbit-port 2>/dev/null); '
            'echo "rabbit-port=$P" > {0}/rabbit-probe.log; '
            '(timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/$P && echo connect-ok || echo connect-fail") '
            '>> {0}/rabbit-probe.log 2>&1; '
            'ss -tnlp 2>&1 | grep -F ":$P " >> {0}/rabbit-probe.log'.format(TMP_DIR),
            throw=False)

        app_log_dir = join(artifact_dir, 'log')
        os.mkdir(app_log_dir)
        device.scp_from_device('{0}/*'.format(TMP_DIR), app_log_dir)
        check_output('chmod -R a+r {0}'.format(artifact_dir), shell=True)

    request.addfinalizer(module_teardown)


def test_start(module_setup, device, device_host, app, domain):
    add_host_alias(app, device_host, domain)
    device.run_ssh('date', retries=100)
    device.run_ssh('mkdir -p {0}'.format(TMP_DIR))


@pytest.mark.flaky(retries=50, delay=10)
def test_activate_device(device):
    device.run_ssh('snap set system refresh.hold=$(date -d "+90 days" -u +%Y-%m-%dT%H:%M:%SZ)')
    device.run_ssh('rm -f /var/snap/platform/current/syncloud.crt', throw=False)
    response = retry(device.activate_custom)
    assert response.status_code == 200, response.text


def test_install(app_archive_path, device_host, device_password, device):
    device.run_ssh('touch /var/snap/platform/current/CI_TEST')
    local_install(device_host, device_password, app_archive_path)


def test_healthcheck(app_domain):
    wait_for_rest(requests.session(), "https://{0}/healthcheck".format(app_domain), 200, 60)


def test_storage_change_event(device):
    device.run_ssh('snap run onlyoffice.storage-change > {0}/storage-change.log'.format(TMP_DIR))


def test_access_change_event(device):
    device.run_ssh('snap run onlyoffice.access-change > {0}/access-change.log'.format(TMP_DIR))


def test_no_redirect_loop_when_2fa_required(device, domain, app_domain, device_user, device_password):
    auth_domain = 'auth.{0}'.format(domain)

    response = device.session.post(
        'https://{0}/rest/settings/2fa'.format(domain),
        json={'enabled': True}, verify=False, timeout=120,
    )
    assert response.status_code == 200, 'enable 2fa: {0}'.format(response.text)

    try:
        wait_for_rest(requests.session(), 'https://{0}/api/health'.format(auth_domain), 200, 60)

        s = requests.session()
        s.verify = False
        first = s.post(
            'https://{0}/api/firstfactor'.format(auth_domain),
            headers={'Content-Type': 'application/json'},
            json={
                'username': device_user,
                'password': device_password,
                'keepMeLoggedIn': False,
                'requestMethod': 'GET',
                'targetURL': 'https://{0}/'.format(app_domain),
            },
            timeout=60,
        )
        assert first.status_code == 200, 'firstfactor: {0}'.format(first.text)
        assert any(c.name == 'authelia_session' for c in s.cookies), 'no authelia_session cookie set'

        r = s.get('https://{0}/'.format(app_domain), timeout=60, allow_redirects=False)

        if r.status_code in (301, 302, 303, 307, 308):
            location = r.headers.get('Location', '')
            loop_trigger = 'https://{0}/?rd='.format(auth_domain)
            assert not (location.startswith(loop_trigger) and 'rm=GET' in location), (
                'app responded with the Authelia AuthRequest redirect that loops with 2FA-required policy: {0}'.format(location)
            )
        else:
            assert r.status_code == 200, (
                'expected 200 or non-loop redirect, got {0}'.format(r.status_code)
            )
    finally:
        device.session.post(
            'https://{0}/rest/settings/2fa'.format(domain),
            json={'enabled': False}, verify=False, timeout=120,
        )


def test_remove(device, app):
    response = device.app_remove(app)
    assert response.status_code == 200, response.text


def test_reinstall(app_archive_path, device_host, device_password):
    local_install(device_host, device_password, app_archive_path)


def test_upgrade(app_archive_path, device_host, device_password):
    local_install(device_host, device_password, app_archive_path)


def retry(method, retries=10):
    attempt = 0
    exception = None
    while attempt < retries:
        try:
            return method()
        except Exception as e:
            exception = e
            print('error (attempt {0}/{1}): {2}'.format(attempt + 1, retries, str(e)))
            time.sleep(5)
        attempt += 1
    raise exception
