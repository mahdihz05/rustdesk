import 'package:flutter/material.dart';
import 'brand.dart';
import 'control.dart';
import 'widgets.dart';

class AbritLiveBanner extends StatelessWidget {
  final bool short, compact;
  const AbritLiveBanner(
      {super.key, required this.short, required this.compact});
  @override
  Widget build(BuildContext context) {
    final controller = AbritControlScope.maybeOf(context);
    final banner = controller?.state.banner;
    if (banner == null) return AbritBanner(short: short, compact: compact);
    if (banner['enabled'] == false) return const SizedBox.shrink();
    final language = Localizations.localeOf(context).languageCode;
    final rawImage =
        (AbritColors.isDark(context) ? banner['image_url_dark'] : null) ??
            banner['image_url'] ??
            '';
    final revision =
        (banner['revision'] ?? controller?.state.document?['revision'] ?? '')
            .toString();
    final url = rawImage is String && safeControlUrl(rawImage)
        ? Uri.parse(rawImage)
        : null;
    final image = url?.replace(queryParameters: {
      ...url.queryParameters,
      'abrit_revision': revision
    }).toString();
    final title = localizedControlText(
        banner['title'],
        language,
        abritText(context, 'Secure remote access',
            'راهکاری امن برای دسترسی از راه دور'));
    final subtitle = localizedControlText(banner['subtitle'], language, '');
    final link = banner['link_url'] as String? ?? '';
    final height = context.dependOnInheritedWidgetOfExactType<AbritScope>()?.metrics.bannerHeight ?? (short ? 96.0 : 160.0);
    final fallback = Image.asset('assets/abrit/servers.png', fit: BoxFit.cover);
    return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
            color: const Color(0xFF06162E),
            child: InkWell(
                key: ValueKey('abrit-live-banner-$revision'),
                onTap: controller != null && safeControlUrl(link)
                    ? () async {
                        final opened = await controller.openUrl(link);
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(
                                  content: Text(abritText(
                                      context,
                                      'The link could not be opened.',
                                      'لینک باز نشد.'))));
                        }
                      }
                    : null,
                child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height),
                    child: Stack(children: [
                      Positioned.fill(
                          child: image == null
                              ? fallback
                              : Image.network(image,
                                  key: ValueKey(image),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) =>
                                      progress == null ? child : fallback,
                                  errorBuilder: (_, __, ___) => fallback)),
                      Positioned.fill(
                          child: ColoredBox(
                              color: const Color(0xFF06162E).withOpacity(.55))),
                      ConstrainedBox(
                          constraints: BoxConstraints(minHeight: height),
                          child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 16 : 24, vertical: 12),
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        maxLines: compact ? 1 : 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: compact ? 16 : 24,
                                            fontWeight: FontWeight.w700)),
                                    if (subtitle.isNotEmpty && !compact) ...[
                                      const SizedBox(height: 6),
                                      Text(subtitle,
                                          maxLines: short ? 1 : 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white70)),
                                    ],
                                  ]))),
                    ])))));
  }
}
