import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:window_manager/window_manager.dart';
import 'brand.dart';

String? get abritSmokeDirectory =>
    !kIsWeb && Platform.isWindows ? Platform.environment['ABRIT_UI_SMOKE_DIR'] : null;

Future<void> Function()? abritSmokeRestoreLanguage;

void installAbritSmokeErrorReporting() {
  final directory = abritSmokeDirectory;
  if (directory == null) return;
  Directory(directory).createSync(recursive: true);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    File('$directory/errors.txt').writeAsStringSync(
        '${details.exceptionAsString()}\n${details.stack}\n',
        mode: FileMode.append);
    previous?.call(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    File('$directory/errors.txt')
        .writeAsStringSync('$error\n$stack\n', mode: FileMode.append);
    return false;
  };
}

// Opt-in CI probe of the actual release application and its native models.
class AbritSmokeCapture extends StatefulWidget {
  final Widget child;
  final ValueChanged<AbritDestination> onSelected;
  const AbritSmokeCapture(
      {super.key, required this.child, required this.onSelected});
  @override
  State<AbritSmokeCapture> createState() => _AbritSmokeCaptureState();
}

class _AbritSmokeCaptureState extends State<AbritSmokeCapture> {
  final _boundary = GlobalKey();
  @override
  void initState() {
    super.initState();
    if (abritSmokeDirectory != null) _capture();
  }

  Future<void> _save(String name) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$abritSmokeDirectory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  }

  Future<void> _capture() async {
    try {
      await Future<void>.delayed(const Duration(seconds: 4));
      await windowManager.unmaximize();
      for (final size in [
        const Size(800, 600),
        const Size(1280, 850),
        const Size(1024, 768),
        const Size(600, 600),
        const Size(480, 600)
      ]) {
        await windowManager.setSize(size);
        await _save('home-${size.width.toInt()}x${size.height.toInt()}');
      }
      await windowManager.setSize(const Size(1280, 850));
      for (final page in [
        AbritDestination.connection,
        AbritDestination.devices,
        AbritDestination.addressBook,
        AbritDestination.settings,
        AbritDestination.home
      ]) {
        widget.onSelected(page);
        await _save(page.name);
      }
      await abritSmokeRestoreLanguage?.call();
      await File('$abritSmokeDirectory/complete.json')
          .writeAsString(jsonEncode({'complete': true}));
    } catch (error, stack) {
      File('$abritSmokeDirectory/errors.txt')
          .writeAsStringSync('$error\n$stack\n', mode: FileMode.append);
    } finally {
      await abritSmokeRestoreLanguage?.call();
    }
  }

  @override
  Widget build(BuildContext context) => abritSmokeDirectory == null
      ? widget.child
      : RepaintBoundary(key: _boundary, child: widget.child);
}
