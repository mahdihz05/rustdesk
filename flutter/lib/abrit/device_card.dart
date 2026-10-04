import 'package:flutter/material.dart';
import 'brand.dart';
import 'widgets.dart';

class AbritDeviceCard extends StatefulWidget {
  final String id;
  final String password;
  final bool unattended;
  final ValueChanged<String> onCopy;
  final VoidCallback? onRefreshPassword;
  final VoidCallback? onSecuritySettings;
  final Widget warning;
  const AbritDeviceCard(
      {super.key,
      required this.id,
      required this.password,
      required this.unattended,
      required this.onCopy,
      this.onRefreshPassword,
      this.onSecuritySettings,
      this.warning = const SizedBox.shrink()});
  @override
  State<AbritDeviceCard> createState() => _AbritDeviceCardState();
}

class _AbritDeviceCardState extends State<AbritDeviceCard> {
  bool _visible = false;
  bool get passwordAvailable =>
      widget.password.isNotEmpty && widget.password != '-';

  Widget _valueRow(String value, {bool password = false}) => Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.only(start: 18, end: 6),
      decoration: BoxDecoration(
          color: password
              ? AbritColors.blue.withOpacity(.08)
              : AbritColors.field(context),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SelectableText(
                                password && passwordAvailable && !_visible
                                    ? '••••••••'
                                    : value,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                    fontFamily: 'NotoSans',
                                    fontSize: password ? 24 : 30,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        AbritColors.foreground(context)))))))),
        if (password)
          IconButton(
              key: const ValueKey('abrit-password-visibility'),
              tooltip: _visible
                  ? abritText(context, 'Hide password', 'پنهان‌کردن رمز')
                  : abritText(context, 'Show password', 'نمایش رمز'),
              onPressed: passwordAvailable
                  ? () => setState(() => _visible = !_visible)
                  : null,
              icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AbritColors.blue,
                  size: 22)),
        IconButton(
            key: ValueKey(password ? 'abrit-copy-password' : 'abrit-copy-id'),
            tooltip: abritText(context, 'Copy', 'کپی'),
            onPressed: value.isNotEmpty && value != '-'
                ? () => widget.onCopy(value)
                : null,
            icon: const Icon(Icons.copy_outlined,
                color: AbritColors.blue, size: 22)),
      ]));

  @override
  Widget build(BuildContext context) => AbritCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: AbritCardHeading(
                  icon: Icons.desktop_windows_outlined,
                  title: abritText(context, 'Your device', 'دستگاه شما'),
                  description: abritText(
                      context,
                      'Share this ID to connect to your device.',
                      'این شناسه را در اختیار طرف مقابل قرار دهید تا به دستگاه شما متصل شود.'))),
          if (widget.onRefreshPassword != null ||
              widget.onSecuritySettings != null)
            PopupMenuButton<String>(
                tooltip: abritText(context, 'More', 'بیشتر'),
                onSelected: (value) {
                  if (value == 'refresh') widget.onRefreshPassword?.call();
                  if (value == 'settings') widget.onSecuritySettings?.call();
                },
                itemBuilder: (_) => [
                      if (widget.onRefreshPassword != null)
                        PopupMenuItem(
                            value: 'refresh',
                            child: Text(abritText(
                                context, 'Refresh password', 'تازه‌سازی رمز'))),
                      if (widget.onSecuritySettings != null)
                        PopupMenuItem(
                            value: 'settings',
                            child: Text(abritText(
                                context, 'Password settings', 'تنظیمات رمز'))),
                    ]),
        ]),
        const SizedBox(height: 20),
        _valueRow(widget.id),
        const SizedBox(height: 8),
        _valueRow(widget.password, password: true),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: Text(
                  abritText(context, 'Access without confirmation',
                      'دسترسی بدون تأیید'),
                  style: TextStyle(
                      fontSize: 13, color: AbritColors.muted(context)))),
          Tooltip(
              message: abritText(
                  context, 'Open security settings', 'بازکردن تنظیمات امنیتی'),
              child: Switch(
                  value: widget.unattended,
                  onChanged: widget.onSecuritySettings == null
                      ? null
                      : (_) => widget.onSecuritySettings!())),
        ]),
        widget.warning,
      ]));
}
