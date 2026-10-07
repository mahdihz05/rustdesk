# بازطراحی abritdesk

نسخهٔ تصویری تأییدشدهٔ 1.5.0 از کامیت `092261965` اکنون به‌عنوان آخرین Release در [GitHub](https://github.com/mahdihz05/rustdesk/releases/latest) منتشر شده است. بنر زنده و سیاست آپدیت اختیاری/اجباری در پیش‌نمایش 1.5.1 اضافه شد؛ بیلد 1.5.2 آدرس API را به دامنهٔ موجود `serverdesk.abrit.cloud` متصل می‌کند. قرارداد API، رفتار قطعی و آزمون‌های استقرار در [ABRIT_CLIENT_API.md](ABRIT_CLIENT_API.md) و راهنمای پنل و بستهٔ انتقال کامل در [راهنمای سرور](../server/abrit-control/README.md) آمده است. نسخهٔ تازه تا تأیید بیلد و آزمون‌های لازم جایگزین انتشار تأییدشده نمی‌شود.

قاب جدید برای پنجرهٔ اصلی دسکتاپ به صفحات خانه، اتصال، دستگاه‌ها، دفترچهٔ آدرس و تنظیمات وصل شده است. عملیات اتصال، کنترل‌کنندهٔ شناسه، پیشنهاد دستگاه‌ها، مدل فهرست‌ها و تنظیمات امنیتی همان پیاده‌سازی موجود هستند.

اصلاحات آمادهٔ 1.5.3 شامل استقلال هویت ویندوز و سرویس، برند ثابت سمت چپ، انتخاب زبان هدر و بزرگ‌ترشدن بنر است. جزئیات هویت‌ها، تست‌ها، محدودیت‌های اعتبارسنجی و سطح اثر تمام فایل‌ها در [ABRIT_WINDOWS_IDENTITY.md](ABRIT_WINDOWS_IDENTITY.md) ثبت شده‌اند. این مرحله هنوز منتشر یا در GitHub Actions اجرا نشده است.

## چیدمان و جهت

- عرض ۱۱۰۰ به بالا: منوی ۲۳۰ پیکسلی و دو کارت کنار هم.
- عرض ۷۶۰ تا ۱۰۹۹: منوی کامل ۱۶۸ پیکسلی و کارت‌های جمع‌وجور کنار هم، اگر عرض محتوای قابل استفاده حداقل ۵۶۰ باشد.
- عرض ۶۰۰ تا ۷۵۹: منوی آیکونی ۷۲ پیکسلی؛ دو کارت جمع‌وجور در عرض محتوای حداقل ۵۶۰ کنار هم قرار می‌گیرند.
- عرض کمتر از ۶۰۰: منوی بازشونده از سمت شروع زبان.
- عرض کمتر از ۱۱۰۰ یا ارتفاع کمتر از ۷۰۰: کارت‌ها، بخش تصویری و بنر جمع‌وجور می‌شوند؛ کنترل‌ها اندازهٔ خوانا و قابل کلیک دارند.
- محتوا اسکرول عمودی دارد؛ ابزارهای فهرست دستگاه‌ها اسکرول افقی داخلی دارند.
- مقصد اتصال، فرم را در بالای صفحه نمایش می‌دهد؛ کارت دستگاه و بنر خانه پنهان می‌شوند و وضعیتشان حفظ می‌شود.
- فارسی: منو و کارت دستگاه سمت راست؛ انگلیسی: سمت چپ. کنترل‌های پنجرهٔ ویندوز در سمت راست باقی می‌مانند.
- برند هدر در تمام زبان‌ها سمت چپ است؛ انتخابگر عربی/فارسی/انگلیسی در سمت راست برند قرار دارد.
- ارتفاع بنر در پنجرهٔ کوتاه حداقل ۹۶، متوسط ۱۲۰ و بزرگ ۱۶۰ پیکسل است.
- شناسه و رمز در کارت، ورودی اتصال و مقادیر فنی تنظیمات جهت LTR دارند. تنها تصویر بدون نوشتهٔ سرورها در فارسی قرینه می‌شود.
- خانه و فهرست‌ها با Offstage نگه داشته می‌شوند؛ کلیدهای پایدار کارت‌ها، کنترل‌کنندهٔ اصلی ورودی و PageView تنظیمات از بازسازی وضعیت هنگام Resize جلوگیری می‌کنند.
- «دسترسی بدون تأیید» مقدار واقعی `approveMode == 'password'` را نشان می‌دهد و تنظیمات امنیتی را باز می‌کند. این کنترل مستقیماً امنیت اتصال را تغییر نمی‌دهد.
- مسیر ویژهٔ کلاینت incoming-only، با اندازه و چیدمان اختصاصی قبلی خود باقی مانده است. پنجره‌های نشست، انتقال فایل، ترمینال و مدیر اتصال قاب قبلی خود را دارند.

تعریف اندازهٔ اولیهٔ ۸۰۰×۶۰۰ در runnerها و منطق ذخیره/بازیابی اندازه، موقعیت و Maximize تغییر نکرده‌اند. چیدمان جدید هیچ فراخوانی تنظیم اندازه یا محدودیت حداقل اندازه اضافه نمی‌کند.

در اندازهٔ شروع ۸۰۰×۶۰۰، ورودی شناسهٔ مقصد و دکمهٔ اتصال همراه با کارت شناسه/رمز دستگاه، بخش تصویری، بنر و دکمهٔ نصب هم‌زمان قابل مشاهده‌اند و به اسکرول نیاز ندارند. برای پنجره‌های کوچک‌تر که فضای دو کارت را ندارند، چیدمان تک‌ستونه و اسکرول همچنان در دسترس است.

## منابع و برند

فونت‌های Vazirmatn و Noto Sans همراه مجوز OFL بسته‌بندی شده‌اند. تصویر روشن سرورها و بنر تیره مستقل هستند؛ همهٔ تیترها و توضیحات متن واقعی و قابل ترجمه‌اند.

لوگوی ارسالی Abrit (ابر و عبارت INFINITE CLOUD) در `res/abrit/logo-source.jpg` نگهداری می‌شود. نشان کامل با نسبت اصلی در سربرگ و بنر و نشان ابر در آیکون اجرا، تسک‌بار و سینی سیستم استفاده می‌شود. نام نمایشی محصول `abritdesk` است.

```powershell
python res/abrit/generate_brand_assets.py
```

از نسخهٔ 1.5.3 هویت فنی ویندوز، نام سرویس، نصب، رجیستری، URI و UpgradeCode از RustDesk جدا می‌شوند. خروجی ویندوز `AbritDesk.exe` و پوشهٔ نصب پیش‌فرض `Program Files\AbritDesk` است؛ نام کتابخانهٔ Rust و نمادهای FFI برای سازگاری پل موجود حفظ شده‌اند. حقوق و انتساب upstream حفظ شده‌اند.

## اعتبارسنجی انجام‌شده

با Flutter 3.24.5 / Dart 3.5.4، آزمون مستقل از FFI روی کپی مستقیم فایل‌های واقعی `flutter/lib/abrit` اجرا شد:

```powershell
python res/abrit/check_ui.py --flutter-sdk C:/Users/m.hosseinzadeh/.cache/abritdesk-tools/flutter
```

اسکریپت، یک پروژهٔ موقت با همان منابع و آزمون‌ها می‌سازد؛ وابستگی و lockfile پروژهٔ اصلی را تغییر نمی‌دهد.

- تحلیل استاتیک اجزای جدید: بدون خطا و هشدار.
- ۹ آزمون Widget موفق، با بارگذاری فونت‌های واقعی و آیکون‌ها.
- ۴۴ ترکیب تغییر اندازه در فارسی/انگلیسی و روشن/تیره: ۳۶۰×۵۰۰، ۵۹۹×۶۰۰، ۶۰۰×۶۰۰، ۸۰۰×۶۰۰، ۸۹۹×۶۵۰، ۹۰۰×۶۵۰، ۱۰۲۴×۷۶۸، ۱۰۹۹×۷۰۰، ۱۱۰۰×۷۰۰، ۱۲۸۰×۸۵۰ و ۱۹۲۰×۱۰۸۰.
- حفظ متن، انتخاب و تمرکز ورودی و وضعیت نمایش رمز پس از Resize و ناوبری.
- صحت مقدار واقعی کپی شناسه/رمز و بازشدن تنظیمات امنیتی بدون تغییر مستقیم روش تأیید.
- تغییر devicePixelRatio در ۱۰۰٪، ۱۲۵٪ و ۱۵۰٪ با اندازهٔ منطقی ثابت؛ جای کنترل‌های پنجره در هر دو زبان.
- جهت منوی بازشونده و حفظ فاصله‌های قدیمی خارج از قاب جدید.
- تولید نام نمایشی MSI در پوشهٔ موقت: Product فنی و UpgradeCode ثابت، نام میان‌برهای جدید صحیح و انتساب upstream حفظ شده است.
- بررسی نحوی اسکریپت‌های Python و `git diff --check` موفق.

پیش‌نمایش‌های محلی `flutter/abrit-preview-*.png` از اجزای واقعی قاب، کارت دستگاه و بنر با دادهٔ نمونه تهیه شده‌اند. فرم داخل پیش‌نمایش، فرم آزمایشی است؛ این تصاویر اسکرین‌شات نسخهٔ اجرایی متصل به Rust نیستند.

تحلیل کل `flutter/lib` در فایل‌های تغییرکرده خطای تازه نشان نداد. تحلیل کل پروژه هنوز به‌علت نبود `flutter/lib/generated_bridge.dart` کامل موفق نمی‌شود؛ در همین محیط فاقد پل، یک خطای نوع در `file_manager_page.dart` هم گزارش می‌شود که فایل آن در این تغییر دست نخورده است. `pub get` پروژهٔ اصلی نیز ناسازگاری lockfile با SDK انتخابی و نبود پشتیبانی symlink ویندوز را نشان داد؛ lockfile اصلی حفظ شده است.

ساخت native و نصب/ارتقا اجرا نشده‌اند: زیرماژول `libs/hbb_common` خالی است و ابزارهای Cargo/CMake/Visual C++ در این محیط آماده نیستند. اتصال واقعی، Enter و پیشنهادها، تمام فرم‌های تنظیمات و فهرست‌های دارای دادهٔ واقعی، اولین اجرا/بازیابی پنجره و جابه‌جایی میان مانیتورهای ویندوز باید روی خروجی اجرایی بررسی شوند. آزمون devicePixelRatio جای آزمون DPI واقعی ویندوز را نمی‌گیرد.

## پیش‌نمایش Windows در GitHub Actions

گردش‌کار `.github/workflows/abritdesk-windows-preview.yml` روی شاخهٔ `feat/abritdesk-responsive-preview` با Push یا اجرای دستی ساخته می‌شود. خروجی برنامه فقط Windows x64 است؛ یک job لینوکس فایل‌های Bridge مورد نیاز این خروجی را تولید می‌کند. نسخه‌های Flutter، Rust، LLVM و vcpkg مطابق گردش‌کار پیش‌نمایش موفق موجود مخزن هستند.

در صفحهٔ اجرای **abritdesk Windows Preview**، فایل **abritdesk-windows-x64-preview** را از بخش Artifacts دانلود و تمام ZIP را استخراج کنید، سپس `abritdesk.exe` را اجرا کنید. پوشهٔ `data` و DLLها باید کنار فایل اجرایی بمانند. هویت تنظیمات موجود حفظ می‌شود. فایل `PREVIEW.txt` شناسهٔ commit و `SHA256SUMS.txt` هش محتویات را ثبت می‌کند. خروجی ۱۴ روز نگهداری می‌شود.

این گردش‌کار تحلیل Dart و آزمون‌های چیدمان را اجرا می‌کند و وجود فایل‌های اجرایی، کتابخانه و منابع جدید را پیش از انتشار artifact بررسی می‌کند. این خروجی برای بررسی ظاهر، بدون امضای دیجیتال، نصب‌کننده یا کدک سخت‌افزاری ساخته می‌شود. گردش‌کارهای کامل انتشار قبلی برای سایر خروجی‌ها همچنان مسیر خود را دارند.

تغییر موجود CI فقط افزودن ورودی اختیاری `legacy-only` به `bridge.yml` است؛ مقدار پیش‌فرض false، هر دو Bridge قبلی را تولید می‌کند. پیش‌نمایش Windows x64 مقدار true می‌فرستد تا Bridge مخصوص ARM64 تولید نشود. کد اندازهٔ شروع پنجره، بازیابی تنظیمات یا رفتار اجرا در این مرحله تغییر نمی‌کند.

## سطح تغییر مسیرهای موجود و بازبینی حداقل تغییرات

اصلاح خروجی خالی: نوار تب مخفی دیگر `Obx` بدون وابستگی واکنشی نمی‌سازد و نوار وضعیت داخل اسکرول عرض محدود دریافت می‌کند. اکشن بعد از ساخت، خود فایل اجرایی را در فارسی/انگلیسی و روشن/تیره اجرا می‌کند. در هر حالت پنج اندازه و پنج مقصد ثبت می‌شود؛ خطای Flutter/GetX یا بسته‌شدن برنامه باعث شکست اکشن می‌شود. عکس‌های اجرای واقعی در artifact جداگانهٔ `abritdesk-ui-screenshots` قرار دارند و فایل اجرایی پس از موفقیت این مرحله آپلود می‌شود.

ابزار آزمون فقط با `ABRIT_UI_SMOKE_DIR` فعال است. زبان، تم و تغییر اندازهٔ خودکار آن در اجرای معمولی فعال نیست؛ تعریف اندازهٔ شروع و بازیابی پنجره تغییر نکرده است. سطح تغییر این اصلاح: مسیر `showTabBar=false` در `tabbar_widget.dart`، عرض نوار وضعیت در `abrit/home.dart`، دو hook اختیاری ابزار آزمون در `main.dart` و `abrit/runtime.dart`، منابع برند و نام نمایشی و گردش‌کار Windows. شبکه و مدل اتصال تغییر نکرده‌اند.

| فایل‌های موجود | علت تغییر مسیر اجرا |
|---|---|
| `flutter/lib/main.dart` | تم و زبان پنجرهٔ اصلی؛ تصمیم چیدمان فهرست‌ها از عرض منطقی، برای حفظ رفتار هنگام تغییر DPI |
| `flutter/lib/desktop/pages/desktop_tab_page.dart` | قاب، ناوبری و اتصال به تب‌های موجود؛ incoming-only همان مسیر قبلی را دارد |
| `flutter/lib/desktop/widgets/tabbar_widget.dart` | گزینهٔ اختیاری `showTabBar` با مقدار پیش‌فرض true؛ تنها قاب جدید نوار تب را پنهان می‌کند |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | اتصال کارت و چیدمان جدید به ServerModel و کارت‌های وضعیت/نصب موجود |
| `flutter/lib/desktop/pages/connection_page.dart` | شاخهٔ اختیاری ظاهر جدید و اندازهٔ پیشنهادها؛ کنترل‌کننده، Enter، گزینه‌های اتصال و عملیات قبلی حفظ شده‌اند |
| `flutter/lib/common/widgets/peer_tab_page.dart` | ارائهٔ مدل‌ها و عملیات فهرست‌های موجود در صفحات دستگاه‌ها و دفترچه؛ ابزارها در فضای کم قابل اسکرول هستند |
| `flutter/lib/common/widgets/address_book.dart`, `my_group.dart`, `peer_card.dart` | فاصله، تراز و گوشه‌ها فقط داخل قاب جدید جهت‌دار می‌شوند؛ ورودی‌های فنی RDP در پنجرهٔ اصلی LTR هستند |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | ناوبری جمع‌وجور، کارت‌های منعطف، تراز و ورودی‌های فنی؛ فرم‌ها، مجوزها و اعمال تنظیمات قبلی باقی هستند |
| `flutter/lib/common.dart`, `flutter/lib/mobile/pages/home_page.dart` | عنوان‌ها و نام نمایشی محصول؛ تغییر برند در خروجی موبایل/وب، بدون بازطراحی آن صفحات |
| `flutter/pubspec.yaml`, `.gitignore` | بسته‌بندی فونت‌ها و منابع جدید، بدون افزودن وابستگی برنامه |
| `src/common.rs`, `src/lang.rs` | نام نمایشی مستقل و جایگزینی نام در متن‌های UI؛ هویت فنی و کلیدهای ترجمه ثابت‌اند |
| `src/tray.rs`, `src/core_main.rs` | نام نمایشی سینی و اعلان نصب/به‌روزرسانی |
| `src/platform/windows.rs` | نام نمایشی نصب/میان‌بر و سرویس؛ پاک‌سازی میان‌بر قدیمی هنگام جایگزینی؛ یافتن پنجره با عنوان جدید و قدیم برای حفظ URI/IPC |
| `flutter/windows/runner/main.cpp`, `Runner.rc` | عنوان و metadata نمایشی؛ fallback تشخیص نمونهٔ قبلی؛ اندازهٔ شروع بدون تغییر |
| `flutter/linux/my_application.cc`, `res/rustdesk.desktop`, `res/rustdesk-link.desktop` | نام قابل نمایش در پنجره و لانچر؛ شناسه و فرمان اجرا ثابت‌اند |
| `flutter/macos/Runner/MainFlutterWindow.swift`, `Info.plist`, `Base.lproj/MainMenu.xib` | نام پنجره، برنامه و منو؛ اندازهٔ XIB و شناسهٔ bundle ثابت‌اند |
| `flutter/ios/Runner/Info.plist` | فقط نام نمایشی/نام برنامه |
| `flutter/android/app/src/main/AndroidManifest.xml`, `res/values/strings.xml`, `BootReceiver.kt`, `MainService.kt` | نام برنامه، accessibility و اعلان‌ها؛ channel ID و شناسهٔ Android ثابت‌اند |
| `flutter/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml` | منبع آیکون تک‌رنگ برای نشان جدید |
| `res/msi/preprocess.py`, `Package/Package.wxs`, `Package/Components/RustDesk.wxs` | DisplayProduct مستقل؛ نام و حذف میان‌بر جدید؛ Product/رجیستری/UpgradeCode فنی ثابت |
| منابع آیکون موجود در `flutter/android/.../mipmap-*`, `flutter/ios/.../AppIcon.appiconset`, `flutter/windows/.../app_icon.ico`, `flutter/macos/Runner/AppIcon.icns`, `flutter/assets/icon.svg`, و `res` | جایگزینی ظاهر آیکون‌ها، لوگو و منابع سینی/لانچر در تمام خروجی‌ها |

در بازبینی diff، تغییرات قالب‌بندی عمومی و فاصله‌های متقارن غیرضروری کنار گذاشته شدند. مدل شبکه، API، کنترل اتصال، فایل داده و وابستگی‌های فنی تغییر نکرده‌اند. شاخه‌های مشترک خارج از قاب جدید مقدار پیش‌فرض و چیدمان قدیمی خود را حفظ می‌کنند؛ استثنای عمدی، نام نمایشی محصول است.

## اصلاحات بازخورد نمای ویندوز — ۴ اکتبر ۲۰۲۶

- ردیف ID/Relay Server در تنظیمات دسکتاپ نمایش داده نمی‌شود. مقدار سرورهای ذخیره‌شده، کلید، API و مسیر اتصال تغییری نکرده‌اند.
- صفحهٔ درباره در دسکتاپ فقط برند abritdesk، نسخه، تاریخ ساخت، شناسه، اثر انگشتِ موجود و وب‌سایت محصول را نمایش می‌دهد؛ محتوای تبلیغاتی، نام شرکت و لینک حریم خصوصی محصول قبلی در این صفحه نمایش داده نمی‌شوند. فایل‌های مجوز و هویت‌های فنی در مخزن باقی هستند.
- منوی عملیات کنار اتصال از PopupMenuButton استاندارد استفاده می‌کند تا باکس نسبت به خود دکمه و لایهٔ overlay جای‌گذاری شود. چهار عملیات موجود همان onConnect قبلی را فراخوانی می‌کنند؛ مسیر نمای قدیمی تغییر نکرده است.
- نصب/ارتقا در کادر منوی کناری قرار دارد: تیره در تم روشن و روشن در تم تیره. در عرض ۸۰۰، کادر به دکمهٔ آیکونی با عنوان و راهنما تبدیل می‌شود؛ در منوی بازشونده، متن کامل نشان داده می‌شود. وضعیت نصب از همان backend فعلی خوانده و همان عملیات نصب/ارتقا اجرا می‌شود. هشدارهای دیگر همچنان در محتوای صفحه باقی هستند.
- لوگوی تکراری انتهای منو حذف شد؛ نسخه همچنان نمایش داده می‌شود.
- انتخاب زبان، locale فعال GetX را هم به‌روز می‌کند. تغییر فارسی به انگلیسی/آلمانی در همان جلسه، جهت و محل منو را اصلاح می‌کند و وضعیت فرم باقی می‌ماند. اندازهٔ شروع ۸۰۰×۶۰۰ و کد ذخیره/بازیابی پنجره تغییر نکرده‌اند.

آزمون‌های ویجت اکنون ۱۳ مورد هستند و جای منوی اتصال در فارسی/انگلیسی و عرض‌های ۱۲۸۰، ۸۰۰ و ۴۸۰، فراخوانی عملیات انتخاب‌شده، جای کادر نصب، جهت فارسی/عربی/انگلیسی/آلمانی/فرانسوی و صفحهٔ درباره را هم بررسی می‌کنند. ابزار اجرای واقعی ویندوز در هر یک از چهار حالت زبان/تم، ۱۴ تصویر می‌گیرد: پنج اندازه، پنج مقصد، شبکه، درباره و دو تغییر زبان در همان جلسه (تصویر نهایی خانه بازنویسی می‌شود). این ابزار فقط با متغیر محیطی آزمون فعال است و زبان قبلی را بازیابی می‌کند. آزمون اتصال به دستگاه راه دور و نصب واقعی روی سیستم در این مرحله انجام نمی‌شوند.

سطح تغییر این بازخورد پس از بازبینی diff:

| مسیر موجود | دلیل تغییر ضروری |
|---|---|
| `abrit/shell.dart` | محل کادر نصب زیر منو و حذف لوگوی تکراری؛ اسکرول منو در پنجرهٔ کوتاه حفظ می‌شود |
| `abrit/runtime.dart`, `abrit/smoke.dart` | آزمون تغییر زبان واقعی و تصاویر شبکه/درباره؛ override زبان فقط هنگام آغاز آزمون اعمال می‌شود |
| `desktop_tab_page.dart` | افزودن کادر نصب به قاب و دو callback اختیاری آزمون تنظیمات |
| `desktop_home_page.dart` | نمایش نصب/ارتقا در قاب جدید به منو منتقل می‌شود؛ مسیر incoming-only قدیمی باقی می‌ماند |
| `connection_page.dart` | شاخهٔ جدید منوی اتصال متصل به دکمه؛ لینک راهنمای سرور عمومی به وب‌سایت محصول اشاره می‌کند |
| `desktop_setting_page.dart` | پنهان‌کردن سرور، دربارهٔ جدید و به‌روزرسانی locale هنگام انتخاب زبان |
| `tabbar_widget.dart`, `install_page.dart` | عنوان پنجره‌های دیگر و لینک قابل‌دیدن نصب از برند فعلی استفاده می‌کنند |
| `common.dart`, `src/lang.rs` | حذف استثناهای نام نمایشی Powered by و پیام نسخهٔ سرور؛ کلیدها و URLهای مستندات دست‌نخورده‌اند |
| `abrit_layout_test.dart`, `check_ui.py`, `smoke_windows.ps1` | پوشش موارد جدید و حفظ جدایی آزمون ویجت از backend بومی |

نتیجهٔ این مرحله: هر ۱۳ تست ویجت پاس شد؛ تحلیل `lib/abrit` بدون مورد و تحلیل مسیرهای تغییرکرده بدون خطای Dart بود (هشدارها و deprecationهای قبلی صفحات قدیمی باقی‌اند). اجرای واقعی ویندوز در هر چهار حالت با ۱۴ تصویر، در مجموع ۵۶ تصویر، بدون errors.txt و با complete.json پایان یافت؛ عکس‌های خانه، شبکه، درباره و تغییر زبان هم بازبینی تصویری شدند. زبان ذخیره‌شدهٔ کاربر بعد از آزمون بازیابی شد.

پیش‌نمایش محلی از کد Flutter جدید در کنار کتابخانه‌ها و موتور آخرین بیلد موفق ویندوز گرفته شد. چون نسخهٔ دانلودشدهٔ کاربر هم‌زمان باز بود و لانچر جدید از ایجاد نمونهٔ دوم جلوگیری می‌کند، برای اجرای جداگانهٔ پیش‌نمایش از لانچر محلی قبلی استفاده شد؛ تصاویر مستقیماً از رابط Flutter جدید در اجرای واقعی گرفته شدند. بازسازی کامل کتابخانهٔ Rust، شامل تغییر کوچک متن‌های بومی در `src/lang.rs`، در اکشن بعدی انجام خواهد شد. تا بررسی عکس‌های جدید توسط کاربر، تغییری به GitHub push نمی‌شود و اکشن تازه‌ای اجرا نمی‌شود.

## دسترسی مستقیم به اتصال در اندازهٔ شروع

بازخورد بعدی کاربر مشخص کرد که فرم اتصال باید در اولین نمای خانه دیده شود. اندازهٔ ۸۰۰×۶۰۰ حفظ شد و چیدمان خانه اصلاح شد: دو کارت در عرض محتوای حداقل ۶۰۰ کنار هم قرار می‌گیرند. در حالت جمع‌وجور، فاصلهٔ داخلی کارت ۱۶، ارتفاع ردیف شناسه/رمز و دکمهٔ اتصال ۴۸، بخش تصویری حداقل ۶۴ و بنر حداقل ۵۶ پیکسل است. تیترها و مقدارها با اندازهٔ مشخص و خوانا نمایش داده می‌شوند؛ توضیح طولانی کارت یک خط همراه با راهنمای متن کامل دارد. فرم، کنترل‌کننده، Enter، عملیات اتصال، کپی و نمایش رمز همان مسیر قبلی هستند.

تست جدید، فضای داخلی واقعی پنجرهٔ ویندوز با اندازهٔ ۷۸۴×۵۹۲ را شبیه‌سازی می‌کند و دیده‌شدن شناسه، رمز، ورودی مقصد، دکمهٔ اتصال، منوی عملیات، بنر و نصب را بدون اسکرول در فارسی/انگلیسی و روشن/تیره بررسی می‌کند. تعداد تست‌های ویجت ۱۴ است. مرز ۷۰۳/۷۰۴ برای گذار کارت‌ها به دو ستون هم به آزمون Resize اضافه شد. وضعیت ورودی و تمرکز همچنان در تغییر اندازه و ناوبری بررسی می‌شود.

سطح تغییر این اصلاح فقط ظاهر خانه است: `abrit/brand.dart` معیار چیدمان خانه را از معیار فهرست‌ها جدا نگه می‌دارد؛ `abrit/home.dart` محل کارت‌ها و فاصله‌ها را تنظیم می‌کند؛ `abrit/widgets.dart`، `abrit/device_card.dart` و `abrit/connection_options.dart` اندازه‌های جمع‌وجور را ارائه می‌کنند؛ `desktop/pages/connection_page.dart` فقط همین اندازه‌ها را به فرم موجود می‌دهد. تست‌های `abrit_layout_test.dart` معیار دیده‌شدن کنترل‌های اتصال را پوشش می‌دهند. مسیر incoming-only، تنظیمات، صفحات فهرست، backend و تعریف اندازهٔ شروع و بازیابی پنجره در این اصلاح تغییر نکرده‌اند.

نتیجهٔ نهایی این اصلاح: ۱۴ تست ویجت پاس شد؛ تحلیل مسیرهای تغییرکرده فقط deprecation قبلی ConnectionPage را گزارش داد و خطایی نداشت. اجرای واقعی ویندوز در چهار حالت فارسی/انگلیسی و روشن/تیره، با ۵۶ تصویر بدون خطای UI تمام شد. عکس‌های اندازهٔ ۸۰۰×۶۰۰ بازبینی شدند و ورودی مقصد، اتصال، شناسه، رمز، بنر و نصب هم‌زمان در پنجره دیده می‌شوند. تصاویر جدید در پوشهٔ `C:/projects/abritdesk/preview` با پیشوند `compact-home-` آمادهٔ بررسی‌اند؛ اکشن جدید تا بازخورد کاربر اجرا نمی‌شود.


## Windows 1.5.4: initial window and package branding (2026-10-07)

The latest requested reference supersedes the original 800x600 first-launch size.
The Windows main window now starts normally at 1160x920 logical pixels, centered,
clamped to its monitor's work area with 16 logical pixels of space per edge.
The previous preview's main-window frame is reset once using an AbritDesk-only
layout marker; subsequent launches restore user-selected geometry/maximized state.
Incoming-only, remote session, installer and non-Windows window paths retain their
existing sizing behavior. Header quick language choices are Persian and English;
other languages remain accessible through Settings.

Local verification: 27 Flutter tests passed in the isolated UI harness using the
production Abrit widgets (18 responsive sizes, light/dark, RTL/LTR, DPI 100/125/150/200%,
resize/input preservation and startup work-area arithmetic); two Rust ownership
tests and five Python native/MSI namespace checks passed. Native Windows startup,
restore, install/service/uninstall and actual installer metadata acceptance runs
on disposable GitHub-hosted Windows runners before publishing the x64 packages.

Regression surface (modified existing files and paths):

| File | Necessary changed path |
|---|---|
| `flutter/lib/main.dart` | One Windows main-window startup hook before the existing restore path. |
| `flutter/lib/abrit/runtime.dart` | Windows-only, once-per-layout initialization and opt-in smoke persistence; retains existing restoration afterwards. |
| `flutter/lib/abrit/language_toggle.dart` | Removes Arabic from the header quick choices only. |
| `flutter/lib/abrit/smoke.dart`, `res/abrit/smoke_windows.ps1` | Opt-in CI probe captures startup geometry and checks first normal launch, resized relaunch and maximized relaunch. |
| `libs/portable/Cargo.toml` | Corrects user-visible EXE resource metadata and packer version without renaming the technical crate/target. |
| `res/msi/preprocess.py` | Default installer manufacturer and support links become Abrit; service name, install directory and UpgradeCode logic retain their independent identities. |
| `Cargo.toml`, `Cargo.lock`, `flutter/pubspec.yaml` | Synchronizes release/packer/Flutter versions to 1.5.4 and Android build number 72 so the new package is distinguishable. |
| `.github/workflows/flutter-build.yml` | Windows release asset filenames use abritdesk; adds x64 UI, native and MSI install/service/uninstall acceptance before release. |
| `.github/workflows/abritdesk-windows-preview.yml` | Executes the new work-area sizing tests in the existing preview validation step. |
| `flutter/test/abrit_layout_test.dart`, `res/abrit/test_identity.py` | Asserts the two-language header, full default layout and matching packer metadata version. |
| `docs/ABRIT_UI.md` | Records this superseding request and the precise changed runtime paths. |

New `flutter/lib/abrit/window.dart` keeps window-size policy inside the Abrit UI;
`flutter/test/abrit_window_test.dart` checks work-area/DPI sizing. No service ownership,
network API, remote-control protocol, server credentials, signed driver identity or
shared submodule changes are needed. Native install and MSI install tests compare
stock RustDesk service/config/registry snapshots before and after each operation.
This is a stock-service sentinel test, not proof of two simultaneous live sessions.
