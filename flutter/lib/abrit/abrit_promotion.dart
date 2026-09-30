import 'abrit_promotion_data.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'abrit_branding.dart';
import 'abrit_config.dart';
import 'abrit_control_api.dart';

class AbritPromotionBanner extends StatefulWidget {
  const AbritPromotionBanner({super.key});
  @override
  State<AbritPromotionBanner> createState() => _AbritPromotionBannerState();
}

class _AbritPromotionBannerState extends State<AbritPromotionBanner> {
  AbritPromotion? _promotion;
  Uint8List? _bytes;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && (_promotion?.expired ?? false))
        setState(() {
          _promotion = null;
          _bytes = null;
        });
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _validateImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
    try {
      final frame = await codec.getNextFrame();
      try {
        if (frame.image.width < 1 ||
            frame.image.height < 1 ||
            frame.image.height > 4096) {
          throw const FormatException('Invalid image size');
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  void _show(AbritPromotion promotion, Uint8List bytes) {
    if (!mounted || promotion.expired) return;
    setState(() {
      _promotion = promotion;
      _bytes = bytes;
    });
  }

  Future<void> _load() async {
    try {
      final config = await AbritConfig.instance;
      Directory? cache;
      try {
        cache = Directory(
            '${(await getApplicationSupportDirectory()).path}/abrit-promotion');
        final envelope = File('${cache.path}/campaign-cache.json');
        if (await envelope.exists() &&
            await envelope.length() <= 6 * 1024 * 1024) {
          final data =
              jsonDecode(await envelope.readAsString()) as Map<String, dynamic>;
          final promotion = AbritPromotion.fromJson(
              data['metadata'] as Map<String, dynamic>, config);
          final bytes = base64Decode(data['image'] as String);
          if (bytes.length > 4 * 1024 * 1024)
            throw const FormatException('Cache too large');
          await _validateImage(bytes);
          _show(promotion, bytes);
        }
      } catch (_) {/* A missing/invalid cache retains the bundled artwork. */}
      final api = AbritControlApi(config);
      final metadata = await api.get('promotion');
      final promotion = AbritPromotion.fromJson(metadata, config);
      final bytes = await api.read(promotion.imageUrl,
          limit: 4 * 1024 * 1024, image: true);
      await _validateImage(bytes);
      _show(promotion, bytes);
      if (cache != null) {
        try {
          await cache.create(recursive: true);
          // One JSON envelope keeps image and metadata from different campaigns apart.
          final envelope = File('${cache.path}/campaign-cache.json');
          final temp = File('${envelope.path}.tmp');
          await temp.writeAsString(
              jsonEncode({'metadata': metadata, 'image': base64Encode(bytes)}),
              flush: true);
          if (await envelope.exists()) await envelope.delete();
          await temp.rename(envelope.path);
        } catch (_) {/* Cache failure cannot affect a remote session. */}
      }
    } catch (_) {
      /* 404/offline/invalid responses keep the last valid campaign. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback =
        const AbritReferenceArtwork(source: Rect.fromLTWH(32, 684, 1384, 304));
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1384 / 304,
          child: Material(
              color: AbritStyle.navy,
              child: InkWell(
                onTap: () async {
                  try {
                    final config = await AbritConfig.instance;
                    final target = (_promotion?.expired ?? true)
                        ? config.website
                        : _promotion!.targetUrl;
                    if (config.permits(target))
                      await launchUrl(target,
                          mode: LaunchMode.externalApplication);
                  } catch (_) {
                    /* No external navigation if configuration is unavailable. */
                  }
                },
                child: Semantics(
                    button: true,
                    label: _promotion?.alt ?? 'ABRIT managed cloud services',
                    child: _bytes == null
                        ? fallback
                        : Image.memory(_bytes!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => fallback)),
              )),
        ));
  }
}
