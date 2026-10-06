import json


PAGE_SIZE = 10
FIELDS = (
    ('update.latest_version', 'آخرین نسخه'),
    ('update.minimum_version', 'حداقل نسخه'),
    ('update.mandatory', 'اجبار بروزرسانی'),
    ('update.download_url', 'لینک دانلود'),
    ('update.message.fa', 'پیام فارسی بروزرسانی'),
    ('update.message.en', 'پیام انگلیسی بروزرسانی'),
    ('banner.enabled', 'نمایش بنر'),
    ('banner.image_url', 'تصویر بنر'),
    ('banner.image_url_dark', 'تصویر بنر تیره'),
    ('banner.title.fa', 'عنوان فارسی بنر'),
    ('banner.title.en', 'عنوان انگلیسی بنر'),
    ('banner.subtitle.fa', 'متن فارسی بنر'),
    ('banner.subtitle.en', 'متن انگلیسی بنر'),
    ('banner.link_url', 'لینک بنر'),
    ('poll_interval_seconds', 'زمان تازه‌سازی'),
)


def changed_fields(document, previous):
    if previous is None:
        return ['تنظیمات اولیه']

    def value(doc, path):
        for key in path.split('.'):
            doc = doc.get(key) if isinstance(doc, dict) else None
        return doc

    keywords = []
    if bool(document.get('update')) != bool(previous.get('update')):
        keywords.append('نمایش بروزرسانی')
    keywords.extend(label for path, label in FIELDS if value(document, path) != value(previous, path))
    return keywords or ['بدون تغییر محتوا']


def history_page(connection, requested_page):
    total = connection.execute('SELECT COUNT(*) FROM history').fetchone()[0]
    pages = max(1, (total + PAGE_SIZE - 1) // PAGE_SIZE)
    page = min(max(requested_page, 1), pages)
    offset = (page - 1) * PAGE_SIZE
    rows = connection.execute('''
        SELECT h.id, h.updated, h.actor, h.action, h.document,
               (SELECT document FROM history WHERE id < h.id ORDER BY id DESC LIMIT 1) AS previous_document
        FROM history AS h ORDER BY h.id DESC LIMIT ? OFFSET ?
    ''', (PAGE_SIZE, offset)).fetchall()
    history = []
    for row in rows:
        previous = json.loads(row['previous_document']) if row['previous_document'] is not None else None
        history.append({'id': row['id'], 'updated': row['updated'], 'actor': row['actor'],
                        'action': row['action'], 'keywords': changed_fields(json.loads(row['document']), previous)})
    return history, {'page': page, 'pages': pages, 'total': total,
                     'start': offset + 1 if total else 0, 'end': offset + len(history)}
