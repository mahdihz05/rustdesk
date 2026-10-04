import 'package:flutter/material.dart';
import 'brand.dart';

class AbritLogo extends StatelessWidget {
  final double size;
  const AbritLogo({super.key, this.size = 46});
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/abrit/wordmark.png',
        width: size * 2.15,
        height: size,
        fit: BoxFit.contain,
      );
}

class AbritCard extends StatelessWidget {
  final Widget child;
  final bool compact;
  const AbritCard({super.key, required this.child, this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 16 : 24),
        decoration: BoxDecoration(
            color: AbritColors.surface(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.blue.withOpacity(.035),
                  blurRadius: 28,
                  offset: const Offset(0, 8))
            ]),
        child: child,
      );
}

class AbritCardHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool compact;
  const AbritCardHeading(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.compact = false});
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: compact ? 36 : 58,
              height: compact ? 36 : 58,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AbritColors.blue.withOpacity(.07)),
              child: Icon(icon, color: AbritColors.blue, size: compact ? 22 : 30)),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: compact ? 2 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                        fontSize: compact ? 18 : 23,
                        fontWeight: FontWeight.w700,
                        color: AbritColors.foreground(context))),
                SizedBox(height: compact ? 4 : 6),
                Tooltip(message: compact ? description : '', child: Text(description,
                    maxLines: compact ? 1 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                        fontSize: compact ? 12 : 14,
                        height: 1.6,
                        color: AbritColors.muted(context)))),
              ])),
        ],
      );
}

class AbritConnectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final bool compact;
  const AbritConnectButton(
      {super.key, required this.onPressed, required this.label, this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
              colors: [Color(0xFF0065DF), Color(0xFF3495FF)])),
      child: ElevatedButton(
          key: const ValueKey('abrit-connect-button'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
              minimumSize: Size(0, compact ? 48 : 64),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.arrow_forward),
            const SizedBox(width: 12),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 18))),
          ])));
}

class AbritHero extends StatelessWidget {
  final bool short;
  final bool compact;
  const AbritHero({super.key, required this.short, this.compact = false});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 64 : short ? 140 : 180),
        child: LayoutBuilder(builder: (context, constraints) {
          final showImage = constraints.maxWidth >= 550;
          return Stack(children: [
            if (showImage)
              PositionedDirectional(
                  top: 0,
                  bottom: 0,
                  end: 0,
                  width: constraints.maxWidth * .61,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => LinearGradient(
                              begin: Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              end: Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              colors: const [Colors.transparent, Colors.white],
                              stops: const [0, .4]).createShader(rect),
                          child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                  Directionality.of(context) == TextDirection.rtl ? -1 : 1,
                                  1,
                                  1),
                              child: Image.asset(AbritColors.isDark(context) ? 'assets/abrit/servers.png' : 'assets/abrit/hero-light.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()))))),
            Align(
                heightFactor: 1,
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                    width: showImage
                        ? constraints.maxWidth * .46
                        : double.infinity,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              abritText(context, 'Fast, secure access',
                                  'دسترسی سریع و امن'),
                              style: TextStyle(
                                  fontSize: compact ? 20 : short ? 26 : 34,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: AbritColors.foreground(context))),
                          Text(
                              abritText(context, 'to your devices',
                                  'به دستگاه‌های شما'),
                              style: TextStyle(
                                  fontSize: compact ? 20 : short ? 26 : 34,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: AbritColors.blue)),
                          if (!short && !compact) ...[
                            const SizedBox(height: 10),
                            Text(
                                abritText(
                                    context,
                                    'Connect to your devices from anywhere with abritdesk.',
                                    'با ابریت دسک از هر کجا، به سادگی و با امنیت بالا به دستگاه‌های خود متصل شوید.'),
                                style: TextStyle(
                                    color: AbritColors.muted(context),
                                    height: 1.7)),
                          ],
                        ]))),
          ]);
        }),
      );
}

class AbritBanner extends StatelessWidget {
  final bool short;
  final bool compact;
  const AbritBanner({super.key, required this.short, this.compact = false});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
            constraints: BoxConstraints(minHeight: compact ? 56 : short ? 96 : 140),
            color: const Color(0xFF06162E),
            child: Stack(children: [
              Positioned.fill(
                  child: Image.asset('assets/abrit/servers.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox())),
              Positioned.fill(
                  child: Container(
                      color: const Color(0xFF06162E).withOpacity(.6))),
              ConstrainedBox(
                  constraints: BoxConstraints(minHeight: compact ? 56 : short ? 96 : 140),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 16 : 24, vertical: compact ? 10 : 12),
                      child: LayoutBuilder(
                          builder: (context, constraints) => Row(children: [
                                Expanded(
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          abritText(
                                              context,
                                              'Secure remote access',
                                              'راهکاری امن برای دسترسی از راه دور'),
                                          maxLines: compact ? 1 : null,
                                          overflow: compact ? TextOverflow.ellipsis : null,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: compact ? 16 : short ? 18 : 24,
                                              fontWeight: FontWeight.w700)),
                                      if (!short && !compact) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                            abritText(
                                                context,
                                                'Built for businesses and professional teams',
                                                'مناسب کسب‌وکارها و تیم‌های حرفه‌ای'),
                                            style: const TextStyle(
                                                color: Colors.white70)),
                                      ],
                                    ])),
                                if (constraints.maxWidth >= 550) ...[
                                  const SizedBox(width: 24),
                                  AbritLogo(size: compact ? 28 : 42),
                                  const SizedBox(width: 12),
                                  Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('abritdesk',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: compact ? 16 : 22,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 2)),
                                            Text('abritdesk.ir',
                                                style: TextStyle(
                                                    color: Color(0xFF45C4FA),
                                                    fontSize: compact ? 10 : 12,
                                                    letterSpacing: 1.2)),
                                          ])),
                                ],
                              ])))),
            ])),
      );
}
