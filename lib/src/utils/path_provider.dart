import 'dart:isolate';

import 'package:path/path.dart';

class PathProvider {
  static Future<String> getWebtritPhoneToolsPath() async {
    final packageUri = Uri.parse('package:webtrit_phone_tools/');
    final absoluteUri = (await Isolate.resolvePackageUri(packageUri))!.path;
    return join(dirname(absoluteUri), 'bin', 'webtrit_phone_tools.dart');
  }
}
