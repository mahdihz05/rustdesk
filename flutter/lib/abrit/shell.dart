import 'package:flutter/material.dart';
import 'brand.dart';
import 'widgets.dart';
import 'smoke.dart';

class AbritDesktopShell extends StatefulWidget {
  final Widget child;
  final Widget windowControls;
  final ValueNotifier<AbritDestination> destination;
  final ValueChanged<AbritDestination> onSelected;
  final VoidCallback onDrag;
  final VoidCallback onMaximize;
  final List<AbritDestination> destinations;
  final String version;
  final ValueChanged<AbritLayoutMetrics>? onLayout;
  const AbritDesktopShell(
      {super.key,
      required this.child,
      required this.windowControls,
      required this.destination,
      required this.onSelected,
      required this.onDrag,
      required this.onMaximize,
      required this.destinations,
      required this.version,
      this.onLayout});
  @override
  State<AbritDesktopShell> createState() => _AbritDesktopShellState();
}

class _AbritDesktopShellState extends State<AbritDesktopShell> {
  bool _drawerOpen = false;
  Size? _lastSize;

  String _label(BuildContext context, AbritDestination destination) {
    switch (destination) {
      case AbritDestination.home:
        return abritText(context, 'Home', 'صفحهٔ اصلی');
      case AbritDestination.connection:
        return abritText(context, 'Connect', 'اتصال');
      case AbritDestination.devices:
        return abritText(context, 'Devices', 'دستگاه‌ها');
      case AbritDestination.addressBook:
        return abritText(context, 'Address book', 'دفترچهٔ آدرس');
      case AbritDestination.settings:
        return abritText(context, 'Settings', 'تنظیمات');
    }
  }

  IconData _icon(AbritDestination destination) {
    switch (destination) {
      case AbritDestination.home:
        return Icons.desktop_windows_outlined;
      case AbritDestination.connection:
        return Icons.swap_horiz_rounded;
      case AbritDestination.devices:
        return Icons.devices_outlined;
      case AbritDestination.addressBook:
        return Icons.contact_page_outlined;
      case AbritDestination.settings:
        return Icons.settings_outlined;
    }
  }

  Widget _navigation(bool compact) => ColoredBox(
        color: AbritColors.background(context),
        child: ValueListenableBuilder<AbritDestination>(
            valueListenable: widget.destination,
            builder: (context, selected, _) => Column(children: [
                  Expanded(
                      child: ListView(
                          padding: EdgeInsets.all(compact ? 10 : 20),
                          children: widget.destinations.map((destination) {
                            final active = selected == destination;
                            final label = _label(context, destination);
                            final color = active
                                ? AbritColors.blue
                                : AbritColors.muted(context);
                            return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Tooltip(
                                    message: label,
                                    child: Material(
                                        color: active
                                            ? AbritColors.blue.withOpacity(.09)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            onTap: () {
                                              setState(
                                                  () => _drawerOpen = false);
                                              widget.onSelected(destination);
                                            },
                                            child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 14,
                                                    horizontal:
                                                        compact ? 0 : 16),
                                                child: Row(
                                                    mainAxisAlignment: compact
                                                        ? MainAxisAlignment
                                                            .center
                                                        : MainAxisAlignment
                                                            .start,
                                                    children: [
                                                      Icon(_icon(destination),
                                                          size: 24,
                                                          color: color),
                                                      if (!compact) ...[
                                                        const SizedBox(
                                                            width: 18),
                                                        Expanded(
                                                            child: Text(label,
                                                                style: TextStyle(
                                                                    color:
                                                                        color,
                                                                    fontWeight: active
                                                                        ? FontWeight
                                                                            .w700
                                                                        : FontWeight
                                                                            .w500))),
                                                      ],
                                                    ]))))));
                          }).toList())),
                  if (MediaQuery.sizeOf(context).height >= 350)
                    Padding(
                        padding: EdgeInsets.all(compact ? 10 : 24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!compact)
                                const Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Row(children: [
                                      AbritLogo(size: 32),
                                      SizedBox(width: 10),
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('abritdesk',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            Text('abritdesk.ir',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: Color(0xFF717B8B),
                                                    letterSpacing: 1)),
                                          ])
                                    ])),
                              const SizedBox(height: 16),
                              if (widget.version.isNotEmpty)
                                Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text('v${widget.version}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                AbritColors.muted(context)))),
                            ])),
                ])),
      );

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final metrics =
            AbritLayoutMetrics(constraints.maxWidth, constraints.maxHeight);
        final size = Size(metrics.width, metrics.height);
        if (_lastSize != size) {
          _lastSize = size;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onLayout?.call(metrics);
          });
        }
        return AbritSmokeCapture(onSelected: widget.onSelected, child: AbritScope(
          metrics: metrics,
          destination: widget.destination,
          child: ColoredBox(
              color: AbritColors.background(context),
              child: Column(children: [
                SizedBox(
                    height: 72,
                    child: Row(textDirection: TextDirection.ltr, children: [
                      Expanded(
                          child: Row(children: [
                        if (metrics.drawer)
                          IconButton(
                              tooltip: abritText(context, 'Menu', 'منو'),
                              onPressed: () =>
                                  setState(() => _drawerOpen = !_drawerOpen),
                              icon: const Icon(Icons.menu)),
                        Expanded(
                            child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (_) => widget.onDrag(),
                                onDoubleTap: widget.onMaximize,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Row(children: [
                                      const AbritLogo(size: 40),
                                      const SizedBox(width: 12),
                                      if (constraints.maxWidth >= 420)
                                        Flexible(
                                            child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              const Text('abritdesk',
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: .8)),
                                              Text(
                                                  abritText(
                                                      context,
                                                      'Secure access, always with you',
                                                      'دسترسی امن، همیشه در کنار شما'),
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: AbritColors.muted(
                                                          context))),
                                            ])),
                                    ])))),
                      ])),
                      Directionality(
                          textDirection: TextDirection.ltr,
                          child: widget.windowControls),
                      const SizedBox(width: 8),
                    ])),
                Expanded(
                    child: Stack(children: [
                  Row(children: [
                    if (!metrics.drawer)
                      SizedBox(
                          width: metrics.navigationWidth,
                          child: _navigation(metrics.compactNavigation)),
                    Expanded(
                        key: const ValueKey('abrit-main-content'),
                        child: widget.child),
                  ]),
                  if (metrics.drawer && _drawerOpen) ...[
                    Positioned.fill(
                        child: GestureDetector(
                            onTap: () => setState(() => _drawerOpen = false),
                            child: ColoredBox(
                                color: Colors.black.withOpacity(.35)))),
                    PositionedDirectional(
                        start: 0,
                        top: 0,
                        bottom: 0,
                        width: 230,
                        child:
                            Material(elevation: 12, child: _navigation(false))),
                  ],
                ])),
              ])),
        ));
      });
}
