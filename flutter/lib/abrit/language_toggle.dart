import 'package:flutter/material.dart';
import 'brand.dart';

class AbritLanguageToggle extends StatelessWidget {
  final ValueChanged<String>? onChanged;
  const AbritLanguageToggle({super.key, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        key: const ValueKey('abrit-header-language'),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AbritColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AbritColors.muted(context).withOpacity(.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final option in const [('ar', 'ع', 'العربية'), ('fa', 'فا', 'فارسی'), ('en', 'EN', 'English')])
            Tooltip(
              message: option.$3,
              child: Semantics(
                button: true,
                selected: language == option.$1,
                label: option.$3,
                child: InkWell(
                  key: ValueKey('abrit-language-${option.$1}'),
                  onTap: onChanged == null ? null : () => onChanged!(option.$1),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: language == option.$1 ? AbritColors.foreground(context) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(option.$2, style: TextStyle(fontSize: 12,
                      fontFamily: option.$1 == 'en' ? 'NotoSans' : 'Vazirmatn',
                      color: language == option.$1 ? AbritColors.surface(context) : AbritColors.muted(context))),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
