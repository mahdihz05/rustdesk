import 'package:flutter/material.dart';
import 'brand.dart';

class AbritLanguageToggle extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  final bool compact;
  const AbritLanguageToggle({super.key, this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        key: const ValueKey('abrit-navigation-language'),
        padding: EdgeInsets.all(compact ? 4 : 6),
        decoration: BoxDecoration(
          color: AbritColors.background(context),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AbritColors.muted(context).withOpacity(.08)),
          boxShadow: [BoxShadow(color: AbritColors.blue.withOpacity(.08),
            blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Flex(direction: compact ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min, children: [
          for (final option in const [('fa', 'فا', 'فارسی'), ('en', 'EN', 'English')])
            Tooltip(
              message: option.$3,
              child: Semantics(
                button: true,
                selected: language == option.$1,
                label: option.$3,
                child: InkWell(
                  key: ValueKey('abrit-language-${option.$1}'),
                  onTap: onChanged == null ? null : () => onChanged!(option.$1),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: compact ? 32 : MediaQuery.sizeOf(context).width < 1100 ? 60 : 78,
                    height: compact ? 34 : 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: language == option.$1 ? AbritColors.blue : null,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: language == option.$1 ? [BoxShadow(
                        color: AbritColors.blue.withOpacity(.24),
                        blurRadius: 12, offset: const Offset(0, 3))] : null,
                    ),
                    child: Text(option.$2, style: TextStyle(fontSize: compact ? 12 : 16,
                      fontFamily: option.$1 == 'en' ? 'NotoSans' : 'Vazirmatn',
                      color: language == option.$1 ? Colors.white : AbritColors.muted(context))),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
