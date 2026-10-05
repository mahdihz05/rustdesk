import 'package:flutter/material.dart';
import 'brand.dart';
import 'widgets.dart';

class AbritAbout extends StatelessWidget {
  final String version;
  final String buildDate;
  final String fingerprint;
  final String deviceId;
  final VoidCallback onWebsiteOpen;
  final Widget? updates;
  const AbritAbout(
      {super.key,
      required this.version,
      required this.buildDate,
      required this.fingerprint,
      required this.deviceId,
      this.updates,
      required this.onWebsiteOpen});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AbritCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(abritText(context, 'About abritdesk', 'دربارهٔ abritdesk'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        const Align(
            alignment: AlignmentDirectional.centerStart,
            child: AbritLogo(size: 64)),
        const SizedBox(height: 16),
        Text('abritdesk',
            textDirection: TextDirection.ltr,
            textAlign: Directionality.of(context) == TextDirection.rtl
                ? TextAlign.right
                : TextAlign.left,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
            abritText(context, 'Secure remote access to your devices.',
                'دسترسی امن از راه دور به دستگاه‌های شما.'),
            style: TextStyle(color: AbritColors.muted(context), height: 1.7)),
        const SizedBox(height: 24),
        _detail(abritText(context, 'Version', 'نسخه'), version),
        _detail(abritText(context, 'Build date', 'تاریخ ساخت'), buildDate),
        if (fingerprint.isNotEmpty)
          _detail(abritText(context, 'Fingerprint', 'اثر انگشت'), fingerprint),
        _detail(abritText(context, 'Device ID', 'شناسهٔ دستگاه'), deviceId),
        const SizedBox(height: 16),
        Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
                onPressed: onWebsiteOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('abritdesk.ir',
                    textDirection: TextDirection.ltr))),
        if (updates != null) ...[const SizedBox(height: 16), updates!],
      ])));

  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SelectableText(value, textDirection: TextDirection.ltr),
      ]));
}
