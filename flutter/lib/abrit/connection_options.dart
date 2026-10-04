import 'package:flutter/material.dart';
import 'brand.dart';

class AbritConnectionOptions extends StatelessWidget {
  final List<(String, VoidCallback)> actions;
  final bool compact;
  const AbritConnectionOptions({super.key, required this.actions, this.compact = false});

  @override
  Widget build(BuildContext context) => Container(
      width: 44,
      height: compact ? 48 : 64,
      decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8)),
      child: PopupMenuButton<int>(
        key: const ValueKey('abrit-connection-options'),
        tooltip: abritText(
            context, 'More connection options', 'گزینه‌های دیگر اتصال'),
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        color: AbritColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        onSelected: (index) => actions[index].$2(),
        itemBuilder: (_) => [
          for (var i = 0; i < actions.length; i++)
            PopupMenuItem(value: i, child: Text(actions[i].$1))
        ],
      ));
}
