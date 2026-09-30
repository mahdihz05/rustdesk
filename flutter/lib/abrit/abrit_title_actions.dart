import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/abrit/abrit_identity.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import '../desktop/pages/desktop_setting_page.dart';
import '../desktop/pages/desktop_tab_page.dart';
import 'abrit_branding.dart';

class AbritTitleActions extends StatefulWidget {
  const AbritTitleActions({super.key});
  @override
  State<AbritTitleActions> createState() => _AbritTitleActionsState();
}

class _AbritTitleActionsState extends State<AbritTitleActions> {
  Timer? _timer;
  bool _installed = true;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _installed = bind.mainIsInstalled();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final installed = bind.mainIsInstalled();
      if (mounted && installed != _installed)
        setState(() => _installed = installed);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 10),
        IconButton(
            tooltip: translate('Account'),
            icon: const Icon(Icons.account_circle,
                color: AbritStyle.blue, size: 30),
            onPressed: () =>
                DesktopSettingPage.switch2page(SettingsTabKey.account)),
        if (!_installed && !bind.isDisableInstallation())
          SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AbritStyle.blue,
                    side: const BorderSide(color: Color(0xFFB6D9FF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9)),
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await rustDeskWinManager.closeAllSubWindows();
                          bind.mainGotoInstall();
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(abritText('Install', 'نصب برنامه'),
                    style: const TextStyle(fontSize: 12)),
              )),
        IconButton(
            tooltip: translate('Settings'),
            icon: const Icon(Icons.menu, size: 20),
            onPressed: DesktopTabPage.onAddSetting),
      ]);
}
