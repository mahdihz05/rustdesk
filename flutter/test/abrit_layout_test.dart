import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/abrit/brand.dart';
import 'package:flutter_hbb/abrit/device_card.dart';
import 'package:flutter_hbb/abrit/directional.dart';
import 'package:flutter_hbb/abrit/home.dart';
import 'package:flutter_hbb/abrit/shell.dart';
import 'package:flutter_hbb/abrit/widgets.dart';

Widget harness(
        {required ValueNotifier<AbritDestination> destination,
        required TextEditingController controller,
        FocusNode? focus,
        String language = 'en',
        bool dark = false,
        ValueChanged<String>? onCopy,
        VoidCallback? onSecurity}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('fa')],
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
        version: '1.5.0',
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
          connectionCard:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AbritCardHeading(
                icon: Icons.send_outlined,
                title: language == 'fa'
                    ? 'اتصال به دستگاه دیگر'
                    : 'Connect to another device',
                description: language == 'fa'
                    ? 'شناسهٔ دستگاه مقصد را وارد کنید.'
                    : 'Enter the remote device ID.'),
            const SizedBox(height: 20),
            Builder(
                builder: (context) => TextField(
                    key: const ValueKey('test-remote-id'),
                    controller: controller,
                    focusNode: focus,
                    textDirection: TextDirection.ltr,
                    style:
                        const TextStyle(fontFamily: 'NotoSans', fontSize: 22),
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
                      contentPadding: const EdgeInsets.all(18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color:
                                  AbritColors.muted(context).withOpacity(.2))),
                    ))),
            const SizedBox(height: 16),
            AbritConnectButton(
                onPressed: () {},
                label: language == 'fa' ? 'اتصال' : 'Connect'),
          ]),
          peers: const Center(child: Text('Saved devices')),
          help: const SizedBox.shrink(),
          status: const SizedBox.shrink(),
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
    const Size(800, 600),
    const Size(899, 650),
    const Size(900, 650),
    const Size(1024, 768),
    const Size(1099, 700),
    const Size(1100, 700),
    const Size(1280, 850),
    const Size(1920, 1080)
  ];

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
          if (size.width >= 1100) {
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
            tester.getRect(find.byKey(const ValueKey('abrit-device'))).bottom,
            lessThanOrEqualTo(
                tester.getRect(find.byKey(const ValueKey('abrit-form'))).top));
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
