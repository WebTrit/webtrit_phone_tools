import 'package:path/path.dart' as path;

class CommandContext {
  const CommandContext({
    required this.workingDirectoryPath,
    required this.applicationId,
    required this.projectKeystorePath,
    required this.authHeader,
    required this.cachePathArg,
  });

  final String workingDirectoryPath;
  final String applicationId;
  final String projectKeystorePath;
  final Map<String, String> authHeader;
  final String? cachePathArg;

  String resolvePath(String inputPath) {
    if (path.isAbsolute(inputPath)) {
      return path.normalize(inputPath);
    }
    return path.normalize(path.join(workingDirectoryPath, inputPath));
  }
}
