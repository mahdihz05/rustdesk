import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

String localizedControlText(dynamic value, String language, String fallback) {
  if (value is String && value.isNotEmpty) return value;
  if (value is Map) {
    final text = value[language] ?? value['en'];
    if (text is String && text.isNotEmpty) return text;
  }
  return fallback;
}

bool safeControlUrl(String value) {
  final uri = Uri.tryParse(value);
  return value.length <= 2048 &&
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !RegExp(r'[\s\\]').hasMatch(value);
}

class AbritControlState {
  final bool enabled, checking, blocked, error;
  final String version;
  final Map<String, dynamic>? document;
  const AbritControlState(
      {this.enabled = false,
      this.checking = false,
      this.blocked = false,
      this.error = false,
      this.version = '',
      this.document});
  factory AbritControlState.parse(String raw) {
    final value = jsonDecode(raw) as Map<String, dynamic>;
    for (final key in ['enabled', 'checking', 'blocked', 'error']) {
      if (value[key] is! bool) {
        throw const FormatException('Invalid control state');
      }
    }
    final document = value['document'] as Map<String, dynamic>?;
    if (document != null && document['schema_version'] != 1) {
      throw const FormatException('Unsupported control manifest');
    }
    return AbritControlState(
        enabled: value['enabled'],
        checking: value['checking'],
        blocked: value['blocked'],
        error: value['error'],
        version: value['current_version'] as String,
        document: document);
  }
  Map<String, dynamic>? get banner =>
      document?['banner'] as Map<String, dynamic>?;
  Map<String, dynamic>? get update =>
      document?['update'] as Map<String, dynamic>?;
  String get latestVersion => update?['latest_version'] as String? ?? '';
  String get downloadUrl => update?['download_url'] as String? ?? '';
  bool get updateAvailable {
    List<int>? parse(String value) {
      if (!RegExp(r'^\d+(\.\d+){0,2}$').hasMatch(value)) return null;
      final result = value.split('.').map(int.parse).toList();
      while (result.length < 3) {
        result.add(0);
      }
      return result;
    }

    final current = parse(version), latest = parse(latestVersion);
    if (current == null || latest == null) return false;
    for (var i = 0; i < 3; i++) {
      if (latest[i] != current[i]) return latest[i] > current[i];
    }
    return false;
  }
}

class AbritControlController extends ChangeNotifier {
  final String Function() readState;
  final VoidCallback refresh;
  final Future<bool> Function(String) openUrl;
  final VoidCallback onExit;
  AbritControlState state = const AbritControlState();
  bool downloadFailed = false;
  String _raw = '', _dismissedVersion = '';
  Timer? _timer;
  AbritControlController(
      {required this.readState,
      required this.refresh,
      required this.openUrl,
      required this.onExit});
  void start() {
    poll();
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void poll() {
    try {
      final raw = readState();
      if (raw.isEmpty || raw == _raw) return;
      final fresh = AbritControlState.parse(raw);
      state = fresh;
      _raw = raw;
      notifyListeners();
    } catch (error) {
      debugPrint('abritdesk control state unavailable: $error');
    }
  }

  bool get showOptionalUpdate =>
      state.enabled &&
      !state.blocked &&
      state.updateAvailable &&
      state.latestVersion != _dismissedVersion;
  void dismissOptionalUpdate() {
    if (state.blocked) return;
    _dismissedVersion = state.latestVersion;
    notifyListeners();
  }

  Future<bool> openDownload() async {
    var opened = false;
    if (safeControlUrl(state.downloadUrl)) {
      try {
        opened = await openUrl(state.downloadUrl);
      } catch (error) {
        debugPrint('abritdesk download link unavailable: $error');
      }
    }
    downloadFailed = !opened;
    notifyListeners();
    return opened;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

class AbritControlScope extends InheritedNotifier<AbritControlController> {
  const AbritControlScope(
      {super.key,
      required AbritControlController controller,
      required super.child})
      : super(notifier: controller);
  static AbritControlController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AbritControlScope>()?.notifier;
}
