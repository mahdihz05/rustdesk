import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time
from datetime import timedelta
from functools import wraps
from contextlib import contextmanager
from urllib.parse import urlsplit

from flask import Flask, abort, flash, redirect, render_template, request, send_from_directory, session, url_for
from PIL import Image, ImageOps, UnidentifiedImageError
from werkzeug.middleware.proxy_fix import ProxyFix
from werkzeug.security import check_password_hash, generate_password_hash

Image.MAX_IMAGE_PIXELS = 16_000_000
DOWNLOAD = 'https://github.com/mahdihz05/rustdesk/releases/download/abritdesk-v1.5.1-control-preview.1/abritdesk-windows-x64-1.5.1-8a91b2cca.zip'


def version(value):
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', value):
        raise ValueError('نسخه باید عددی باشد؛ مثلاً 1.5.1')
    numbers = tuple(int(x) for x in value.split('.'))
    if any(x > 4_294_967_295 for x in numbers):
        raise ValueError('شمارهٔ نسخه بیش از حد بزرگ است.')
    return numbers + (0,) * (3 - len(numbers))


def https_url(value, optional=False):
    if not value and optional:
        return ''
    try:
        parsed = urlsplit(value)
        valid = parsed.scheme == 'https' and parsed.hostname and not parsed.username and not parsed.password
        valid = valid and len(value) <= 2048 and not any(c.isspace() or ord(c) < 32 for c in value) and '\\' not in value
        if not valid:
            raise ValueError()
        _ = parsed.port
    except ValueError:
        raise ValueError('لینک باید HTTPS معتبر و بدون نام کاربری یا رمز باشد.') from None
    return value


def validate_document(doc):
    if doc.get('schema_version') != 1 or not 5 <= doc.get('poll_interval_seconds', 0) <= 300:
        raise ValueError('زمان تازه‌سازی باید بین ۵ تا ۳۰۰ ثانیه باشد.')
    banner = doc.get('banner', {})
    if type(banner.get('enabled')) is not bool:
        raise ValueError('وضعیت بنر معتبر نیست.')
    for key in ('image_url', 'image_url_dark', 'link_url'):
        https_url(banner.get(key, ''), optional=True)
    update = doc.get('update')
    if update:
        if version(update['minimum_version']) > version(update['latest_version']):
            raise ValueError('حداقل نسخه نمی‌تواند از آخرین نسخه بیشتر باشد.')
        https_url(update['download_url'])
        if type(update.get('mandatory')) is not bool:
            raise ValueError('نوع به‌روزرسانی معتبر نیست.')
    if len(json.dumps(doc, ensure_ascii=False).encode()) > 65536:
        raise ValueError('متن‌ها بیش از حد طولانی هستند.')
    return doc


def initial_document(base_url):
    return {
        'schema_version': 1, 'revision': secrets.token_hex(12), 'poll_interval_seconds': 30,
        'banner': {'enabled': True, 'revision': secrets.token_hex(12),
                   'image_url': f'{base_url}/media/default-banner.webp', 'image_url_dark': '',
                   'title': {'fa': 'راهکاری امن برای دسترسی از راه دور', 'en': 'Secure remote access'},
                   'subtitle': {'fa': 'مناسب کسب‌وکارها و تیم‌های حرفه‌ای', 'en': 'Built for businesses and professional teams'},
                   'link_url': 'https://abritdesk.ir'},
        'update': {'latest_version': '1.5.1', 'minimum_version': '0.0.0', 'mandatory': False,
                   'download_url': DOWNLOAD,
                   'message': {'fa': 'نسخهٔ جدید abritdesk آمادهٔ دریافت است.', 'en': 'A new version of abritdesk is available.'}},
    }


def create_app(config=None):
    app = Flask(__name__)
    if config is None:
        path = Path(os.environ.get('ABRIT_CONTROL_CONFIG', '/etc/abrit-control/config.json'))
        config = json.loads(path.read_text(encoding='utf-8'))
    app.config.update(config)
    if not app.config.get('SECRET_KEY') or not app.config.get('BASE_URL'):
        raise ValueError('Server configuration requires SECRET_KEY and BASE_URL')
    app.config.setdefault('DUMMY_HASH', generate_password_hash(secrets.token_urlsafe(32)))
    app.config['SESSION_COOKIE_SECURE'] = config.get('SESSION_COOKIE_SECURE', True)
    app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Lax',
                      PERMANENT_SESSION_LIFETIME=timedelta(hours=8), MAX_CONTENT_LENGTH=9 * 1024 * 1024,
                      MAX_FORM_MEMORY_SIZE=128 * 1024, MAX_FORM_PARTS=50, SESSION_COOKIE_NAME='abrit_admin')
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=0, x_port=0, x_prefix=0)
    app.json.ensure_ascii = False
    data = Path(app.config['DATA_DIR'])
    media = data / 'media'
    media.mkdir(parents=True, exist_ok=True)
    database = data / 'control.sqlite3'

    @contextmanager
    def db():
        connection = sqlite3.connect(database, timeout=20)
        connection.row_factory = sqlite3.Row
        connection.execute('PRAGMA busy_timeout=20000')
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    with db() as connection:
        connection.executescript('''
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS users (name TEXT PRIMARY KEY, password TEXT NOT NULL, generation INTEGER NOT NULL DEFAULT 1);
            CREATE TABLE IF NOT EXISTS policy (id INTEGER PRIMARY KEY CHECK(id=1), document TEXT NOT NULL, updated INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY, document TEXT NOT NULL, updated INTEGER NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS attempts (address TEXT PRIMARY KEY, count INTEGER NOT NULL, until INTEGER NOT NULL);
        ''')

    def state():
        with db() as connection:
            row = connection.execute('SELECT document, updated FROM policy WHERE id=1').fetchone()
        if row is None:
            abort(503)
        return json.loads(row['document']), row['updated']

    def logged_in():
        with db() as connection:
            row = connection.execute('SELECT generation FROM users WHERE name=?', (session.get('user', ''),)).fetchone()
        return row is not None and row['generation'] == session.get('generation')

    def protected(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if not logged_in():
                session.clear()
                return redirect(url_for('login'))
            return fn(*args, **kwargs)
        return wrapper

    def csrf():
        if 'csrf' not in session:
            session['csrf'] = secrets.token_hex(32)
        return session['csrf']

    @app.before_request
    def verify_csrf():
        if request.method == 'POST':
            token = request.form.get('csrf', '')
            if not token or not secrets.compare_digest(token, session.get('csrf', '')):
                abort(403)

    @app.after_request
    def headers(response):
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Referrer-Policy'] = 'no-referrer'
        response.headers['Content-Security-Policy'] = "default-src 'self'; img-src 'self' https: blob:; style-src 'self'; script-src 'self'; font-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
        if request.path.startswith('/admin'):
            response.headers['Cache-Control'] = 'no-store'
            response.headers['X-Robots-Tag'] = 'noindex, nofollow'
        return response

    @app.context_processor
    def template_context():
        return {'csrf': csrf, 'base_url': app.config['BASE_URL']}

    @app.get('/')
    def index():
        return redirect(url_for('dashboard'))

    @app.route('/admin/login', methods=['GET', 'POST'])
    def login():
        if request.method == 'POST':
            address = request.remote_addr or 'unknown'
            now = int(time.time())
            with db() as connection:
                attempt = connection.execute('SELECT count, until FROM attempts WHERE address=?', (address,)).fetchone()
                if attempt and attempt['until'] > now and attempt['count'] >= 8:
                    return render_template('login.html', error='تعداد تلاش‌ها زیاد است. ۱۵ دقیقه بعد دوباره امتحان کنید.'), 429
                row = connection.execute('SELECT * FROM users WHERE name=?', (request.form.get('username', ''),)).fetchone()
                password = request.form.get('password', '')[:512]
                matched = check_password_hash(row['password'] if row else app.config['DUMMY_HASH'], password)
                if row and matched:
                    connection.execute('DELETE FROM attempts WHERE address=?', (address,))
                    session.clear()
                    session.update(user=row['name'], generation=row['generation'], csrf=secrets.token_hex(32))
                    session.permanent = True
                    return redirect(url_for('dashboard'))
                count = attempt['count'] + 1 if attempt and attempt['until'] > now else 1
                connection.execute('INSERT OR REPLACE INTO attempts VALUES (?,?,?)', (address, count, now + 900))
            return render_template('login.html', error='نام کاربری یا رمز پنل درست نیست.'), 401
        return render_template('login.html')

    @app.post('/admin/logout')
    @protected
    def logout():
        session.clear()
        return redirect(url_for('login'))

    @app.get('/admin')
    @protected
    def dashboard():
        doc, updated = state()
        with db() as connection:
            history = connection.execute('SELECT id, updated, actor, action FROM history ORDER BY id DESC LIMIT 20').fetchall()
        update = doc.get('update') or {}
        mode = 'off' if not update else 'mandatory' if update.get('mandatory') else 'minimum' if version(update['minimum_version']) > (0, 0, 0) else 'optional'
        preview_image = doc['banner'].get('image_url', '')
        prefix = app.config['BASE_URL'] + '/'
        if preview_image.startswith(prefix):
            preview_image = '/' + preview_image[len(prefix):]
        return render_template('dashboard.html', doc=doc, update=update, mode=mode, updated=updated, history=history, preview_image=preview_image)

    def text(name, limit=600):
        value = request.form.get(name, '').strip()
        if len(value) > limit:
            raise ValueError('متن بیش از حد طولانی است.')
        return value

    def upload_image(field, existing):
        upload = request.files.get(field)
        if not upload or not upload.filename:
            return https_url(existing, optional=True)
        raw = upload.stream.read(4 * 1024 * 1024 + 1)
        if len(raw) > 4 * 1024 * 1024:
            raise ValueError('هر تصویر باید حداکثر ۴ مگابایت باشد.')
        try:
            with Image.open(io.BytesIO(raw)) as probe:
                if probe.format not in ('JPEG', 'PNG', 'WEBP'):
                    raise ValueError('فقط تصویر PNG، JPEG یا WebP پذیرفته می‌شود.')
                if probe.width * probe.height > 16_000_000:
                    raise ValueError('ابعاد تصویر نباید بیش از ۱۶ میلیون پیکسل باشد.')
                probe.verify()
            with Image.open(io.BytesIO(raw)) as original:
                image = ImageOps.exif_transpose(original).convert('RGB')
                image.thumbnail((4096, 2048))
                output = io.BytesIO()
                image.save(output, 'WEBP', quality=88)
        except (UnidentifiedImageError, OSError, Image.DecompressionBombError, Image.DecompressionBombWarning):
            raise ValueError('تصویر معتبر نیست یا ابعاد بسیار بزرگی دارد.') from None
        encoded = output.getvalue()
        name = hashlib.sha256(encoded).hexdigest() + '.webp'
        path = media / name
        if not path.exists():
            temporary = media / (secrets.token_hex(16) + '.tmp')
            temporary.write_bytes(encoded)
            os.replace(temporary, path)
        return f"{app.config['BASE_URL']}/media/{name}"

    def commit(doc, expected_revision, action):
        validate_document(doc)
        doc['revision'] = secrets.token_hex(12)
        doc['banner']['revision'] = secrets.token_hex(12)
        encoded = json.dumps(doc, ensure_ascii=False, separators=(',', ':'))
        with db() as connection:
            connection.execute('BEGIN IMMEDIATE')
            current = connection.execute('SELECT document FROM policy WHERE id=1').fetchone()
            if not current or json.loads(current['document'])['revision'] != expected_revision:
                raise ValueError('محتوا در صفحهٔ دیگری تغییر کرده است؛ صفحه را تازه کنید و دوباره ذخیره کنید.')
            now = int(time.time())
            connection.execute('UPDATE policy SET document=?, updated=? WHERE id=1', (encoded, now))
            connection.execute('INSERT INTO history(document, updated, actor, action) VALUES(?,?,?,?)', (encoded, now, session['user'], action))

    @app.post('/admin/save')
    @protected
    def save():
        try:
            current, _ = state()
            doc = {'schema_version': 1, 'poll_interval_seconds': int(text('interval', 3)),
                   'banner': {'enabled': request.form.get('banner_enabled') == 'on',
                              'image_url': upload_image('image_file', text('image_url', 2048)),
                              'image_url_dark': upload_image('dark_file', text('image_url_dark', 2048)),
                              'title': {'fa': text('title_fa', 200), 'en': text('title_en', 200)},
                              'subtitle': {'fa': text('subtitle_fa'), 'en': text('subtitle_en')},
                              'link_url': https_url(text('link_url', 2048), optional=True)}}
            mode = text('update_mode', 20)
            if mode not in ('off', 'optional', 'minimum', 'mandatory'):
                raise ValueError('نوع بروزرسانی معتبر نیست.')
            if mode != 'off':
                doc['update'] = {'latest_version': text('latest', 32),
                                 'minimum_version': text('minimum', 32) if mode in ('minimum', 'mandatory') else '0.0.0',
                                 'mandatory': mode == 'mandatory', 'download_url': https_url(text('download_url', 2048)),
                                 'message': {'fa': text('message_fa'), 'en': text('message_en')}}
                validate_document(doc)
                restrictive = doc['update']['mandatory'] or version(doc['update']['minimum_version']) > (0, 0, 0)
                if restrictive and doc['update'] != current.get('update') and request.form.get('confirm_force') != 'on':
                    raise ValueError('برای انتشار الزام نسخه، تأیید مسدودشدن نسخه‌های پایین‌تر را انتخاب کنید.')
            commit(doc, text('revision', 100), 'ذخیرهٔ محتوا')
            flash('تغییرات منتشر شد. برنامه‌های متصل در نوبت تازه‌سازی بعدی آن را دریافت می‌کنند.', 'success')
        except (ValueError, KeyError) as error:
            flash(str(error) or 'ورودی معتبر نیست.', 'error')
        return redirect(url_for('dashboard'))

    @app.post('/admin/restore/<int:history_id>')
    @protected
    def restore(history_id):
        with db() as connection:
            row = connection.execute('SELECT document FROM history WHERE id=?', (history_id,)).fetchone()
        if row is None:
            abort(404)
        try:
            doc = json.loads(row['document'])
            update = doc.get('update') or {}
            restrictive = update and (update.get('mandatory') or version(update['minimum_version']) > (0, 0, 0))
            if restrictive and request.form.get('confirm_restore') != 'on':
                raise ValueError('این نسخهٔ محتوا الزام بروزرسانی دارد؛ تأیید بازگردانی الزام را انتخاب کنید.')
            commit(doc, text('revision', 100), f'بازگردانی نسخهٔ محتوا {history_id}')
            flash('نسخهٔ انتخاب‌شده با شناسهٔ انتشار جدید بازگردانی شد.', 'success')
        except ValueError as error:
            flash(str(error), 'error')
        return redirect(url_for('dashboard') + '#history')

    @app.post('/admin/password')
    @protected
    def password():
        current = request.form.get('current_password', '')[:512]
        new = request.form.get('new_password', '')
        with db() as connection:
            row = connection.execute('SELECT * FROM users WHERE name=?', (session['user'],)).fetchone()
            if not check_password_hash(row['password'], current):
                flash('رمز فعلی پنل درست نیست.', 'error')
            elif not 12 <= len(new) <= 128 or new != request.form.get('repeat_password'):
                flash('رمز جدید باید حداقل ۱۲ کاراکتر باشد و تکرار آن یکسان باشد.', 'error')
            else:
                connection.execute('UPDATE users SET password=?, generation=generation+1 WHERE name=?', (generate_password_hash(new), session['user']))
                session['generation'] = row['generation'] + 1
                session['csrf'] = secrets.token_hex(32)
                flash('رمز پنل تغییر کرد. رمز SSH سرور تغییری نکرده است.', 'success')
        return redirect(url_for('dashboard') + '#account')

    @app.get('/api/v1/client/windows')
    def manifest():
        doc, _ = state()
        encoded = json.dumps(doc, ensure_ascii=False, separators=(',', ':')).encode()
        response = app.response_class(encoded, mimetype='application/json')
        response.set_etag(hashlib.sha256(encoded).hexdigest())
        response.headers['Cache-Control'] = 'no-cache, max-age=0, must-revalidate'
        return response.make_conditional(request)

    @app.get('/media/<path:name>')
    def image_file(name):
        if not re.fullmatch(r'(?:[0-9a-f]{64}|default-banner)\.webp', name):
            abort(404)
        return send_from_directory(media, name, mimetype='image/webp', max_age=31536000)

    @app.get('/healthz')
    def health():
        state()
        return {'ok': True}

    @app.errorhandler(413)
    def too_large(_):
        return 'حجم ارسال زیاد است؛ هر تصویر حداکثر ۴ مگابایت باشد.', 413

    @app.template_filter('date_fa')
    def date_fa(value):
        from datetime import datetime
        from zoneinfo import ZoneInfo
        return datetime.fromtimestamp(value, ZoneInfo('Asia/Tehran')).strftime('%Y/%m/%d  %H:%M')

    app.control_db = db
    return app


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['init', 'reset-password', 'backup', 'serve'])
    parser.add_argument('--username', default='manager')
    parser.add_argument('--output')
    args = parser.parse_args()
    app = create_app()
    if args.command == 'serve':
        app.run(host='127.0.0.1', port=8088)
        return
    if args.command == 'backup':
        if not args.output:
            parser.error('backup requires --output')
        with app.control_db() as source, sqlite3.connect(args.output) as target:
            source.backup(target)
        print('Database backup completed')
        return
    import getpass
    password = getpass.getpass('Panel password: ')
    if len(password) < 12:
        raise SystemExit('Panel password must contain at least 12 characters')
    with app.control_db() as connection:
        if args.command == 'init':
            if connection.execute('SELECT 1 FROM users LIMIT 1').fetchone():
                raise SystemExit('Already initialized; no credentials or data changed')
            connection.execute('INSERT INTO users(name,password) VALUES(?,?)', (args.username, generate_password_hash(password)))
            doc = validate_document(initial_document(app.config['BASE_URL']))
            encoded = json.dumps(doc, ensure_ascii=False, separators=(',', ':'))
            now = int(time.time())
            connection.execute('INSERT INTO policy VALUES(1,?,?)', (encoded, now))
            connection.execute('INSERT INTO history(document,updated,actor,action) VALUES(?,?,?,?)', (encoded, now, args.username, 'راه‌اندازی اولیه'))
        else:
            changed = connection.execute('UPDATE users SET password=?,generation=generation+1 WHERE name=?', (generate_password_hash(password), args.username)).rowcount
            if not changed:
                raise SystemExit('Panel user not found; no changes made')
    print('Panel account saved; SSH credentials unchanged')


if __name__ == '__main__':
    main()
