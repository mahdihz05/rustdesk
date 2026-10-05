#!/bin/sh
set -eu
test "$(id -u)" = 0
test -f /opt/abrit-control/app.py
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
if [ "$(dpkg-query -W -f='${Status}\n' python3-venv nginx 2>/dev/null | grep -c 'install ok installed')" != 2 ]; then
    apt-get -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 update
    apt-get -y --no-install-recommends install python3-venv nginx
fi
if ! id abrit-control >/dev/null 2>&1; then
    useradd --system --home-dir /var/lib/abrit-control --shell /usr/sbin/nologin abrit-control
fi
install -d -m 0750 -o abrit-control -g abrit-control /var/lib/abrit-control /var/lib/abrit-control/media
install -d -m 0755 /var/lib/abrit-control/acme
install -d -m 0750 -o root -g abrit-control /etc/abrit-control
install -d -m 0700 /etc/abrit-control/tls
if [ ! -x /opt/abrit-control/.venv/bin/python ]; then
    python3 -m venv /opt/abrit-control/.venv
fi
if [ -d /opt/abrit-control/wheels ]; then
    /opt/abrit-control/.venv/bin/pip install --no-index --find-links=/opt/abrit-control/wheels -r /opt/abrit-control/requirements.txt
else
    /opt/abrit-control/.venv/bin/pip install --disable-pip-version-check -r /opt/abrit-control/requirements.txt
fi
if [ ! -f /etc/abrit-control/config.json ]; then
    /opt/abrit-control/.venv/bin/python - <<'PY'
import json, secrets
from pathlib import Path
config = {'SECRET_KEY':secrets.token_hex(48),'BASE_URL':'https://serverdesk.abrit.cloud',
          'DATA_DIR':'/var/lib/abrit-control','TRUSTED_HOSTS':['serverdesk.abrit.cloud','10.0.0.150','localhost','127.0.0.1']}
Path('/etc/abrit-control/config.json').write_text(json.dumps(config), encoding='utf-8')
PY
    chown root:abrit-control /etc/abrit-control/config.json
    chmod 0640 /etc/abrit-control/config.json
fi
chown root:abrit-control /etc/abrit-control/config.json
chmod 0640 /etc/abrit-control/config.json
if [ ! -f /var/lib/abrit-control/control.sqlite3 ]; then
    umask 077
    /opt/abrit-control/.venv/bin/python - <<'PY'
import secrets
from pathlib import Path
password = secrets.token_urlsafe(24)
Path('/root/abrit-control-panel-password').write_text(password + '\n')
Path('/root/abrit-control-access.txt').write_text(
    'Panel: https://10.0.0.150/admin\nPublic panel after HTTPS routing: https://serverdesk.abrit.cloud/admin\n'
    'Username: manager\nPassword: ' + password + '\n\nSSH credentials unchanged.\n', encoding='utf-8')
PY
    cd /opt/abrit-control
    cat /root/abrit-control-panel-password | ABRIT_CONTROL_CONFIG=/etc/abrit-control/config.json /opt/abrit-control/.venv/bin/python app.py init
    chown -R abrit-control:abrit-control /var/lib/abrit-control
    chmod 0755 /var/lib/abrit-control/acme
fi
chown -R abrit-control:abrit-control /var/lib/abrit-control
if [ ! -f /var/lib/abrit-control/media/default-banner.webp ]; then
    /opt/abrit-control/.venv/bin/python - <<'PY'
from PIL import Image
with Image.open('/opt/abrit-control/default-banner.png') as image:
    image.convert('RGB').save('/var/lib/abrit-control/media/default-banner.webp','WEBP',quality=90)
PY
    chown abrit-control:abrit-control /var/lib/abrit-control/media/default-banner.webp
    chmod 0640 /var/lib/abrit-control/media/default-banner.webp
fi
if [ ! -f /etc/abrit-control/tls/privkey.pem ]; then
    openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 90 \
        -keyout /etc/abrit-control/tls/privkey.pem -out /etc/abrit-control/tls/fullchain.pem \
        -subj '/CN=serverdesk.abrit.cloud' -addext 'subjectAltName=DNS:serverdesk.abrit.cloud,IP:10.0.0.150' >/dev/null 2>&1
    chmod 0600 /etc/abrit-control/tls/privkey.pem
fi
install -m 0644 /opt/abrit-control/deploy/abrit-control.service /etc/systemd/system/abrit-control.service
install -m 0644 /opt/abrit-control/deploy/nginx-http.conf /etc/nginx/sites-available/abrit-control-http
install -m 0644 /opt/abrit-control/deploy/nginx-https.conf /etc/nginx/sites-available/abrit-control-https
ln -sfn /etc/nginx/sites-available/abrit-control-http /etc/nginx/sites-enabled/abrit-control-http
ln -sfn /etc/nginx/sites-available/abrit-control-https /etc/nginx/sites-enabled/abrit-control-https
nginx -t
systemctl daemon-reload
systemctl enable --now abrit-control
systemctl enable nginx
systemctl reload nginx
curl --fail --silent --retry 10 --retry-connrefused --retry-delay 1 http://127.0.0.1:8088/healthz
printf '\nPanel and API deployed. SSH and connection services unchanged.\n'
