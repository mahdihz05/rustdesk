import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';

class AbritStyle {
  static const blue = Color(0xFF0088FF);
  static const navy = Color(0xFF14233D);
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFF0F6FF)
          : const Color(0xFF101A2B);
  static BoxDecoration panel(BuildContext context, {bool remote = false}) =>
      BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: remote
                ? [const Color(0xFF314E79), navy]
                : Theme.of(context).brightness == Brightness.light
                    ? [Colors.white, const Color(0xFFE3F1FF)]
                    : [const Color(0xFF223249), const Color(0xFF18253A)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: remote
                ? const Color(0xFF40618E)
                : Theme.of(context).dividerColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
              color: navy.withOpacity(0.09),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      );
}

// Render only approved artwork from the reference; the source stays unmodified.
// No reference IDs/passwords/peers are included in these source rectangles.
class AbritReferenceArtwork extends StatelessWidget {
  final Rect source;
  const AbritReferenceArtwork({super.key, required this.source});
  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: source.width,
          height: source.height,
          child: ClipRect(
              child: Stack(children: [
            Positioned(
              left: -source.left,
              top: -source.top,
              width: 1448,
              height: 1086,
              child: Image.asset('assets/abrit_reference.png',
                  width: 1448,
                  height: 1086,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high),
            )
          ])),
        ),
      );
}

class AbritBrand extends StatelessWidget {
  const AbritBrand({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 112,
        height: 36,
        child: Stack(fit: StackFit.expand, children: [
          AbritReferenceArtwork(
              source: Theme.of(context).brightness == Brightness.light
                  ? const Rect.fromLTWH(1056, 19, 133, 41)
                  : const Rect.fromLTWH(62, 856, 194, 62)),
          Center(child: FittedBox(fit: BoxFit.contain, child: loadLogo())),
        ]),
      );
}

class AbritPanelContent extends StatelessWidget {
  final Widget child;
  final bool remote;
  final bool enabled;
  const AbritPanelContent(
      {super.key, required this.child, this.remote = false, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return Ink(child: child);
    final light = Theme.of(context).brightness == Brightness.light;
    return Stack(children: [
      Positioned.fill(
          child: IgnorePointer(
              child: ExcludeSemantics(
                  child: ClipRect(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Opacity(
                              opacity: remote ? 0.85 : (light ? 0.8 : 0.18),
                              child: SizedBox(
                                  width: remote ? 126 : 112,
                                  height: remote ? 172 : 220,
                                  child: ShaderMask(
                                      blendMode: BlendMode.dstIn,
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                              colors: [
                                            Colors.transparent,
                                            Colors.white,
                                            Colors.white,
                                            Colors.transparent
                                          ],
                                              stops: [0, 0.18, 0.86, 1])
                                              .createShader(bounds),
                                      child: AbritReferenceArtwork(
                                          source: remote
                                              ? const Rect.fromLTWH(
                                                  635, 125, 125, 170)
                                              : const Rect.fromLTWH(
                                                  1281, 119, 135, 263)))))))))),
      child,
    ]);
  }
}
