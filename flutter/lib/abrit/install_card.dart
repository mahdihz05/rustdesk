import 'package:flutter/material.dart';
import 'brand.dart';

class AbritInstallCard extends StatelessWidget {
  final bool compact;
  final bool upgrade;
  final VoidCallback onPressed;
  const AbritInstallCard(
      {super.key,
      required this.compact,
      this.upgrade = false,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final dark = AbritColors.isDark(context);
    final foreground = dark ? const Color(0xFF132841) : Colors.white;
    final label = upgrade
        ? abritText(context, 'Upgrade', 'ارتقا')
        : abritText(context, 'Install', 'نصب');
    final description = abritText(
        context,
        'Install abritdesk for easy access and to handle Windows permission prompts.',
        'برای دسترسی راحت‌تر و مدیریت پیام‌های مجوز ویندوز، abritdesk را نصب کنید.');
    return Tooltip(
        message: compact ? description : '',
        child: Material(
            key: const ValueKey('abrit-install-card'),
            color: dark ? const Color(0xFFDCEAFF) : const Color(0xFF132841),
            borderRadius: BorderRadius.circular(12),
            child: compact
                ? InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(children: [
                          Icon(Icons.download_rounded,
                              color: foreground, size: 24),
                          const SizedBox(height: 6),
                          Text(label,
                              style:
                                  TextStyle(color: foreground, fontSize: 11)),
                        ])))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Icon(Icons.download_rounded,
                                color: foreground, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text('$label abritdesk',
                                    style: TextStyle(
                                        color: foreground,
                                        fontWeight: FontWeight.w700))),
                          ]),
                          const SizedBox(height: 10),
                          Text(
                              upgrade
                                  ? abritText(
                                      context,
                                      'Upgrade your installed version of abritdesk.',
                                      'نسخهٔ نصب‌شدهٔ abritdesk را به‌روز کنید.')
                                  : description,
                              style: TextStyle(
                                  color: foreground.withOpacity(.8),
                                  fontSize: 12,
                                  height: 1.7)),
                          const SizedBox(height: 14),
                          OutlinedButton(
                              onPressed: onPressed,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: dark
                                      ? const Color(0xFF132841)
                                      : AbritColors.blue,
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              child: Text(label)),
                        ]))));
  }
}
