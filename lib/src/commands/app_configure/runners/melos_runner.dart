import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

/// Asks the phone project to configure itself.
///
/// Generating launcher icons, generating a splash screen and applying a
/// package name are things that application can do; which of them a build
/// wants is this tool's business, and how they are done is not. Each is a
/// melos script declared in that repository, beside the dependencies it needs
/// - so the project stays runnable by hand, and nothing here has to know that
/// one of them is `flutter_launcher_icons` and another is `package_rename`.
///
/// This used to run `make` targets that did the same three things. Those
/// targets each added their generator as a dependency before running it, which
/// is how they worked in a checkout nobody had resolved yet; the scripts
/// declare theirs, so the dependencies are fetched once here instead.
class MelosRunner {
  const MelosRunner({required this.logger});

  final Logger logger;

  /// Resolves the project's own dependencies, once, before any script runs.
  ///
  /// Not the same as `FlutterRunner.setupDependencies`, which activates global
  /// command line tools. This is the checkout's own package resolution, and
  /// without it melos is not there to be run.
  Future<void> fetchDependencies(String workingDirectory) async {
    await _run(workingDirectory, 'flutter', ['pub', 'get'], 'Dependency resolution');
  }

  Future<void> configureLaunchIcons(String workingDirectory) async {
    await _melos(workingDirectory, 'icons:generate');
  }

  Future<void> configureSplash(String workingDirectory) async {
    await _melos(workingDirectory, 'splash:generate');
  }

  Future<void> configurePlatformIdentifiers(String workingDirectory) async {
    await _melos(workingDirectory, 'package:rename');
  }

  Future<void> _melos(String workingDirectory, String script) async {
    await _run(workingDirectory, 'dart', ['run', 'melos', 'run', script], 'Melos script "$script"');
  }

  Future<void> _run(String workingDirectory, String executable, List<String> arguments, String label) async {
    final process = await Process.run(executable, arguments, workingDirectory: workingDirectory);

    final stdout = process.stdout.toString().trim();
    final stderr = process.stderr.toString().trim();
    if (stdout.isNotEmpty) logger.info(stdout);
    if (stderr.isNotEmpty) {
      process.exitCode != 0 ? logger.err(stderr) : logger.detail(stderr);
    }
    logger.info('$label finished with: ${process.exitCode}');
  }
}
