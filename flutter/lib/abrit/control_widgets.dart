import 'package:flutter/material.dart';
import 'brand.dart';
import 'control.dart';
import 'widgets.dart';

class AbritControlHost extends StatefulWidget {
  final Widget child;
  final AbritControlController controller;
  const AbritControlHost(
      {super.key, required this.child, required this.controller});
  @override
  State<AbritControlHost> createState() => _AbritControlHostState();
}

class _AbritControlHostState extends State<AbritControlHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.start();
  }

  @override
  void dispose() {
    widget.controller.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AbritControlScope(
      controller: widget.controller,
      child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final state = widget.controller.state;
            return Stack(fit: StackFit.expand, children: [
              Offstage(
                  offstage: state.enabled && state.blocked,
                  child: widget.child),
              if (state.enabled && state.blocked)
                Positioned.fill(
                    child: AbritRequiredUpdate(controller: widget.controller)),
            ]);
          }));
}

Future<void> _download(
    BuildContext context, AbritControlController controller) async {
  final opened = await controller.openDownload();
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(abritText(
            context,
            'The download link could not be opened. Please retry.',
            'لینک دانلود باز نشد. دوباره تلاش کنید.'))));
  }
}

class AbritRequiredUpdate extends StatelessWidget {
  final AbritControlController controller;
  const AbritRequiredUpdate({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final waiting = state.checking && state.update == null;
    final unverified = state.update == null && !waiting;
    return PopScope(
        canPop: false,
        child: Material(
            key: const ValueKey('abrit-required-update'),
            color: AbritColors.background(context),
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AbritCard(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              const Center(child: AbritLogo(size: 52)),
                              const SizedBox(height: 24),
                              Text(
                                  waiting
                                      ? abritText(
                                          context,
                                          'Checking your version',
                                          'در حال بررسی نسخهٔ برنامه')
                                      : unverified
                                          ? abritText(
                                              context,
                                              'Unable to verify your version',
                                              'بررسی نسخه ممکن نشد')
                                          : abritText(
                                              context,
                                              'Update required',
                                              'بروزرسانی الزامی است'),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Text(
                                  waiting
                                      ? abritText(
                                          context,
                                          'Please wait while abritdesk checks for updates.',
                                          'لطفاً صبر کنید تا نسخهٔ برنامه بررسی شود.')
                                      : localizedControlText(
                                          state.update?['message'],
                                          Localizations.localeOf(context)
                                              .languageCode,
                                          abritText(
                                              context,
                                              'Update abritdesk to continue using the application.',
                                              'برای ادامهٔ استفاده از abritdesk باید برنامه را بروزرسانی کنید.')),
                                  style: const TextStyle(height: 1.7)),
                              const SizedBox(height: 12),
                              Text(
                                  '${abritText(context, 'Current version', 'نسخهٔ فعلی')}: ${state.version}'),
                              if (state.latestVersion.isNotEmpty)
                                Text(
                                    '${abritText(context, 'New version', 'نسخهٔ جدید')}: ${state.latestVersion}'),
                              if (state.error)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(unverified
                                        ? abritText(
                                            context,
                                            'Please retry when the update server is available.',
                                            'پس از برقراری ارتباط با سرور، دوباره تلاش کنید.')
                                        : abritText(
                                            context,
                                            'The update server is unavailable. Your saved update requirement remains active.',
                                            'سرور بروزرسانی در دسترس نیست. الزام بروزرسانی دریافت‌شده همچنان برقرار است.'))),
                              if (controller.downloadFailed)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                        abritText(
                                            context,
                                            'The download link could not be opened. Please retry.',
                                            'لینک دانلود باز نشد. دوباره تلاش کنید.'),
                                        style: const TextStyle(
                                            color: Colors.red))),
                              const SizedBox(height: 20),
                              if (waiting)
                                const Center(child: CircularProgressIndicator())
                              else if (safeControlUrl(state.downloadUrl))
                                ElevatedButton.icon(
                                    key: const ValueKey(
                                        'abrit-required-download'),
                                    onPressed: () =>
                                        _download(context, controller),
                                    icon: const Icon(Icons.download_rounded),
                                    label: Text(abritText(
                                        context,
                                        'Download update',
                                        'دانلود بروزرسانی'))),
                              const SizedBox(height: 12),
                              Wrap(
                                  spacing: 12,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    TextButton(
                                        onPressed: controller.refresh,
                                        child: Text(abritText(
                                            context, 'Retry', 'بررسی دوباره'))),
                                    TextButton(
                                        onPressed: controller.onExit,
                                        child: Text(abritText(
                                            context, 'Exit', 'خروج'))),
                                  ]),
                            ])))))));
  }
}

class AbritUpdateNotice extends StatelessWidget {
  final bool alwaysVisible;
  const AbritUpdateNotice({super.key, this.alwaysVisible = false});
  @override
  Widget build(BuildContext context) {
    final controller = AbritControlScope.maybeOf(context);
    if (controller == null ||
        !controller.state.enabled ||
        (!alwaysVisible && !controller.showOptionalUpdate)) {
      return const SizedBox.shrink();
    }
    final state = controller.state;
    return AbritCard(
        compact: true,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              state.updateAvailable
                  ? '${abritText(context, 'Update available', 'بروزرسانی موجود است')}: ${state.latestVersion}'
                  : state.error
                      ? abritText(context, 'Update server unavailable',
                          'سرور بروزرسانی در دسترس نیست')
                      : abritText(context, 'Your version is up to date',
                          'نسخهٔ برنامه به‌روز است'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (state.updateAvailable)
            Text(localizedControlText(
                state.update?['message'],
                Localizations.localeOf(context).languageCode,
                abritText(
                    context,
                    'You can continue using this version or download the update.',
                    'می‌توانید از این نسخه استفاده کنید یا بروزرسانی را دریافت کنید.'))),
          Wrap(spacing: 8, alignment: WrapAlignment.end, children: [
            if (state.updateAvailable)
              TextButton.icon(
                  onPressed: () => _download(context, controller),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(abritText(
                      context, 'Download update', 'دانلود بروزرسانی'))),
            if (!alwaysVisible)
              TextButton(
                  onPressed: controller.dismissOptionalUpdate,
                  child: Text(abritText(context, 'Later', 'بعداً'))),
            if (alwaysVisible)
              TextButton(
                  onPressed: controller.refresh,
                  child: Text(abritText(
                      context, 'Check for updates', 'بررسی بروزرسانی'))),
          ])
        ]));
  }
}
