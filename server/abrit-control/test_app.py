import io
import json
import copy
import re
from pathlib import Path
import secrets
import tempfile
import unittest
import hashlib
import sqlite3

from PIL import Image
from werkzeug.security import generate_password_hash

from app import create_app, initial_document, validate_document, version
from deploy.backup import snapshot
from deploy.restore import verify
from history import changed_fields, FIELDS


class ControlTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.app = create_app({'TESTING': True, 'SECRET_KEY': secrets.token_hex(32),
                               'BASE_URL': 'https://serverdesk.abrit.cloud', 'DATA_DIR': self.temp.name})
        self.doc = initial_document('https://serverdesk.abrit.cloud')
        with self.app.control_db() as db:
            db.execute('INSERT INTO users(name,password) VALUES(?,?)', ('manager', generate_password_hash('panel-test-password')))
            encoded = json.dumps(self.doc)
            db.execute('INSERT INTO policy VALUES(1,?,1)', (encoded,))
            db.execute('INSERT INTO history(document,updated,actor,action) VALUES(?,1,?,?)', (encoded, 'manager', 'init'))
        self.client = self.app.test_client()
        self.base = 'https://serverdesk.abrit.cloud'

    def tearDown(self):
        self.temp.cleanup()

    def get(self, path, **kwargs):
        return self.client.get(path, base_url=self.base, **kwargs)

    def post(self, path, data, **kwargs):
        return self.client.post(path, data=data, base_url=self.base, **kwargs)

    def token(self, client=None):
        selected = client or self.client
        selected.get('/admin/login', base_url=self.base)
        with selected.session_transaction(base_url=self.base) as session:
            return session['csrf']

    def login(self):
        response = self.post('/admin/login', {'csrf': self.token(), 'username': 'manager', 'password': 'panel-test-password'})
        self.assertEqual(response.status_code, 302)
        with self.client.session_transaction(base_url=self.base) as session:
            return session['csrf']

    def document(self):
        return self.get('/api/v1/client/windows').json

    def form(self, **changes):
        doc = self.document()
        form = {'csrf': self.login(), 'revision': doc['revision'], 'interval': '30', 'banner_enabled': 'on',
                'image_url': doc['banner']['image_url'], 'image_url_dark': '', 'title_fa': 'بنر جدید', 'title_en': 'New banner',
                'subtitle_fa': 'توضیح', 'subtitle_en': 'Description', 'link_url': 'https://abrit.cloud',
                'update_mode': 'optional', 'latest': '1.5.1', 'minimum': '0.0.0',
                'download_url': doc['update']['download_url'], 'message_fa': 'پیام', 'message_en': 'Message'}
        form.update(changes)
        return form

    def test_versions_and_policy_validation(self):
        self.assertGreater(version('1.10'), version('1.9.9'))
        self.assertEqual(version('1.3'), version('1.3.0'))
        for invalid in ('1.5.1-beta', '-1', '1.2.3.4'):
            with self.assertRaises(ValueError):
                version(invalid)
        self.doc['update']['minimum_version'] = '2.0'
        with self.assertRaises(ValueError):
            validate_document(self.doc)

    def test_transfer_snapshots_and_identity_checks(self):
        source = Path(self.temp.name) / 'source.sqlite3'
        current = sqlite3.connect(source)
        try:
            current.execute('PRAGMA journal_mode=WAL')
            current.execute('CREATE TABLE example(value INTEGER)')
            current.execute('INSERT INTO example VALUES(42)')
            current.commit()
            root = Path(self.temp.name) / 'transfer'
            for relative in ('payload/var/lib/rustdesk-server/db_v2.sqlite3', 'payload/var/lib/abrit-control/control.sqlite3'):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                snapshot(source, destination)
                self.assertFalse(Path(str(destination) + '-shm').exists())
                self.assertFalse(Path(str(destination) + '-wal').exists())
                with sqlite3.connect(destination) as copied:
                    self.assertEqual(copied.execute('SELECT value FROM example').fetchone()[0], 42)
            key = root / 'payload/var/lib/rustdesk-server/id_ed25519.pub'
            key.write_text('example-server-identity')
            metadata = {'format': 1, 'domain': 'serverdesk.abrit.cloud',
                        'files': {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in root.rglob('*') if path.is_file()},
                        'server_public_key_sha256': hashlib.sha256(key.read_bytes()).hexdigest()}
            (root / 'transfer-manifest.json').write_text(json.dumps(metadata))
            verify(root)
            key.write_text('changed-identity')
            with self.assertRaises(SystemExit):
                verify(root)
        finally:
            current.close()

    def test_auth_csrf_and_security_headers(self):
        self.assertEqual(self.get('/admin').status_code, 302)
        self.assertEqual(self.post('/admin/save', {}).status_code, 403)
        self.login()
        response = self.get('/admin')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers['Cache-Control'], 'no-store')
        self.assertEqual(response.headers['X-Frame-Options'], 'DENY')
        self.assertIn(b'content-form', response.data)
        response = self.get('/admin/login')
        self.assertTrue(self.app.config['SESSION_COOKIE_SECURE'])

    def test_forced_restore_requires_acknowledgement(self):
        form = self.form(update_mode='mandatory', minimum='0.0.0', confirm_force='on')
        self.post('/admin/save', form)
        with self.app.control_db() as db:
            history_id = db.execute('SELECT MAX(id) FROM history').fetchone()[0]
        self.post('/admin/save', self.form(update_mode='optional'))
        optional = self.document()
        with self.client.session_transaction(base_url=self.base) as session:
            token = session['csrf']
        restore = {'csrf': token, 'revision': optional['revision']}
        self.post(f'/admin/restore/{history_id}', restore)
        self.assertEqual(self.document(), optional)
        restore['confirm_restore'] = 'on'
        self.post(f'/admin/restore/{history_id}', restore)
        self.assertTrue(self.document()['update']['mandatory'])

    def test_live_save_and_etag(self):
        before = self.get('/api/v1/client/windows')
        self.assertEqual(self.get('/api/v1/client/windows', headers={'If-None-Match': before.headers['ETag']}).status_code, 304)
        form = self.form()
        self.post('/admin/save', form)
        after = self.get('/api/v1/client/windows', headers={'If-None-Match': before.headers['ETag']})
        self.assertEqual(after.status_code, 200)
        self.assertNotEqual(after.json['revision'], before.json['revision'])
        self.assertNotEqual(after.json['banner']['revision'], before.json['banner']['revision'])
        self.assertEqual(after.json['banner']['title']['fa'], 'بنر جدید')
        self.assertEqual(after.json['update']['minimum_version'], '0.0.0')

    def test_history_keywords_only_name_changed_fields(self):
        self.assertEqual(changed_fields(self.doc, None), ['تنظیمات اولیه'])
        for path, label in FIELDS:
            with self.subTest(field=path):
                changed = copy.deepcopy(self.doc)
                target = changed
                keys = path.split('.')
                for key in keys[:-1]:
                    target = target[key]
                original = target[keys[-1]]
                target[keys[-1]] = not original if isinstance(original, bool) else 60 if isinstance(original, int) else 'changed'
                self.assertEqual(changed_fields(changed, self.doc), [label])
        unchanged = copy.deepcopy(self.doc)
        unchanged['revision'] = 'new-publication'
        unchanged['banner']['revision'] = 'new-banner-revision'
        self.assertEqual(changed_fields(unchanged, self.doc), ['بدون تغییر محتوا'])
        del unchanged['update']
        self.assertIn('نمایش بروزرسانی', changed_fields(unchanged, self.doc))

    def seed_history(self, total):
        with self.app.control_db() as db:
            for index in range(1, total):
                doc = copy.deepcopy(self.doc)
                doc['update']['latest_version'] = f'1.5.{index}'
                db.execute('INSERT INTO history(document,updated,actor,action) VALUES(?,?,?,?)',
                           (json.dumps(doc), index + 1, 'manager', 'ذخیرهٔ محتوا'))

    def test_history_pagination_preserves_all_records_and_api(self):
        self.login()
        self.seed_history(25)
        original = self.document()
        for page, expected in ((1, range(25, 15, -1)), (2, range(15, 5, -1)), (3, range(5, 0, -1))):
            response = self.get(f'/admin?history_page={page}')
            self.assertEqual(response.status_code, 200)
            html = response.get_data(as_text=True)
            self.assertEqual([int(value) for value in re.findall(r'data-history-id="(\d+)"', html)], list(expected))
            self.assertIn(f'صفحهٔ {page} از 3', html)
            self.assertEqual('rel="prev"' in html, page > 1)
            self.assertEqual('rel="next"' in html, page < 3)
            if page == 2:
                first = html.split('data-history-id="15"', 1)[1].split('data-history-id="14"', 1)[0]
                self.assertIn('آخرین نسخه', first)
                self.assertNotIn('تنظیمات اولیه', first)
        self.assertEqual(self.document(), original)
        with self.app.control_db() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM history').fetchone()[0], 25)
        with self.client.session_transaction(base_url=self.base) as session:
            token = session['csrf']
        self.post('/admin/restore/5', {'csrf': token, 'revision': original['revision']})
        self.assertEqual(self.document()['update']['latest_version'], '1.5.4')
        newest = self.get('/admin').get_data(as_text=True)
        self.assertIn('data-history-id="26"', newest)
        self.assertIn('آخرین نسخه', newest)

    def test_history_page_boundaries_invalid_input_and_empty_history(self):
        self.login()
        self.seed_history(20)
        for value, expected in (('', 1), ('invalid', 1), ('-4', 1), ('0', 1), ('999999999999999999', 2)):
            response = self.get('/admin?history_page=' + value)
            self.assertEqual(response.status_code, 200)
            html = response.get_data(as_text=True)
            self.assertEqual(len(re.findall(r'data-history-id="(\d+)"', html)), 10)
            self.assertIn(f'صفحهٔ {expected} از 2', html)
            self.assertEqual('rel="next"' in html, expected == 1)
        with self.app.control_db() as db:
            db.execute('DELETE FROM history')
        response = self.get('/admin?history_page=2')
        html = response.get_data(as_text=True)
        self.assertIn('هنوز تغییری ثبت نشده است.', html)
        self.assertIn('نمایش 0 تا 0 از 0 تغییر', html)
        self.assertNotIn('rel="next"', html)
        self.assertNotIn('rel="prev"', html)

    def test_history_save_without_content_change_and_changed_banner(self):
        self.post('/admin/save', self.form())
        with self.client.session_transaction(base_url=self.base) as session:
            token = session['csrf']
        doc = self.document()
        form = {'csrf': token, 'revision': doc['revision'], 'interval': '30', 'banner_enabled': 'on',
                'image_url': doc['banner']['image_url'], 'image_url_dark': '',
                'title_fa': doc['banner']['title']['fa'], 'title_en': doc['banner']['title']['en'],
                'subtitle_fa': doc['banner']['subtitle']['fa'], 'subtitle_en': doc['banner']['subtitle']['en'],
                'link_url': doc['banner']['link_url'], 'update_mode': 'optional',
                'latest': doc['update']['latest_version'], 'download_url': doc['update']['download_url'],
                'message_fa': doc['update']['message']['fa'], 'message_en': doc['update']['message']['en']}
        self.post('/admin/save', form)
        html = self.get('/admin').get_data(as_text=True)
        first = html.split('data-history-id="3"', 1)[1].split('data-history-id="2"', 1)[0]
        self.assertIn('بدون تغییر محتوا', first)
        form.update(revision=self.document()['revision'], title_fa='عنوان تغییرکرده')
        self.post('/admin/save', form)
        html = self.get('/admin').get_data(as_text=True)
        first = html.split('data-history-id="4"', 1)[1].split('data-history-id="3"', 1)[0]
        self.assertIn('عنوان فارسی بنر', first)
        self.assertNotIn('آخرین نسخه', first)

    def test_force_requires_acknowledgement(self):
        original = self.document()
        form = self.form(update_mode='minimum', minimum='1.5.1')
        self.post('/admin/save', form)
        self.assertEqual(self.document(), original)
        form['confirm_force'] = 'on'
        self.post('/admin/save', form)
        self.assertEqual(self.document()['update']['minimum_version'], '1.5.1')

    def test_invalid_policy_preserves_last_good(self):
        original = self.document()
        for changes in ({'download_url': 'http://unsafe.test'}, {'update_mode': 'minimum', 'minimum': '9.0', 'confirm_force': 'on'},
                        {'image_url': 'https://user:password@unsafe.test/a.png'}, {'interval': '1'}):
            self.post('/admin/save', self.form(**changes))
            self.assertEqual(self.document(), original)

    def test_stale_edit_cannot_overwrite(self):
        form = self.form()
        self.post('/admin/save', form)
        first = self.document()
        form['title_fa'] = 'متن قدیمی'
        self.post('/admin/save', form)
        self.assertEqual(self.document(), first)

    def test_image_reencoded_and_content_addressed(self):
        image = io.BytesIO()
        Image.new('RGB', (600, 120), '#0878ee').save(image, 'PNG')
        form = self.form(image_file=(io.BytesIO(image.getvalue()), '../../evil.png'))
        self.post('/admin/save', form, content_type='multipart/form-data')
        link = self.document()['banner']['image_url']
        path = '/' + link.split('/', 3)[3]
        response = self.get(path)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.mimetype, 'image/webp')
        self.assertEqual(Image.open(io.BytesIO(response.data)).size, (600, 120))
        response.close()
        self.assertEqual(self.get('/media/../../config.json').status_code, 404)
        previous = self.document()
        form = self.form(image_file=(io.BytesIO(b'<svg onload="alert(1)"/>'), 'bad.svg'))
        self.post('/admin/save', form, content_type='multipart/form-data')
        self.assertEqual(self.document(), previous)

    def test_restore_and_disable(self):
        form = self.form(update_mode='off')
        form.pop('banner_enabled')
        self.post('/admin/save', form)
        self.assertNotIn('update', self.document())
        self.assertFalse(self.document()['banner']['enabled'])
        self.post('/admin/restore/1', {'csrf': form['csrf'], 'revision': self.document()['revision']})
        restored = self.document()
        self.assertEqual(restored['banner']['title'], self.doc['banner']['title'])
        self.assertNotEqual(restored['revision'], self.doc['revision'])

    def test_password_invalidates_other_sessions(self):
        token = self.login()
        other = self.app.test_client()
        other.post('/admin/login', base_url=self.base, data={'csrf': self.token(other), 'username': 'manager', 'password': 'panel-test-password'})
        self.assertEqual(other.get('/admin', base_url=self.base).status_code, 200)
        self.post('/admin/password', {'csrf': token, 'current_password': 'panel-test-password',
                                     'new_password': 'replacement-panel-password', 'repeat_password': 'replacement-panel-password'})
        self.assertEqual(other.get('/admin', base_url=self.base).status_code, 302)
        self.assertEqual(self.get('/admin').status_code, 200)

    def test_login_throttled(self):
        token = self.token()
        for _ in range(8):
            self.assertEqual(self.post('/admin/login', {'csrf': token, 'username': 'manager', 'password': 'wrong'}).status_code, 401)
        self.assertEqual(self.post('/admin/login', {'csrf': token, 'username': 'manager', 'password': 'wrong'}).status_code, 429)


if __name__ == '__main__':
    unittest.main()
