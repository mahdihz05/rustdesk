import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/abrit/abrit_config.dart';
import 'package:flutter_hbb/abrit/abrit_promotion_data.dart';
import 'package:flutter_hbb/abrit/abrit_update.dart';

void main() {
  final config = AbritConfig.fromJson({
    'api_base': 'https://control.example/api/v1/',
    'website': 'https://company.example',
    'approved_hosts': ['control.example', 'company.example'],
  });
  Map<String, dynamic> promotion() => {
        'version': 1,
        'enabled': true,
        'image_url': 'https://control.example/banner.png',
        'target_url': 'https://company.example/services',
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(days: 1))
            .toIso8601String(),
        'alt': 'Company services',
      };
  Map<String, dynamic> update() => {
        'schema': 1,
        'latest_version': '1.5.1',
        'minimum_supported_version': '1.0.0',
        'blocked_versions': <String>[],
        'force_after': null,
        'download_url': 'https://control.example/client.exe',
        'sha256': List.filled(64, 'a').join(),
        'title': 'Update',
        'message': 'New version',
      };
  test('only exact approved HTTPS origins are allowed', () {
    expect(config.permits(Uri.parse('https://company.example/page')), isTrue);
    for (final url in [
      'http://company.example',
      'https://company.example.evil.test',
      'https://evil.company.example',
      'https://user@company.example',
      'https://company.example:8443',
      'file:///tmp/client.exe'
    ]) {
      expect(config.permits(Uri.parse(url)), isFalse, reason: url);
    }
  });
  test('expired, disabled and foreign promotions are rejected', () {
    expect(AbritPromotion.fromJson(promotion(), config).expired, isFalse);
    for (final patch in [
      {'expires_at': '2020-01-01T00:00:00Z'},
      {'enabled': false},
      {'version': 2},
      {'target_url': 'https://foreign.example'},
      {'image_url': 'http://control.example/banner.png'},
    ]) {
      expect(() => AbritPromotion.fromJson({...promotion(), ...patch}, config),
          throwsFormatException);
    }
  });
  test('update requires a SHA-256 and approved download URL', () {
    expect(
        AbritUpdateManifest.fromJson(update(), config).latestVersion, '1.5.1');
    for (final patch in [
      {'sha256': ''},
      {'sha256': List.filled(64, 'z').join()},
      {'download_url': 'https://github.com/rustdesk/client.exe'},
      {'schema': 2},
      {'latest_version': 'latest'},
      {
        'blocked_versions': ['invalid']
      },
    ]) {
      expect(
          () => AbritUpdateManifest.fromJson({...update(), ...patch}, config),
          throwsFormatException);
    }
  });
}
