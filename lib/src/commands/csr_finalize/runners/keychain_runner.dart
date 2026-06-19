import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

/// Re-packages a PKCS12 bundle through the macOS keychain so the resulting file
/// carries a MAC that `security import` accepts.
///
/// OpenSSL 3.x and Apple's SecurityFramework compute the PKCS12 MAC differently
/// for empty passwords, so a bundle written directly by `openssl pkcs12 -export`
/// with an empty password is rejected by macOS with
/// "MAC verification failed during PKCS12 import (wrong password?)". Importing
/// the bundle into a throwaway keychain and exporting it again with `security`
/// produces the same MAC layout (MAC iteration 1) the other applications use,
/// which imports cleanly with an empty password.
///
/// macOS only — `security` is not available on other platforms.
class KeychainRunner {
  const KeychainRunner({required this.logger});

  final Logger logger;

  /// Imports [sourcePkcs12Path] (protected by [sourcePassword]) into a temporary
  /// keychain and re-exports it to [outputPkcs12Path] under [outputPassword].
  /// The temporary keychain is always removed. Returns `false` on failure.
  bool repackage({
    required String sourcePkcs12Path,
    required String sourcePassword,
    required String outputPkcs12Path,
    required String outputPassword,
    required String workDirectory,
  }) {
    final keychainPath = path.join(workDirectory, 'csr_finalize.keychain');
    const keychainPassword = 'csr-finalize';

    try {
      if (!_run('create-keychain', ['create-keychain', '-p', keychainPassword, keychainPath])) return false;
      if (!_run('unlock-keychain', ['unlock-keychain', '-p', keychainPassword, keychainPath])) return false;
      // -A grants every tool access so the later export does not prompt.
      if (!_run('import', ['import', sourcePkcs12Path, '-k', keychainPath, '-P', sourcePassword, '-A'])) return false;

      final output = File(outputPkcs12Path);
      if (output.existsSync()) output.deleteSync();

      return _run('export', [
        'export', '-k', keychainPath, '-t', 'identities', '-f', 'pkcs12', '-P', outputPassword, '-o', outputPkcs12Path, //
      ]);
    } finally {
      Process.runSync('security', ['delete-keychain', keychainPath], runInShell: true);
    }
  }

  bool _run(String step, List<String> arguments) {
    final result = Process.runSync('security', arguments, runInShell: true);
    if (result.exitCode != 0) {
      logger
        ..info(result.stdout.toString())
        ..err('security $step failed: ${result.stderr}');
      return false;
    }
    return true;
  }
}
