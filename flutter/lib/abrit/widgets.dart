import 'package:flutter/material.dart';
import 'brand.dart';

class AbritLogo extends StatelessWidget {
  final double size;
  const AbritLogo({super.key, this.size = 46});
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/abrit/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .17),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4B95E8), Color(0xFF005ACB)]),
          ),
          child: CustomPaint(painter: _AbritMark()),
        ),
      );
}

class _AbritMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, size.height * .2)
      ..lineTo(size.width * .8, size.height * .77)
      ..lineTo(size.width * .2, size.height * .77)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_AbritMark oldDelegate) => false;
}

class AbritCard extends StatelessWidget {
  final Widget child;
  const AbritCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
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
  const AbritCardHeading(
      {super.key,
      required this.icon,
      required this.title,
      required this.description});
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AbritColors.blue.withOpacity(.07)),
              child: Icon(icon, color: AbritColors.blue, size: 30)),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: AbritColors.foreground(context))),
                const SizedBox(height: 6),
                Text(description,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AbritColors.muted(context))),
              ])),
        ],
      );
}

class AbritConnectButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const AbritConnectButton(
      {super.key, required this.onPressed, required this.label});
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
              colors: [Color(0xFF0065DF), Color(0xFF3495FF)])),
      child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              elevation: 0,
              minimumSize: const Size(0, 64),
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
  const AbritHero({super.key, required this.short});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: short ? 140 : 210),
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
                                  fontSize: short ? 26 : 34,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: AbritColors.foreground(context))),
                          Text(
                              abritText(context, 'to your devices',
                                  'به دستگاه‌های شما'),
                              style: TextStyle(
                                  fontSize: short ? 26 : 34,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                  color: AbritColors.blue)),
                          if (!short) ...[
                            const SizedBox(height: 10),
                            Text(
                                abritText(
                                    context,
                                    'Connect to your devices from anywhere with Abrit Desk.',
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
  const AbritBanner({super.key, required this.short});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
            constraints: BoxConstraints(minHeight: short ? 96 : 154),
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
                  constraints: BoxConstraints(minHeight: short ? 96 : 154),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
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
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: short ? 18 : 24,
                                              fontWeight: FontWeight.w700)),
                                      if (!short) ...[
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
                                  const AbritLogo(size: 42),
                                  const SizedBox(width: 12),
                                  const Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('ABRIT',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 2)),
                                            Text('ABRITDESK.IR',
                                                style: TextStyle(
                                                    color: Color(0xFF45C4FA),
                                                    fontSize: 12,
                                                    letterSpacing: 1.2)),
                                          ])),
                                ],
                              ])))),
            ])),
      );
}
