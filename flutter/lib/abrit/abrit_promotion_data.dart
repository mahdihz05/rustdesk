import 'abrit_config.dart';

class AbritPromotion {
  final Uri imageUrl;
  final Uri targetUrl;
  final String alt;
  final DateTime? expiresAt;
  AbritPromotion.fromJson(Map<String, dynamic> json, AbritConfig config)
      : imageUrl = Uri.parse(json['image_url'] as String),
        targetUrl = Uri.parse(json['target_url'] as String),
        alt = json['alt'] is String
            ? (json['alt'] as String)
                .substring(0, (json['alt'] as String).length.clamp(0, 200))
            : 'ABRIT',
        expiresAt = json['expires_at'] == null
            ? null
            : DateTime.parse(json['expires_at'] as String) {
    if (json['version'] != 1 ||
        json['enabled'] != true ||
        !config.permits(imageUrl) ||
        !config.permits(targetUrl) ||
        expired) {
      throw const FormatException('Invalid promotion metadata');
    }
  }
  bool get expired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());
}
