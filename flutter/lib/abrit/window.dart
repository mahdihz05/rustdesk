import 'dart:math' as math;
import 'dart:ui';

const abritInitialWindowSize = Size(1160, 920);
const abritWindowLayoutKey = 'abrit-main-window-layout-v2';

Size abritWindowSizeForWorkArea(Size physicalWorkArea, double scale) {
  final dpi = scale.isFinite && scale > 0 ? scale : 1.0;
  return Size(
    math.min(abritInitialWindowSize.width,
        math.max(1.0, physicalWorkArea.width / dpi - 32)),
    math.min(abritInitialWindowSize.height,
        math.max(1.0, physicalWorkArea.height / dpi - 32)),
  );
}
