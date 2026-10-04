import 'package:flutter/material.dart';
import 'brand.dart';

bool abritEnabled(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<AbritScope>() != null;

AlignmentGeometry abritStartAlignment(BuildContext context, Alignment fallback,
        AlignmentDirectional directional) =>
    abritEnabled(context) ? directional : fallback;

extension AbritSpacing on Widget {
  Widget abritMarginOnly(
          {double start = 0,
          double end = 0,
          double top = 0,
          double bottom = 0}) =>
      Builder(
          builder: (context) => Container(
              margin: abritEnabled(context)
                  ? EdgeInsetsDirectional.fromSTEB(start, top, end, bottom)
                  : EdgeInsets.fromLTRB(start, top, end, bottom),
              child: this));

  Widget abritPaddingOnly(
          {double start = 0,
          double end = 0,
          double top = 0,
          double bottom = 0}) =>
      Builder(
          builder: (context) => Padding(
              padding: abritEnabled(context)
                  ? EdgeInsetsDirectional.fromSTEB(start, top, end, bottom)
                  : EdgeInsets.fromLTRB(start, top, end, bottom),
              child: this));
}
