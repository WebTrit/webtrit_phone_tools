import 'dart:convert';

import 'package:mustache_template/mustache.dart';

extension TemplateExtension on Template {
  Map<String, dynamic> renderAndCleanJson(
    Map<String, dynamic> stringValues, {
    bool removeEmptyFields = true,
  }) {
    final renderedString = renderString(stringValues);

    Map<String, dynamic> parsedJson;
    try {
      parsedJson = jsonDecode(renderedString) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Rendered template is not a valid JSON: $e');
    }

    return removeEmptyFields ? _removeEmptyAndNullFields(parsedJson) : parsedJson;
  }

  Map<String, dynamic> _removeEmptyAndNullFields(Map<String, dynamic> json) {
    final cleanJson = <String, dynamic>{};

    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final nested = _removeEmptyAndNullFields(value);
        if (nested.isNotEmpty) {
          cleanJson[key] = nested;
        }
      } else if (value is List) {
        final cleanList = value
            .where((item) => item != null && (item is! String || item.isNotEmpty) && (item is! Map || item.isNotEmpty))
            .map((item) => item is Map<String, dynamic> ? _removeEmptyAndNullFields(item) : item)
            .toList();
        if (cleanList.isNotEmpty) {
          cleanJson[key] = cleanList;
        }
      } else if (value != null && value != '') {
        cleanJson[key] = value;
      }
    });

    return cleanJson;
  }
}
