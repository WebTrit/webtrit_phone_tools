import 'dart:convert';

import 'package:mustache_template/mustache.dart';

import 'package:webtrit_phone_tools/src/extension/map_extension.dart';

extension TemplateExtension on Template {
  String renderStringFilteredJson(Map<String, String?> values) {
    final rendered = renderString(values);

    Map<String, dynamic> parsedJson;
    try {
      parsedJson = jsonDecode(rendered) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Rendered template is not a valid JSON: $e');
    }

    parsedJson.removeWhere((key, value) => value == null || value == '');

    return parsedJson.toJson();
  }
}
