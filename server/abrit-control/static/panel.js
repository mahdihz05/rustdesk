(() => {
  const form = document.querySelector('#content-form');
  if (!form) return;
  const byId = id => document.getElementById(id);
  let language = 'fa';
  let imageObject;
  const modeLabels = {off:'بدون بروزرسانی', optional:'بروزرسانی اختیاری', minimum:'حداقل نسخهٔ مجاز', mandatory:'بروزرسانی اجباری'};
  function refresh() {
    byId('preview-title').textContent = byId('title-' + language).value;
    byId('preview-subtitle').textContent = byId('subtitle-' + language).value;
    byId('banner-preview').dir = language === 'fa' ? 'rtl' : 'ltr';
    byId('banner-preview').hidden = !byId('banner-enabled').checked;
    const mode = byId('update-mode').value;
    const latest = byId('latest').value;
    const minimum = byId('minimum').value;
    byId('force-warning').hidden = !['minimum', 'mandatory'].includes(mode);
    byId('minimum').disabled = ['off', 'optional'].includes(mode);
    byId('policy-label').textContent = modeLabels[mode];
    byId('policy-summary').textContent = mode === 'minimum' ? `نسخه‌های کمتر از ${minimum} باید بروزرسانی کنند؛ آخرین نسخه ${latest} است.` : mode === 'mandatory' ? `تمام نسخه‌های کمتر از ${latest} باید بروزرسانی کنند.` : mode === 'optional' ? `نسخهٔ ${latest} پیشنهاد می‌شود؛ استفاده از نسخهٔ فعلی ادامه دارد.` : 'محدودیت یا پیام بروزرسانی ارسال نمی‌شود.';
  }
  form.addEventListener('input', () => {
    byId('dirty-state').textContent = 'تغییرات هنوز منتشر نشده‌اند.';
    refresh();
  });
  byId('image-file').addEventListener('change', event => {
    if (imageObject) URL.revokeObjectURL(imageObject);
    const file = event.target.files[0];
    if (file) { imageObject = URL.createObjectURL(file); byId('preview-image').src = imageObject; }
    else byId('preview-image').src = byId('image-url').value;
  });
  byId('image-url').addEventListener('change', event => {
    if (!byId('image-file').files.length && event.target.value.startsWith('https://')) byId('preview-image').src = event.target.value;
  });
  byId('preview-language').addEventListener('click', () => {
    language = language === 'fa' ? 'en' : 'fa';
    byId('preview-language').textContent = language === 'fa' ? 'English' : 'فارسی';
    refresh();
  });
  refresh();
})();
