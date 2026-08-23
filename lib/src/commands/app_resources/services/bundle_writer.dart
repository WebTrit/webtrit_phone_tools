import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import 'package:webtrit_phone_tools/src/utils/utils.dart';

import '../models/build_bundle.dart';

/// Puts a bundle on disk.
///
/// Everything here is a copy, not a decision: the service already chose the
/// theme, resolved the appearances, rewrote each picture reference to the file
/// it will live in, and named the path every document belongs to. What is left
/// is writing, which is why nothing in this class knows what any of it means.
class BundleWriter {
  const BundleWriter({required this.httpClient, required this.logger});

  final HttpClient httpClient;
  final Logger logger;

  /// The configuration documents, each under the path the bundle gave it.
  Future<void> writeFiles(
    Map<String, dynamic> files,
    String Function(String) resolvePath,
  ) async {
    for (final entry in files.entries) {
      await writeJsonToFile(resolvePath(entry.key), entry.value, logger: logger);
    }
  }

  /// The pictures the documents point at.
  ///
  /// A picture that cannot be fetched is named and skipped rather than allowed
  /// to end the run: the app shows a gap where it should have been, which is
  /// visible and recoverable, while a run that stops here leaves the brand with
  /// no configuration at all.
  Future<void> downloadAssets(
    List<BundleAsset> assets,
    String Function(String) resolvePath,
  ) async {
    for (final asset in assets) {
      await _download(asset.url, asset.path, 'picture ${asset.id}', resolvePath);
    }
  }

  /// The splash screen and the launcher icons, each to the file the bundle
  /// named for it.
  Future<void> downloadBrandImages(
    BrandImageSet images,
    String what,
    String Function(String) resolvePath,
  ) async {
    if (images.isEmpty) {
      logger.warn('No $what of its own: the app will be built with the stock WebTrit one');
      return;
    }
    for (final image in images.files) {
      await _download(image.url, image.path, what, resolvePath);
    }
  }

  Future<void> _download(
    String url,
    String path,
    String what,
    String Function(String) resolvePath,
  ) async {
    if (url.isEmpty) {
      logger.warn('No address for $what, skipping');
      return;
    }
    // A refused or missing file is a warning, not the end of the run - and the
    // client raises rather than returns for anything but a 200, so the refusal
    // has to be caught here or it would take the whole brand down with it.
    final bytes = await httpClient.getBytes(url).onError<Object>((error, _) {
      logger.warn('Could not fetch $what: $error');
      return null;
    });
    if (bytes == null) {
      logger.warn('No $what was written');
      return;
    }
    final file = File(resolvePath(path));
    if (!file.parent.existsSync()) await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    logger.success('✓ $what written to $path');
  }
}
