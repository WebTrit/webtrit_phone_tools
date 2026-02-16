import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

import 'hash_utils.dart';

typedef BytesFetcher = Future<Uint8List?> Function(String url);

class JsonAssetMigrator {
  JsonAssetMigrator({
    required this.fetchBytes,
    required this.assetsRootOnDisk,
    required this.assetLogicalPrefix,
    required this.logger,
  });

  final BytesFetcher fetchBytes;
  final String assetsRootOnDisk;
  final String assetLogicalPrefix;
  final Logger logger;

  final Map<String, String> _cache = {};

  Future<dynamic> transform(dynamic node, {List<String> path = const []}) async {
    if (path.contains('embeddedResources')) return node;

    if (node is Map) {
      final result = <String, dynamic>{};
      for (final entry in node.entries) {
        final k = entry.key.toString();
        final v = entry.value;

        if (_isUrlKey(k) && _isUrlValue(v)) {
          result[k] = await _processUrl(v as String);
          continue;
        }

        if (k == 'imageSource' && v is Map && _isUrlValue(v['uri'])) {
          final newUri = await _processUrl(v['uri'] as String);
          result[k] = Map<String, dynamic>.from(v)..['uri'] = newUri;
          continue;
        }

        result[k] = await transform(v, path: [...path, k]);
      }
      return result;
    } else if (node is List) {
      final result = <dynamic>[];
      for (var i = 0; i < node.length; i++) {
        result.add(await transform(node[i], path: [...path, '[$i]']));
      }
      return result;
    }

    return node;
  }

  bool _isUrlKey(String key) => ['uri', 'url'].contains(key) || key.endsWith('Url') || key.endsWith('URL');

  bool _isUrlValue(Object? value) => value is String && (value.startsWith('http://') || value.startsWith('https://'));

  Future<String> _processUrl(String url) async {
    if (_cache.containsKey(url)) return _cache[url]!;

    final bytes = await fetchBytes(url);
    if (bytes == null) {
      logger.warn('Failed to download asset: $url');
      return url;
    }

    final ext = _sniffExtension(bytes) ?? 'bin';
    final filename = _deriveFilename(url, ext);
    final diskPath = path.join(assetsRootOnDisk, filename);

    try {
      final file = File(diskPath);
      if (!file.parent.existsSync()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsBytes(bytes);

      final logicalPath = '$assetLogicalPrefix/$filename';
      _cache[url] = logicalPath;

      return logicalPath;
    } catch (e) {
      logger.err('Failed to save asset to disk: $e');
      return url;
    }
  }

  String _deriveFilename(String url, String ext) {
    final uri = Uri.tryParse(url);
    final lastSegment = uri?.pathSegments.lastOrNull ?? 'image';

    final hash = HashUtils.generateShort(url);

    final name = lastSegment.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '').replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    return '${name}_$hash.$ext';
  }

  String? _sniffExtension(List<int> bytes) {
    if (bytes.length < 12) return null;

    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes[0] == 0x47 && bytes[1] == 0x49) return 'gif';
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return 'bmp';

    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }

    try {
      final header = utf8.decode(bytes.take(100).toList(), allowMalformed: true);
      if (header.contains('<svg')) return 'svg';
    } catch (_) {}

    return null;
  }
}
