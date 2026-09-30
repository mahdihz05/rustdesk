import 'package:flutter/material.dart';

class AbritPeerStyle extends InheritedWidget {
  final double cardWidth;
  const AbritPeerStyle(
      {super.key, required this.cardWidth, required super.child});
  static AbritPeerStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AbritPeerStyle>();
  @override
  bool updateShouldNotify(AbritPeerStyle oldWidget) =>
      cardWidth != oldWidget.cardWidth;
}
