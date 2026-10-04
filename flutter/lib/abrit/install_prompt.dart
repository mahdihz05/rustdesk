import 'dart:async';
import 'package:flutter/material.dart';
import '../common.dart';
import '../consts.dart';
import '../models/platform_model.dart';
import '../utils/multi_window_manager.dart';
import 'install_card.dart';

class AbritInstallPrompt extends StatefulWidget {
  final bool compact;
  const AbritInstallPrompt({super.key, required this.compact});
  @override
  State<AbritInstallPrompt> createState() => _AbritInstallPromptState();
}

class _AbritInstallPromptState extends State<AbritInstallPrompt> {
  Timer? _timer;
  bool _visible = false;
  bool _upgrade = false;

  void _refresh() {
    if (!isWindows) return;
    final installed = bind.mainIsInstalled();
    final upgrade = installed && bind.mainIsInstalledLowerVersion();
    final visible = !bind.isDisableInstallation() &&
        (!installed || upgrade) &&
        bind.mainGetBuildinOption(key: kOptionHideHelpCards) != 'Y';
    if (visible != _visible || upgrade != _upgrade) {
      setState(() {
        _visible = visible;
        _upgrade = upgrade;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    if (isWindows) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_visible
      ? const SizedBox.shrink()
      : AbritInstallCard(
          compact: widget.compact,
          upgrade: _upgrade,
          onPressed: () async {
            await rustDeskWinManager.closeAllSubWindows();
            if (_upgrade) {
              bind.mainUpdateMe();
            } else {
              bind.mainGotoInstall();
            }
          });
}
