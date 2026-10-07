import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/abrit/brand.dart';
import 'package:flutter_hbb/abrit/device_card.dart';
import 'package:flutter_hbb/abrit/directional.dart';
import 'package:flutter_hbb/abrit/home.dart';
import 'package:flutter_hbb/abrit/shell.dart';
import 'package:flutter_hbb/abrit/widgets.dart';
import 'package:flutter_hbb/abrit/install_card.dart';
import 'package:flutter_hbb/abrit/connection_options.dart';
import 'package:flutter_hbb/abrit/about.dart';
import 'package:flutter_hbb/abrit/window.dart';

Widget harness(
        {required ValueNotifier<AbritDestination> destination,
        required TextEditingController controller,
        FocusNode? focus,
        String language = 'en',
        bool dark = false,
        VoidCallback? onInstall,
        VoidCallback? onTransfer,
        ValueChanged<String>? onLanguageChanged,
        ValueChanged<String>? onCopy,
        VoidCallback? onSecurity}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('fa'), Locale('de'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      theme: abritTheme(
          ThemeData(
              useMaterial3: false,
              brightness: dark ? Brightness.dark : Brightness.light),
          persian: language == 'fa'),
      home: Scaffold(
          body: AbritDesktopShell(
        destination: destination,
        onSelected: (page) => destination.value = page,
        onDrag: () {},
        onMaximize: () {},
        onLanguageChanged: onLanguageChanged,
        version: '1.5.4',
        navigationFooterBuilder: (_, compact) => AbritInstallCard(
            compact: compact, onPressed: onInstall ?? () {}),
        destinations: AbritDestination.values,
        windowControls: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 44, child: Icon(Icons.remove, size: 18)),
          SizedBox(width: 44, child: Icon(Icons.crop_square, size: 18)),
          SizedBox(width: 44, child: Icon(Icons.close, size: 18)),
        ]),
        child: AbritHomeLayout(
          deviceCard: AbritDeviceCard(
              id: '195 799 164',
              password: 'ab12CD34',
              unattended: false,
              onCopy: onCopy ?? (_) {},
              onRefreshPassword: () {},
              onSecuritySettings: onSecurity ?? () {}),
          connectionCard: Builder(builder: (context) {
            final compact = AbritScope.of(context).metrics.compactHome;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AbritCardHeading(
                compact: compact,
                icon: Icons.send_outlined,
                title: language == 'fa'
                    ? 'اتصال به دستگاه دیگر'
                    : 'Connect to another device',
                description: language == 'fa'
                    ? 'شناسهٔ دستگاه مقصد را وارد کنید.'
                    : 'Enter the remote device ID.'),
            SizedBox(height: compact ? 12 : 20),
            Builder(
                builder: (context) => TextField(
                    key: const ValueKey('test-remote-id'),
                    controller: controller,
                    focusNode: focus,
                    textDirection: TextDirection.ltr,
                    style:
                        TextStyle(fontFamily: 'NotoSans', fontSize: compact ? 20 : 22),
                    textAlign: language == 'fa' && controller.text.isEmpty
                        ? TextAlign.right
                        : TextAlign.left,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AbritColors.field(context),
                      hintText: abritText(context, 'Enter the remote device ID',
                          'شناسهٔ دستگاه را وارد کنید'),
                      hintStyle: TextStyle(
                          fontFamily:
                              language == 'fa' ? 'Vazirmatn' : 'NotoSans',
                          fontSize: 14),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: compact ? 10 : 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color:
                                  AbritColors.muted(context).withOpacity(.2))),
                    ))),
            const SizedBox(height: 13),
            Row(children: [Expanded(child: AbritConnectButton(
                compact: compact,
                onPressed: () {},
                label: language == 'fa' ? 'اتصال' : 'Connect')),
              const SizedBox(width: 8),
              AbritConnectionOptions(compact: compact, actions: [
                ('Transfer file', onTransfer ?? () {}),
                ('View camera', () {}),
                ('Terminal (beta)', () {}),
                ('TCP tunneling', () {}),
              ]),
            ]),
          ]);
          }),
          peers: const Center(child: Text('Saved devices')),
          help: const SizedBox.shrink(),
          status: const SizedBox(height: 42),
        ),
      )),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final name in ['Vazirmatn', 'NotoSans']) {
      final loader = FontLoader(name)
        ..addFont(rootBundle.load('assets/abrit/$name.ttf'));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  final sizes = [
    const Size(360, 500),
    const Size(599, 600),
    const Size(600, 600),
    const Size(655, 600),
    const Size(656, 600),
    const Size(703, 600),
    const Size(704, 600),
    const Size(759, 600),
    const Size(760, 600),
    const Size(800, 600),
    const Size(899, 650),
    const Size(900, 650),
    const Size(1024, 768),
    const Size(1099, 700),
    const Size(1100, 700),
    abritInitialWindowSize,
    const Size(1280, 850),
    const Size(1920, 1080)
  ];

  if (Platform.environment['ABRIT_UI_PREVIEW_DIR'] != null) {
    testWidgets('capture the current Flutter home for review', (tester) async {
      final destination = ValueNotifier(AbritDestination.home);
      final controller = TextEditingController();
      addTearDown(destination.dispose);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final spec in [('fa', false, const Size(784, 592)), ('fa', false, const Size(1280, 850)),
          ('en', false, const Size(1280, 850)), ('ar', false, const Size(784, 592)),
          ('fa', true, const Size(784, 592))]) {
        tester.view.physicalSize = spec.$3;
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: harness(destination: destination,
            controller: controller, language: spec.$1, dark: spec.$2, onLanguageChanged: (_) {})));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final asset in ['wordmark.png', 'servers.png', 'hero-light.png']) {
            await precacheImage(AssetImage('assets/abrit/$asset'), key.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final directory = Directory(Platform.environment['ABRIT_UI_PREVIEW_DIR']!);
          await directory.create(recursive: true);
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/home-${spec.$1}-${spec.$2 ? "dark" : "light"}-${spec.$3.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('header brand stays left and language buttons retain form state', (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController(text: '195799164');
    final changed = <String>[];
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(784, 592), const Size(1280, 850)]) {
      tester.view.physicalSize = size;
      for (final language in ['fa', 'ar', 'en', 'de', 'fr']) {
        await tester.pumpWidget(harness(destination: destination, controller: controller,
            language: language, onLanguageChanged: changed.add));
        await tester.pumpAndSettle();
        final logo = tester.getRect(find.byKey(const ValueKey('abrit-header-logo')));
        final toggle = tester.getRect(find.byKey(const ValueKey('abrit-header-language')));
        expect(logo.left, lessThan(50));
        expect(logo.right, lessThan(toggle.left));
        expect(toggle.right, lessThan(tester.getRect(find.byIcon(Icons.remove)).left));
        expect(find.byKey(const ValueKey('abrit-language-ar')), findsNothing);
        for (final choice in ['fa', 'en']) {
          final buttonLabel = tester.widget<Text>(find.descendant(
              of: find.byKey(ValueKey('abrit-language-$choice')), matching: find.byType(Text)));
          expect(buttonLabel.style!.fontFamily, choice == 'en' ? 'NotoSans' : 'Vazirmatn');
          await tester.tap(find.byKey(ValueKey('abrit-language-$choice')));
          expect(changed.last, choice);
          expect(controller.text, '195799164');
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('default window has menu labels and a larger banner at all display scales', (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      tester.view.devicePixelRatio = scale;
      tester.view.physicalSize = Size(1160 * scale, 920 * scale);
      await tester.pumpWidget(harness(destination: destination, controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('abrit-home-banner'))).height, greaterThanOrEqualTo(160));
      expect(tester.getRect(find.byKey(const ValueKey('abrit-home-banner'))).bottom, lessThan(920));
      expect(tester.getRect(find.byKey(const ValueKey('test-remote-id'))).bottom, lessThan(700));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('language changes mirror navigation and preserve the form', (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController(text: '195799164');
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 850);
    for (final language in ['fa', 'en', 'de', 'ar', 'fr', 'fa']) {
      await tester.pumpWidget(harness(destination: destination, controller: controller, language: language));
      await tester.pumpAndSettle();
      final install = tester.getRect(find.byKey(const ValueKey('abrit-install-card')));
      final content = tester.getRect(find.byKey(const ValueKey('abrit-main-content')));
      final rtl = language == 'fa' || language == 'ar';
      expect(rtl ? install.left >= content.right : install.right <= content.left, isTrue);
      expect(install.top, greaterThan(tester.getRect(find.byIcon(Icons.settings_outlined)).bottom));
      expect(controller.text, '195799164');
      expect(find.byType(AbritLogo), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('default Windows client area shows both forms and the banner without scrolling', (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(784, 592);
    for (final language in ['fa', 'en']) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(harness(destination: destination, controller: controller,
            language: language, dark: dark));
        await tester.pumpAndSettle();
        for (final key in ['abrit-device-id-field', 'abrit-device-password-field',
          'test-remote-id', 'abrit-connect-button', 'abrit-connection-options',
          'abrit-home-banner', 'abrit-install-card']) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.top, greaterThanOrEqualTo(72), reason: '$language/$dark/$key');
          expect(rect.bottom, lessThanOrEqualTo(550), reason: '$language/$dark/$key');
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(784));
        }
        expect(tester.getRect(find.byKey(const ValueKey('abrit-device'))).top,
            tester.getRect(find.byKey(const ValueKey('abrit-form'))).top);
        await tester.tap(find.byKey(const ValueKey('test-remote-id')));
        await tester.enterText(find.byKey(const ValueKey('test-remote-id')), '195799164');
        expect(controller.text, '195799164');
        await tester.tap(find.byKey(const ValueKey('abrit-connect-button')));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('installation stays usable in the rail and uses opposite theme color', (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    int installs = 0;
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    for (final dark in [false, true]) {
      await tester.pumpWidget(harness(destination: destination, controller: controller,
          language: 'fa', dark: dark, onInstall: () => installs++));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('abrit-install-card'));
      final rect = tester.getRect(card);
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThan(600));
      final color = tester.widget<Material>(card).color!;
      expect(color.computeLuminance() > .5, dark);
      await tester.tap(find.descendant(of: card, matching: find.byType(InkWell)));
      expect(tester.takeException(), isNull);
    }
    expect(installs, 2);
  });

  testWidgets('connection options stay anchored after resize and dispatch the selected action', (tester) async {
    final destination = ValueNotifier(AbritDestination.connection);
    final controller = TextEditingController();
    int transfers = 0;
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final language in ['fa', 'en']) {
      for (final size in [const Size(1280, 850), const Size(800, 600), const Size(480, 600)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(harness(destination: destination, controller: controller,
            language: language, onTransfer: () => transfers++));
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('abrit-connection-options'));
        final anchor = tester.getRect(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        final menu = tester.getRect(find.byType(PopupMenuItem<int>).first);
        expect((menu.left - anchor.left).abs() <= 20 ||
            (menu.right - anchor.right).abs() <= 20, isTrue);
        expect(menu.top, greaterThanOrEqualTo(anchor.bottom));
        expect(menu.right, lessThanOrEqualTo(size.width));
        await tester.tap(find.text('Transfer file'));
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuItem<int>), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
    expect(transfers, 6);
  });

  testWidgets('about shows abritdesk with readable technical values in both directions', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final language in ['fa', 'en']) {
      for (final size in [const Size(480, 600), const Size(1024, 768)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(MaterialApp(locale: Locale(language),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: Scaffold(body: AbritAbout(version: '1.5.0', buildDate: '2026-10-04',
            fingerprint: 'A0 B1 C2 D3 E4 F5 0123456789ABCDEF0123456789ABCDEF',
            deviceId: '195799164', onWebsiteOpen: () {}))));
        await tester.pumpAndSettle();
        expect(find.text('abritdesk'), findsOneWidget);
        expect(find.textContaining('RustDesk'), findsNothing);
        expect(find.textContaining('Purslane'), findsNothing);
        expect(tester.widget<SelectableText>(find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == '195799164')).textDirection, TextDirection.ltr);
        expect(tester.takeException(), isNull);
      }
    }
  });

  for (final language in ['en', 'fa']) {
    for (final dark in [false, true]) {
      testWidgets(
          'resize without overflow: $language ${dark ? "dark" : "light"}',
          (tester) async {
        final destination = ValueNotifier(AbritDestination.home);
        final controller = TextEditingController();
        addTearDown(destination.dispose);
        addTearDown(controller.dispose);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1280, 850);
        await tester.pumpWidget(harness(
            destination: destination,
            controller: controller,
            language: language,
            dark: dark));
        await tester.pumpAndSettle();
        for (final size in sizes) {
          tester.view.physicalSize = size;
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$language $dark $size');
          final device =
              tester.getRect(find.byKey(const ValueKey('abrit-device')));
          final form = tester.getRect(find.byKey(const ValueKey('abrit-form')));
          if (size.width >= 656) {
            expect(device.top, form.top);
            expect(
                language == 'fa'
                    ? device.left > form.left
                    : device.left < form.left,
                isTrue);
          } else {
            expect(device.bottom <= form.top, isTrue);
          }
        }
      });
    }
  }

  testWidgets(
      'input, focus and password visibility survive resize and navigation',
      (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 850);
    await tester.pumpWidget(harness(
        destination: destination, controller: controller, focus: focus));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('abrit-password-visibility')));
    await tester.tap(find.byKey(const ValueKey('test-remote-id')));
    await tester.enterText(
        find.byKey(const ValueKey('test-remote-id')), '195799164');
    final selection = controller.selection;
    for (final size in [
      const Size(800, 600),
      const Size(500, 600),
      const Size(1280, 850)
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(controller.text, '195799164');
      expect(controller.selection, selection);
      expect(focus.hasFocus, isTrue);
      expect(find.text('ab12CD34'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    destination.value = AbritDestination.devices;
    await tester.pumpAndSettle();
    expect(find.text('Saved devices'), findsOneWidget);
    tester.view.physicalSize = const Size(800, 600);
    destination.value = AbritDestination.connection;
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('test-remote-id'))).bottom,
        lessThan(600));
    expect(controller.text, '195799164');
    expect(
        find.byKey(const ValueKey('abrit-password-visibility')), findsNothing);
    destination.value = AbritDestination.home;
    await tester.pumpAndSettle();
    expect(controller.text, '195799164');
    expect(find.text('ab12CD34'), findsOneWidget);
  });

  testWidgets('copy uses real values; security shortcut does not toggle state',
      (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    String copied = '';
    int securityOpened = 0;
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 850);
    await tester.pumpWidget(harness(
        destination: destination,
        controller: controller,
        language: 'fa',
        onCopy: (value) => copied = value,
        onSecurity: () => securityOpened++));
    await tester.pumpAndSettle();
    expect(find.text('ab12CD34'), findsNothing);
    expect(find.text('••••••••'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('abrit-copy-id')));
    expect(copied, '195 799 164');
    await tester.tap(find.byKey(const ValueKey('abrit-copy-password')));
    expect(copied, 'ab12CD34');
    await tester.tap(find.byType(Switch));
    expect(securityOpened, 1);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    final id = tester.widget<SelectableText>(find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == '195 799 164'));
    expect(id.data, '195 799 164');
  });

  testWidgets('logical window size stays responsive across display scales',
      (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in ['en', 'fa']) {
      for (final scale in [1.0, 1.25, 1.5]) {
        tester.view.devicePixelRatio = scale;
        tester.view.physicalSize = Size(800 * scale, 600 * scale);
        await tester.pumpWidget(harness(
            destination: destination,
            controller: controller,
            language: language));
        await tester.pumpAndSettle();
        expect(
            tester.getRect(find.byKey(const ValueKey('abrit-device'))).top,
            tester.getRect(find.byKey(const ValueKey('abrit-form'))).top);
        expect(
            tester.getRect(find.byIcon(Icons.close)).right, greaterThan(750));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('directional spacing applies only inside the branded shell',
      (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    addTearDown(destination.dispose);
    Widget content(bool branded) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
            width: 200,
            height: 100,
            child: branded
                ? AbritScope(
                    metrics: const AbritLayoutMetrics(200, 100),
                    destination: destination,
                    child: const SizedBox(key: ValueKey('spacing-probe'))
                        .abritMarginOnly(start: 20))
                : const SizedBox(key: ValueKey('spacing-probe'))
                    .abritMarginOnly(start: 20)));
    await tester.pumpWidget(content(false));
    final original =
        tester.getRect(find.byKey(const ValueKey('spacing-probe')));
    await tester.pumpWidget(content(true));
    final directional =
        tester.getRect(find.byKey(const ValueKey('spacing-probe')));
    expect(original.left - directional.left, 20);
    expect(original.right - directional.right, 20);
  });

  testWidgets(
      'drawer opens on the locale start side and closes after selection',
      (tester) async {
    final destination = ValueNotifier(AbritDestination.home);
    final controller = TextEditingController();
    addTearDown(destination.dispose);
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 600);
    await tester.pumpWidget(harness(
        destination: destination, controller: controller, language: 'fa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('دستگاه‌ها')).center.dx, greaterThan(250));
    await tester.tap(find.text('دستگاه‌ها'));
    await tester.pumpAndSettle();
    expect(destination.value, AbritDestination.devices);
    expect(find.byIcon(Icons.contact_page_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
