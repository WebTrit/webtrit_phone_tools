// utils/json_uri_rewriter.dart
import 'dart:io';
import 'package:path/path.dart' as p;

typedef BytesFetcher = Future<List<int>?> Function(String url);
typedef LogFn = void Function(String);

class JsonUriRewriter {
  JsonUriRewriter({
    required this.fetchBytes,
    required this.assetsRootOnDisk,
    required this.assetLogicalPrefix, // e.g. 'asset://assets/images'
    required this.deriveFilename,
    required this.sniffExt,
    required this.cache,
    required this.info,
    required this.thiswarn,
    required this.thiserr,
  });

  final BytesFetcher fetchBytes;
  final String assetsRootOnDisk; // folder on disk: <project>/assets/images
  final String assetLogicalPrefix; // logical uri:   asset://assets/images
  final String Function(String url, {String? fallbackExt}) deriveFilename;
  final String? Function(List<int> bytes) sniffExt;
  final Map<String, String> cache;
  final LogFn info;
  final LogFn thiswarn;
  final LogFn thiserr;

  bool _looksUrl(Object? v) {
    if (v is! String) return false;
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<dynamic> transform(dynamic node) async {
    if (node is Map) {
      // Keys that conventionally store URLs
      const urlishKeys = {'uri', 'url'};
      // Also treat metadata keys ending with "Url"
      final result = <String, dynamic>{};
      for (final entry in node.entries) {
        final k = entry.key.toString();
        final v = entry.value;

        if (urlishKeys.contains(k) || k.endsWith('Url') || k.endsWith('URL')) {
          if (_looksUrl(v)) {
            final newUri = await _downloadAndMakeAssetUri(v as String);
            result[k] = newUri;
            continue;
          }
        }

        // Common structure: { imageSource: { uri: ... } }
        if (k == 'imageSource' && v is Map && _looksUrl(v['uri'])) {
          final newUri = await _downloadAndMakeAssetUri(v['uri'] as String);
          final newImageSource = Map<String, dynamic>.from(v)..['uri'] = newUri;
          result[k] = newImageSource;
          continue;
        }

        // Recurse
        result[k] = await transform(v);
      }
      return result;
    } else if (node is List) {
      return Future.wait(node.map(transform));
    } else {
      return node;
    }
  }

  Future<String> _downloadAndMakeAssetUri(String url) async {
    // single-flight cache
    if (cache.containsKey(url)) return cache[url]!;
    final bytes = await fetchBytes(url);
    if (bytes == null) {
      thiserr('Failed to download: $url');
      return url; // leave as is if failed
    }

    // Decide extension
    final ext = sniffExt(bytes) ?? 'bin';
    final filename = deriveFilename(url, fallbackExt: ext);
    final outDisk = p.normalize(p.join(assetsRootOnDisk, filename));
    await File(outDisk).create(recursive: true);
    await File(outDisk).writeAsBytes(bytes);

    final logical = '$assetLogicalPrefix/$filename';
    info('Saved $url → $logical');
    cache[url] = logical;
    return logical;
  }
}
