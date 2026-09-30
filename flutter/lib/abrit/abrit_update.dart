import 'abrit_config.dart';
import 'abrit_control_api.dart';

class AbritUpdateManifest {
  final String latestVersion;
  final String minimumSupportedVersion;
  final List<String> blockedVersions;
  final DateTime? forceAfter;
  final Uri downloadUrl;
  final String sha256;
  final String title;
  final String message;

  AbritUpdateManifest.fromJson(Map<String, dynamic> json, AbritConfig config)
      : latestVersion = json['latest_version'] as String,
        minimumSupportedVersion = json['minimum_supported_version'] as String,
        blockedVersions = (json['blocked_versions'] as List).cast<String>(),
        forceAfter = json['force_after'] == null
            ? null
            : DateTime.parse(json['force_after'] as String),
        downloadUrl = Uri.parse(json['download_url'] as String),
        sha256 = json['sha256'] as String,
        title = json['title'] as String,
        message = json['message'] as String {
    final version = RegExp(r'^\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$');
    if (json['schema'] != 1 ||
        !version.hasMatch(latestVersion) ||
        !version.hasMatch(minimumSupportedVersion) ||
        blockedVersions.any((value) => !version.hasMatch(value)) ||
        !config.permits(downloadUrl) ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256)) {
      throw const FormatException('Invalid AbrIT update manifest');
    }
  }
}

class AbritUpdate {
  // Preview foundation only: never downloads, executes or locks the running app.
  static Future<AbritUpdateManifest?> check() async {
    try {
      final config = await AbritConfig.instance;
      return AbritUpdateManifest.fromJson(
          await AbritControlApi(config).get('update'), config);
    } catch (_) {
      return null;
    }
  }
}
