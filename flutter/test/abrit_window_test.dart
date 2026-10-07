import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/abrit/window.dart';

void main() {
  test('initial size matches the reference without maximizing a large screen', () {
    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      expect(abritWindowSizeForWorkArea(Size(1920 * scale, 1040 * scale), scale),
          const Size(1160, 920));
    }
  });
  test('small work areas leave room around the normal window at each DPI', () {
    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      expect(abritWindowSizeForWorkArea(Size(1024 * scale, 728 * scale), scale),
          const Size(992, 696));
    }
    expect(abritWindowSizeForWorkArea(const Size(1920, 1040), 1.5),
        const Size(1160, 1040 / 1.5 - 32));
  });
}
