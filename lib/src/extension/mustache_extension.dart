import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart';
import 'package:simple_mustache/simple_mustache.dart';

extension MustacheExtension on Mustache {
  Future<String> convertFromFile(String path) async {
    final packageUri = Uri.parse('package:webtrit_phone_tools/');
    final absoluteUri = (await Isolate.resolvePackageUri(packageUri))!.path;
    final contents = File.fromUri(Uri.parse(join(dirname(absoluteUri), normalize(path)))).readAsStringSync();
    return convert(contents);
  }
}
