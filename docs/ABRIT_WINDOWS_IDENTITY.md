# استقلال نسخهٔ ویندوز AbritDesk — 1.5.3

این تغییر برای رفع تداخل نسخهٔ Portable با RustDesk نصب‌شده است. نام داخلی ویندوز پیش از مقداردهی تنظیمات و IPC، به `AbritDesk` تثبیت می‌شود؛ نام نمایشی رابط همچنان `abritdesk` است. فایل سفارشی نمی‌تواند نام داخلی ویندوز را به RustDesk برگرداند. دامنه و کلید عمومی سرور اتصال عوض نشده‌اند.

## هویت‌ها و رفتار مورد انتظار

| بخش | مقدار یا رفتار AbritDesk |
|---|---|
| نام داخلی برنامه | `AbritDesk` |
| نام سرویس / نام نمایشی | `AbritDesk` / `AbritDesk Service` |
| فایل و پوشهٔ نصب پیش‌فرض | `%ProgramFiles%\AbritDesk\AbritDesk.exe` |
| اتصال سرویس به فایل | فقط `AbritDesk.exe`؛ مسیر دارای مؤلفهٔ `RustDesk` رد می‌شود |
| Pipe اصلی / سرویس | `\\.\pipe\AbritDesk\query` / `\\.\pipe\AbritDesk\query_service` |
| Pipe ترمینال | `AbritDesk_term_in_<uuid>` / `AbritDesk_term_out_<uuid>` |
| تک‌نمونه / پنجره / Tray | کلاس `ABRITDESK_FLUTTER_RUNNER_WIN32_WINDOW` و Mutex با نام `Local\AbritDesk_tray` |
| Clipboard | Mutex با نام `AbritDesk_data_obj_mutex` و قالب مالکیت `dyn.cloud.abrit.abritdesk.owner` |
| تنظیمات کاربر | `%APPDATA%\AbritDesk\config\AbritDesk*.toml`؛ بدون fallback به تنظیمات RustDesk |
| فایل‌های Portable و helper | کش مستقل در `%LOCALAPPDATA%\abritdesk`؛ helper قدیمی در `%LOCALAPPDATA%\AbritDesk` |
| تنظیمات سمت سرویس | همان نام AbritDesk در پروفایل حساب سرویس؛ import فقط از تنظیمات AbritDesk |
| رجیستری | InstallState، Uninstall، file association و protocol از نام داخلی AbritDesk ساخته می‌شوند؛ fallback به GUID نصب‌کنندهٔ قدیمی RustDesk حذف شده است |
| URI | `abritdesk://` |
| Autostart / میان‌برها / Firewall | نام و فایل مستقل AbritDesk؛ عنوان نمایشی میان‌بر `abritdesk` |
| MSI | UpgradeCode پایدار از `uuid5(NAMESPACE_OID, "AbritDesk.exe")`؛ متفاوت از RustDesk؛ GUID اجزای سفارشی از اجزای stock جدا هستند |
| Privacy mode | پنجره و کلاس AbritDesk و فایل `RuntimeBroker_abritdesk.exe` |
| انتقال فایل / اتصال / رمز | مدل و پروتکل اتصال موجود؛ بازنویسی نشده‌اند |

پورت پیش‌فرض دسترسی مستقیم ویندوز `21218` و کشف LAN ویندوز `21219` شده‌اند تا دو برنامه روی پورت‌های محلی پیش‌فرض هم تداخل نداشته باشند. اتصال با IP بدون پورت نیز از `21218` استفاده می‌کند. پورت صریح واردشده یا ذخیره‌شده حفظ می‌شود. پورت‌های سرور ID و Relay تغییر نکرده‌اند. از کلاینتی با پیش‌فرض قدیمی، برای اتصال مستقیم به AbritDesk باید `IP:21218` وارد شود. کشف LAN با namespace پورت قدیمی مشترک نیست.

تغییر هویت به ویندوز محدود است؛ نام داخلی و پورت‌های پیش‌فرض دیگر سیستم‌عامل‌ها در این تغییر حفظ شده‌اند. نام crate، نام DLL و نمادهای FFI موجود، شناسهٔ سرویس/IPC/رجیستری نیستند و برای حفظ سازگاری پل Flutter تغییر نکرده‌اند.

## تنظیمات قدیمی و منابع سیستم

ویندوز به بزرگی و کوچکی حروف حساس نیست؛ تنظیمات قبلی `abritDesk` همان مسیر `AbritDesk` هستند و شناسه/رمز موجود آن‌ها حفظ می‌شود. پوشهٔ مستقل `ABRIT` و پوشهٔ RustDesk خودکار خوانده، کپی یا حذف نمی‌شوند. در نصب تازه، مقادیر پیش‌فرض سرور و کلید عمومی فعلی AbritDesk اعمال می‌شوند؛ تنظیمات موجود خود AbritDesk اولویت دارند.

نصب قدیمیِ خراب زیر `Program Files\RustDesk` یا سرویس RustDesk با Display Name اشتباه، خودکار ترمیم یا حذف نمی‌شود: چنین عملی دوباره به سرویس اصلی دست می‌زند. فایل جدید باید از پوشهٔ مستقل اجرا/نصب شود. بررسی و بازیابی نصب قدیمی باید جداگانه و با پشتیبان انجام شود.

درایورهای امضاشدهٔ چاپگر/نمایشگر، Clipboard استاندارد، Spooler و برخی تنظیمات ویندوز منابع مشترک سیستم‌اند. نام INF و گواهی امضاشده را نمی‌توان با جایگزینی رشته تغییر داد. حذف AbritDesk دیگر درایور/گواهی مشترک را پاک نمی‌کند؛ چاپگر و port خود برنامه مستقل هستند و درایور چاپگر موجود دوباره نصب نمی‌شود. این تغییر ادعای استقلال دو نصب درایور امضاشده یا کنترل رفتار uninstall برنامهٔ اصلی را ندارد.

## ظاهر و اندازه

- برند هدر در فارسی، عربی و انگلیسی سمت چپ می‌ماند؛ کنترل‌های ویندوز سمت راست هستند.
- کلیدهای `ع / فا / EN` سمت راست برند قرار دارند و همان تنظیم زبان برنامه را ذخیره می‌کنند. مسیر تنظیمات زبان نیز موجود است؛ اگر زبان با policy ثابت شده باشد، کلیدها غیرفعال‌اند.
- از عرض داخلی ۷۶۰، منوی دارای عنوان نمایش داده می‌شود: ۱۶۸ پیکسل تا عرض ۱۱۰۰ و سپس ۲۳۰ پیکسل. از ۶۰۰ تا ۷۵۹ منوی آیکونی و زیر ۶۰۰ Drawer است.
- حداقل عرض مفید لازم برای دو کارت ۵۶۰ است؛ در حالت Drawer کارت‌ها زیر هم هستند.
- ارتفاع بنر در پنجرهٔ کوتاه ۹۶، در پنجرهٔ متوسط ۱۲۰ و در پنجرهٔ بزرگ ۱۶۰ است. ارتفاع می‌تواند برای متن بلند بیشتر شود.
- شروع ۸۰۰×۶۰۰، بازیابی اندازه و Maximize، و قواعد DPI فعلی runner حفظ شده‌اند. اندازهٔ مانیتور به اینچ معیار چیدمان نیست؛ عرض/ارتفاع منطقی واقعی پنجره معیار است.

## آزمون‌ها و حدود نتیجه

آزمون‌های محلی اجراشده:

- `cargo test --offline --manifest-path res/abrit/identity-tests/Cargo.toml`: دو آزمون production module هویت و رد فایل/پوشهٔ RustDesk، موفق با Rust 1.75 روی ویندوز.
- `python res/abrit/test_identity.py`: چهار آزمون تولید UpgradeCode واقعی، جداسازی Component GUID، تطابق namespaceها و ارسال نام داخلی به نصب چاپگر MSI، موفق.
- `WindowInjection.dll`: منبع pinned حالت Privacy با دو نام جدید، در MSBuild محلی با toolset نصب‌شدهٔ v143 و خروجی x64 Release با موفقیت کامپایل شد؛ اجرای Privacy در نشست واقعی هنوز آزموده نشده است.
- `python res/abrit/check_ui.py --flutter-sdk <sdk>`: تحلیل اجزای UI بدون خطا؛ ۲۵ آزمون UI، Resize، RTL/LTR، popup، کپی، policy و بنر. با فعال‌کردن ثبت تصاویر، مجموع ۲۶ آزمون.
- تحلیل مسیرهای اصلی Dart: بدون error؛ اطلاعیه‌های قدیمی deprecated/unused موجود باقی مانده‌اند.
- `git diff --check` و بررسی نحوی PowerShell انجام شده است.

تصاویر بررسی از widgetهای واقعی Flutter، فونت‌ها و تصاویر همراه برنامه ساخته شده‌اند؛ شناسه و رمز نمونه‌اند. این تصاویر اجرای نسخهٔ native تازه یا اثبات کارکرد Windows Service نیستند. خروجی‌ها: `../preview/identity-ui-review/` در workspace، خارج از این مخزن.

بیلد کامل Rust/FFI و نصب واقعی MSI محلی انجام نشده است. تست نهایی نسخهٔ native در `res/abrit/test_windows_identity.ps1` به workflow ویندوز وصل شده است و پس از تأیید تصاویر اجرا می‌شود. اسکریپت فقط روی runner موقت GitHub-hosted مجاز است؛ هویت واقعی `--identity-json` را بررسی می‌کند، UI Portable را اجرا می‌کند، نصب/Stop/Start/Uninstall AbritDesk را آزمایش می‌کند و تغییرنکردن سرویس، رجیستری و hash فایل‌های stock را در هر مرحله می‌سنجد. در نبود RustDesk یک سرویس sentinel متوقف می‌سازد؛ این آزمون جای آزمایش دو نشست فعال با دو برنامهٔ کامل را نمی‌گیرد. اجرای هم‌زمان واقعی و نصب/ارتقای MSI باید با خروجی تازه روی ماشین آزمایشی نیز بررسی شود.

هیچ push، انتشار یا اجرای GitHub Action در مرحلهٔ پیش‌نمایش انجام نشده است.

## سطح اثر تغییرات و بررسی حداقلی diff

تمام فایل‌های موجودِ تغییرکرده در این جدول آمده‌اند. تغییرهای عمومی، hook کوچک یا شرط پلتفرم هستند؛ submodule مشترک تغییر نکرده است. رفع خطا یا بازآرایی نامرتبط در این تغییر انجام نشده است.

| فایل موجود | مسیر رفتاری تغییرکرده و ضرورت |
|---|---|
| `src/common.rs` | مقداردهی زودهنگام هویت ویندوز، جلوگیری از override نام، متغیر Portable مستقل؛ مانع رسیدن service/config به stock |
| `src/platform/windows.rs` | نصب، import، SCM، رجیستری، مسیر cache/staging، broker و cleanup؛ حذف fallback نصب اصلی و رد فایل سرویس مشترک |
| `src/platform/windows.cc` | فایل log تشخیص چاپگر `test_abritdesk.log`؛ جلوگیری از نوشتن دو برنامه در فایل تشخیصی مشترک |
| `src/core_main.rs` | فرمان readonly `--identity-json` پیش از bootstrap؛ سنجش namespace واقعی DLL ساخته‌شده بدون نصب |
| `src/privacy_mode/win_topmost_window.rs` | فایل helper و پنجرهٔ Privacy مستقل؛ مانع مدیریت helper اصلی |
| `src/server/terminal_service.rs` | نام Pipe ترمینال از نام برنامه؛ namespace مستقل |
| `src/clipboard.rs` | علامت مالکیت Clipboard در ویندوز مستقل؛ از مخلوط‌شدن مالکیت دو برنامه جلوگیری می‌کند |
| `libs/clipboard/src/windows/wf_cliprdr.c` | Mutex سراسری Clipboard مستقل؛ قفل مشترک حذف می‌شود |
| `src/lan.rs` | پورت کشف ویندوز مستقل؛ جلوگیری از اشغال پورت یکدیگر |
| `src/rendezvous_mediator.rs` | listener اتصال مستقیم ویندوز مستقل؛ پورت صریح حفظ می‌شود |
| `src/client.rs` | پیش‌فرض اتصال مستقیم IP مطابق listener مستقل؛ جلوگیری از اتصال ناخواسته به stock روی 21118 |
| `libs/portable/src/main.rs` | cache/env/broker ویندوز مستقل؛ مسیر غیر ویندوز حفظ شده است |
| `libs/remote_printer/src/setup/setup.rs` | reuse درایور موجود و عدم حذف درایور مشترک برای AbritDesk؛ حفاظت از چاپگر برنامهٔ دیگر |
| `res/msi/preprocess.py` | نام داخلی پیش‌فرض و UpgradeCode بر اساس ورودی واقعی؛ نصب/upgrade مستقل |
| `res/msi/Package/Components/RustDesk.wxs` | helper مستقل، عدم حذف driver مشترک، ارسال نام داخلی به چاپگر؛ نام نمایشی lowercase نباید namespace چاپگر را تعیین کند |
| `res/msi/CustomActions/CustomActions.cpp` | حذف فقط broker اختصاصی هنگام uninstall |
| `res/msi/CustomActions/RemotePrinter.cpp` | namespace چاپگر و حفاظت از درایور مشترک در نصب/حذف MSI |
| `build.py` | payload و فایل اجرایی ویندوز `AbritDesk.exe`؛ سرویس باید به همین فایل وصل شود |
| `flutter/windows/CMakeLists.txt` | نام خروجی runner ویندوز مستقل |
| `flutter/windows/runner/main.cpp` | fallback نام داخلی runner مستقل |
| `flutter/windows/runner/win32_window.cpp` | کلاس پنجره مطابق native؛ تک‌نمونه/ارسال پیام با stock اشتباه نمی‌شود |
| `flutter/windows/runner/Runner.rc` | metadata فایل اجرایی مستقل؛ انتساب حقوقی حفظ شده است |
| `Cargo.toml` | نسخهٔ 1.5.3 و metadata ویندوز؛ تشخیص بیلد اصلاح‌شده از 1.5.2 |
| `flutter/pubspec.yaml` | نسخهٔ 1.5.3+71 هم‌راستا با نسخهٔ native |
| `.github/workflows/abritdesk-windows-preview.yml` | فایل خروجی جدید و آزمون‌های native/installer/coexistence؛ جلوگیری از تحویل بیلد با هویت قدیمی |
| `.github/workflows/flutter-build.yml` | payload و staging نصب‌کننده مطابق فایل اجرایی جدید؛ سایر خروجی‌ها بازنویسی نشده‌اند |
| `.github/workflows/third-party-RustDeskTempTopMostWindow.yml` | دو نام پنجره در helper خارجی قبل از کامپایل به AbritDesk تغییر می‌کنند؛ بدون این تغییر DLL قبلی با جست‌وجوی namespace جدید کار نمی‌کند؛ commit منبع ثابت مانده است |
| `flutter/lib/abrit/brand.dart` | آستانهٔ منو، عرض دو کارت، حداقل بنر؛ دیدن همهٔ عناصر در اندازهٔ پیش‌فرض |
| `flutter/lib/abrit/shell.dart` | هدر ثابت LTR، toggle اضافی، منوی عنوان‌دار و footer جمع‌وجور؛ خواستهٔ ظاهری کاربر |
| `flutter/lib/abrit/runtime.dart` | handler اختصاصی زبان برای هدر با ذخیره و reload موجود |
| `flutter/lib/abrit/live_banner.dart` | ارتفاع بنر API مطابق فضای واقعی پنجره؛ جلوگیری از بنر ۵۶ پیکسلی |
| `flutter/lib/abrit/widgets.dart` | بنر fallback هم‌اندازهٔ بنر زنده؛ سبک ثابت در قطعی API |
| `flutter/lib/desktop/pages/desktop_tab_page.dart` | hook اختیاری toggle در shell موجود؛ احترام به زبان ثابت policy |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | handler دسکتاپ زبان و hint پورت مستقیم؛ هماهنگی کنترل‌های موجود با تغییر جدید |
| `flutter/lib/common/widgets/dialog.dart` | hint پورت مستقیم ویندوز هماهنگ با listener؛ کاربر به پورت stock هدایت نشود |
| `flutter/test/abrit_layout_test.dart` | مرزهای جدید، مقیاس‌ها، جهت ثابت برند، toggle/حفظ ورودی و renderer تصاویر؛ اثبات رفتار ظاهر |
| `docs/ABRIT_UI.md` | قواعد جدید چیدمان و ارجاع به گزارش هویت؛ حذف توضیح منسوخ «هویت فنی حفظ شده» |

فایل‌های جدید: ماژول هویت Windows، widget انتخاب زبان، crate مستقل آزمون هویت و ignore/lock آن، تست‌های Python/MSI، اسکریپت پذیرش Windows و این گزارش. هیچ dependency جدیدی به برنامه اضافه نشده است.

پس از تأیید ظاهر و درخواست بیلد همهٔ پلتفرم‌ها، گردش‌کار `flutter-build.yml` شمارهٔ خروجی‌ها را با نسخهٔ ۱٫۵٫۳ هماهنگ می‌کند و متغیرهای API را از همان آدرس بیلد پیش‌نمایش ویندوز می‌گیرد؛ بدون این متغیرها، بنر زنده و سیاست آپدیت ویندوز در بیلد کامل غیرفعال می‌شدند. خروجی بدون امضای iOS نیز به‌صورت xcarchive در Artifacts ذخیره می‌شود تا بعداً با حساب Apple امضا و آزمایش شود. مسیرهای کامپایل، امضا و انتشار موجود تغییر نکرده‌اند. بیلد کامل با تگ آزمایشی و prerelease اجرا می‌شود و جایگزین Latest پایدار نیست.


## CI build correction (2026-10-07)

The 1.5.3 builds stopped because the root Cargo.lock still listed rustdesk 1.5.2. The Windows i686 job, which resolves its lock separately, additionally found unsupported cfg attributes on expressions in the new LAN/direct-port branches. The fix keeps dependency pins, service identity, and port values unchanged.

Regression surface of this correction:

| Existing file/path | Necessary change |
|---|---|
| Cargo.lock / every locked Cargo build | Match the root package version to Cargo.toml (1.5.3); no dependency upgrade or removal of --locked. |
| src/lan.rs / LAN broadcast port | Put each platform result in a cfg block accepted by stable Rust 1.75; Windows remains 21219 and other platforms remain 21119. |
| src/rendezvous_mediator.rs / direct listener default | Put the non-Windows assignment in a cfg block; Windows remains 21218, other platforms remain 21118, and explicit configured ports still win. |
| res/abrit/test_identity.py / Windows preview validation | Assert the native, locked, Flutter and workflow versions agree before the expensive build. |
| This report | Record failure evidence, minimal patch surface and verification. |

Verification: five Python identity/MSI/version tests pass. The actual two modified port functions were extracted from production source, compiled with Rust 1.75 for both platform branches, and executed to check defaults and an explicit 30000 override. Full application compilation and service acceptance are verified by the new Actions runs rather than claimed from these focused checks.
