import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import 'package:data/dto/dto.dart';

import '../constants/constants.dart';
import 'package:webtrit_phone_tools/src/utils/utils.dart';

import '../utils/utils.dart';

class LocalConfigProcessor {
  const LocalConfigProcessor({required this.logger});

  final Logger logger;

  Future<void> writeBuildCache({
    required ApplicationDTO application,
    required String projectKeystorePath,
    required String? cachePathArg,
    required String Function(String) resolvePath,
  }) async {
    final config = AppConfigFactory.createBuildCacheConfig(application, projectKeystorePath);

    final cachePath = cachePathArg ?? defaultCacheSessionDataPath;
    await writeJsonToFile(resolvePath(cachePath), config, logger: logger);
  }

  Future<void> writeEnvironmentConfig({
    required ApplicationDTO application,
    required String projectKeystorePath,
    required String Function(String) resolvePath,
  }) async {
    final env = AppConfigFactory.createDartDefineEnv(application, projectKeystorePath);

    final file = File(resolvePath(configureDartDefinePath));
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }

    await file.writeAsString(jsonEncode(env));
    logger.success('✓ Environment config written to ${file.path}');
  }
}
