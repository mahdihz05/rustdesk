import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/abrit/brand.dart';
import 'package:flutter_hbb/abrit/control.dart';
import 'package:flutter_hbb/abrit/control_widgets.dart';
import 'package:flutter_hbb/abrit/live_banner.dart';

String snapshot(
        {bool blocked = false,
        bool checking = false,
        bool error = false,
        String version = '1.5.1',
        String latest = '1.5.2',
        String minimum = '1.5.0',
        String revision = 'a',
        bool bannerEnabled = true,
        bool includeDocument = true}) =>
    jsonEncode({
      'enabled': true,
      'checking': checking,
      'blocked': blocked,
      'error': error,
      'current_version': version,
      'document': !includeDocument
          ? null
          : {
              'schema_version': 1,
              'revision': revision,
              'banner': {
                'enabled': bannerEnabled,
                'revision': revision,
                'title': {'fa': 'بنر $revision', 'en': 'Banner $revision'},
                'subtitle': {'fa': 'متن فارسی', 'en': 'English text'},
                'link_url': 'https://abritdesk.ir/offers'
              },
              'update': {
                'latest_version': latest,
                'minimum_version': minimum,
                'download_url': 'https://abritdesk.ir/download/windows',
                'message': {
                  'fa': 'لطفاً نسخهٔ جدید را دریافت کنید.',
                  'en': 'Please download the new version.'
                }
              }
            }
    });

Widget app(Widget child, {String language = 'fa', bool dark = false}) =>
    MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('fa'), Locale('en')],
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
        home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Vazirmatn', 'NotoSans']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/abrit/$family.ttf')))
          .load();
    }
  });

  test('version comparisons use numbers, including short versions', () {
    expect(
        AbritControlState.parse(snapshot(version: '1.9.9', latest: '1.10'))
            .updateAvailable,
        isTrue);
    expect(
        AbritControlState.parse(snapshot(version: '1.3', latest: '1.3.0'))
            .updateAvailable,
        isFalse);
    expect(
        AbritControlState.parse(snapshot(version: '2.0', latest: '1.9'))
            .updateAvailable,
        isFalse);
  });
  test('rejects unsafe browser and download targets', () {
    for (final url in [
      'file:///x',
      'http://host/x',
      'javascript:alert(1)',
      'https://',
      'https://user@host/a',
      'https://host/a b',
      'https://host\\evil/a'
    ]) {
      expect(safeControlUrl(url), isFalse, reason: url);
    }
    expect(safeControlUrl('https://abritdesk.ir/download?a=1'), isTrue);
  });
  test('malformed state cannot erase an already mandatory update', () {
    var raw = snapshot(blocked: true, error: true);
    final controller = AbritControlController(
        readState: () => raw,
        refresh: () {},
        openUrl: (_) async => true,
        onExit: () {});
    controller.poll();
    raw = '{broken';
    controller.poll();
    expect(controller.state.blocked, isTrue);
    raw = snapshot(blocked: true, error: true, revision: 'offline');
    controller.poll();
    expect(controller.state.blocked, isTrue);
    expect(controller.state.error, isTrue);
    raw = snapshot(latest: '1.5.1', minimum: '1.5.1');
    controller.poll();
    expect(controller.state.blocked, isFalse);
    controller.dispose();
  });
  test('dismissal is per version and can never dismiss mandatory policy', () {
    var raw = snapshot();
    final controller = AbritControlController(
        readState: () => raw,
        refresh: () {},
        openUrl: (_) async => true,
        onExit: () {});
    controller.poll();
    expect(controller.showOptionalUpdate, isTrue);
    controller.dismissOptionalUpdate();
    expect(controller.showOptionalUpdate, isFalse);
    raw = snapshot(latest: '1.5.3');
    controller.poll();
    expect(controller.showOptionalUpdate, isTrue);
    raw = snapshot(blocked: true);
    controller.poll();
    controller.dismissOptionalUpdate();
    expect(controller.state.blocked, isTrue);
    controller.dispose();
  });
  testWidgets('live banner changes text and visibility without restarting',
      (tester) async {
    var raw = snapshot();
    final opened = <String>[];
    final controller = AbritControlController(
        readState: () => raw,
        refresh: () {},
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
        onExit: () {});
    controller.poll();
    await tester.pumpWidget(app(AbritControlScope(
        controller: controller,
        child: const Align(
            alignment: Alignment.topCenter,
            child: AbritLiveBanner(short: false, compact: false)))));
    await tester.pumpAndSettle();
    expect(find.text('بنر a'), findsOneWidget);
    await tester.tap(find.text('بنر a'));
    await tester.pump();
    expect(opened, ['https://abritdesk.ir/offers']);
    raw = snapshot(revision: 'b');
    controller.poll();
    await tester.pumpAndSettle();
    expect(find.text('بنر b'), findsOneWidget);
    expect(find.text('بنر a'), findsNothing);
    raw = snapshot(bannerEnabled: false);
    controller.poll();
    await tester.pumpAndSettle();
    expect(find.text('بنر b'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
      'optional update leaves the application usable and can be deferred',
      (tester) async {
    final controller = AbritControlController(
        readState: () => snapshot(),
        refresh: () {},
        openUrl: (_) async => true,
        onExit: () {});
    await tester.pumpWidget(app(AbritControlHost(
        controller: controller,
        child: Column(children: [
          TextButton(onPressed: () {}, child: const Text('Connect now')),
          const AbritUpdateNotice()
        ]))));
    await tester.pumpAndSettle();
    expect(find.text('Connect now').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('abrit-required-update')), findsNothing);
    await tester.tap(find.text('بعداً'));
    await tester.pumpAndSettle();
    expect(find.text('دانلود بروزرسانی'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
      'mandatory gate preserves input but prevents use, even after opening download',
      (tester) async {
    var raw = snapshot(blocked: true, minimum: '1.5.2');
    var downloads = 0, connects = 0, retries = 0;
    final input = TextEditingController(text: '123456789');
    final controller = AbritControlController(
        readState: () => raw,
        refresh: () => retries++,
        openUrl: (_) async {
          downloads++;
          return true;
        },
        onExit: () {});
    await tester.pumpWidget(app(AbritControlHost(
        controller: controller,
        child: Column(children: [
          TextField(controller: input),
          TextButton(
              onPressed: () => connects++, child: const Text('Connect now')),
        ]))));
    await tester.pumpAndSettle();
    expect(find.text('Connect now').hitTestable(), findsNothing);
    await tester.tap(find.byKey(const ValueKey('abrit-required-download')));
    await tester.pump();
    expect(downloads, 1);
    expect(controller.state.blocked, isTrue);
    expect(connects, 0);
    await tester.tap(find.text('بررسی دوباره'));
    await tester.pump();
    expect(retries, 1);
    raw = snapshot(version: '1.5.2', latest: '1.5.2', minimum: '1.5.2');
    controller.poll();
    await tester.pumpAndSettle();
    expect(find.text('Connect now').hitTestable(), findsOneWidget);
    expect(input.text, '123456789');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    input.dispose();
  });
  testWidgets('initial outage permits use when no minimum policy was received',
      (tester) async {
    final controller = AbritControlController(
        readState: () => snapshot(error: true, includeDocument: false),
        refresh: () {},
        openUrl: (_) async => true,
        onExit: () {});
    await tester.pumpWidget(app(
        AbritControlHost(controller: controller, child: const Text('Usable'))));
    await tester.pumpAndSettle();
    expect(find.text('Usable'), findsOneWidget);
    expect(find.byKey(const ValueKey('abrit-required-update')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('required update fits short windows in both languages and themes',
      (tester) async {
    final boundary = GlobalKey();
    for (final language in ['fa', 'en']) {
      for (final dark in [false, true]) {
        for (final size in [const Size(360, 420), const Size(800, 600)]) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          final controller = AbritControlController(
              readState: () => snapshot(blocked: true, error: true),
              refresh: () {},
              openUrl: (_) async => true,
              onExit: () {});
          controller.poll();
          await tester.pumpWidget(app(
              RepaintBoundary(
                  key: boundary,
                  child: AbritRequiredUpdate(controller: controller)),
              language: language,
              dark: dark));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final output = Platform.environment['ABRIT_TEST_SHOTS'];
          if (output != null && size.width == 800) {
            await tester.runAsync(() async {
              final image = await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              Directory(output).createSync(recursive: true);
              File('$output/update-required-$language-${dark ? "dark" : "light"}.png')
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
