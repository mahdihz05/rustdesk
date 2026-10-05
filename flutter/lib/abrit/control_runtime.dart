import 'dart:io';
import 'dart:convert';
import '../models/platform_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'control.dart';

final abritControl = AbritControlController(
    readState: () => bind.mainGetLocalOption(key: 'abrit-control-state'),
    refresh: () =>
        bind.mainSetLocalOption(key: 'abrit-control-refresh', value: '1'),
    openUrl: (url) async {
      try {
        return await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    },
    onExit: () => exit(0));

bool abritConnectionBlocked() {
  if (!Platform.isWindows) return false;
  final raw = bind.mainGetLocalOption(key: 'abrit-control-state');
  if (raw.isEmpty) return false;
  try {
    return (jsonDecode(raw) as Map)['blocked'] == true;
  } catch (_) {
    return true;
  }
}
