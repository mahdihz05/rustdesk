import 'dart:convert';
import 'package:flutter/services.dart';

class AbritConfig {
  final Uri apiBase;
  final Uri website;
  final Set<String> approvedHosts;

  AbritConfig.fromJson(Map<String, dynamic> json)
      : apiBase = Uri.parse(json['api_base'] as String),
        website = Uri.parse(json['website'] as String),
        approvedHosts = (json['approved_hosts'] as List).cast<String>().toSet();

  static final Future<AbritConfig> instance = rootBundle
      .loadString('assets/abrit_config.json')
      .then((data) =>
          AbritConfig.fromJson(jsonDecode(data) as Map<String, dynamic>));

  bool permits(Uri url) =>
      url.scheme == 'https' &&
      url.userInfo.isEmpty &&
      (!url.hasPort || url.port == 443) &&
      approvedHosts.contains(url.host.toLowerCase());
}
