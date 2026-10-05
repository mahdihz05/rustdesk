import 'package:flutter/material.dart';
import 'brand.dart';
import 'widgets.dart';
import 'live_banner.dart';

class AbritHomeLayout extends StatelessWidget {
  final Widget? deviceCard;
  final Widget connectionCard;
  final Widget peers;
  final Widget help;
  final Widget status;
  const AbritHomeLayout(
      {super.key,
      this.deviceCard,
      required this.connectionCard,
      required this.peers,
      required this.help,
      required this.status});

  @override
  Widget build(BuildContext context) {
    final scope = AbritScope.of(context);
    return ValueListenableBuilder<AbritDestination>(
        valueListenable: scope.destination,
        builder: (context, destination, _) {
          final showingPeers = destination == AbritDestination.devices ||
              destination == AbritDestination.addressBook;
          final compact = scope.metrics.compactHome;
          final gap = compact ? 12.0 : 20.0;
          return Column(children: [
            Expanded(
                child: Stack(children: [
              Offstage(
                  offstage: showingPeers,
                  child: SingleChildScrollView(
                      padding: EdgeInsets.all(scope.metrics.padding),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Offstage(
                                offstage:
                                    destination == AbritDestination.connection,
                                child: AbritHero(short: scope.metrics.short, compact: compact)),
                            SizedBox(height: gap),
                            LayoutBuilder(builder: (context, constraints) {
                              final cardWidth = scope.metrics.homeSideBySide &&
                                      deviceCard != null &&
                                      destination == AbritDestination.home
                                  ? (constraints.maxWidth - (compact ? 16 : 22)) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                  spacing:
                                      destination == AbritDestination.connection
                                          ? 0
                                          : compact ? 16 : 22,
                                  runSpacing:
                                      destination == AbritDestination.connection
                                          ? 0
                                          : compact ? 12 : 22,
                                  children: [
                                    if (deviceCard != null)
                                      Offstage(
                                          offstage: destination ==
                                              AbritDestination.connection,
                                          child: SizedBox(
                                              key: const ValueKey(
                                                  'abrit-device'),
                                              width: cardWidth,
                                              child: deviceCard)),
                                    SizedBox(
                                        key: const ValueKey('abrit-form'),
                                        width: cardWidth,
                                        child: ConstrainedBox(
                                            constraints: BoxConstraints(minHeight:
                                                compact && scope.metrics.homeSideBySide &&
                                                    destination == AbritDestination.home
                                                    ? 236 : scope.metrics.sideBySide && !compact ? 309 : 0),
                                            child: AbritCard(compact: compact, child: connectionCard))),
                                  ]);
                            }),
                            SizedBox(height: gap),
                            Offstage(
                                offstage:
                                    destination == AbritDestination.connection,
                                child: AbritLiveBanner(key: const ValueKey('abrit-home-banner'),
                                    short: scope.metrics.short, compact: compact)),
                            const SizedBox(height: 8),
                            help,
                          ]))),
              Offstage(
                  offstage: !showingPeers,
                  child: Padding(
                      padding: EdgeInsets.all(scope.metrics.padding),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                destination == AbritDestination.addressBook
                                    ? abritText(
                                        context, 'Address book', 'دفترچهٔ آدرس')
                                    : abritText(
                                        context, 'Devices', 'دستگاه‌ها'),
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 20),
                            Expanded(child: peers),
                          ]))),
            ])),
            LayoutBuilder(builder: (context, constraints) =>
                SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: SizedBox(width: constraints.maxWidth < 680
                      ? 680 : constraints.maxWidth, child: status))),
          ]);
        });
  }
}
