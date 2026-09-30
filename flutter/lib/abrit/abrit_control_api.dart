import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'abrit_config.dart';

class AbritControlApi {
  static const timeout = Duration(seconds: 6);
  final AbritConfig config;
  AbritControlApi(this.config);

  Future<Uint8List> read(Uri url,
      {int limit = 65536, bool image = false}) async {
    if (!config.permits(url))
      throw const FormatException('Unapproved AbrIT URL');
    final client = http.Client();
    try {
      return await (() async {
        final request = http.Request('GET', url)..followRedirects = false;
        request.headers['Accept'] =
            image ? 'image/png,image/jpeg,image/webp' : 'application/json';
        final response = await client.send(request);
        if (response.statusCode != 200 ||
            (response.contentLength != null &&
                response.contentLength! > limit)) {
          throw const FormatException('Invalid control API response');
        }
        final type = response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase();
        if (image &&
            !['image/png', 'image/jpeg', 'image/webp'].contains(type)) {
          throw const FormatException('Unsupported promotion image');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > limit)
            throw const FormatException('Response too large');
          bytes.add(chunk);
        }
        return bytes.takeBytes();
      })()
          .timeout(timeout);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async =>
      jsonDecode(utf8.decode(await read(config.apiBase.resolve(endpoint))))
          as Map<String, dynamic>;
}
