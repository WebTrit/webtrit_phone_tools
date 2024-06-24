import 'dart:convert';

import 'package:simple_mustache/simple_mustache.dart';

extension MustacheExtension on Mustache {
  /// Converts a Mustache template with embedded JSON-like structures to a
  /// properly formatted JSON string.
  ///
  /// [template] is the Mustache template containing JSON-like structures.
  /// This function handles lists within the template and formats the output
  /// JSON string with proper indentation.
  String toStringifyJSON(String template) {
    // Regular expression to find list placeholders in the format: [{{ key }}]
    final regex = RegExp(r'\[\{\{ (\w+) \}\}\]');
    final matches = regex.allMatches(template);

    // Start with the original template
    var result = template;

    // Replace each list placeholder with the corresponding JSON array string
    for (final match in matches) {
      final key = match.group(1);
      if (key != null && map[key] is List) {
        final list = map[key] as List;
        // Convert list elements to a JSON-compatible string
        final listString = list.map((e) => e is String ? '"$e"' : e.toString()).join(', ');
        result = result.replaceAll('[{{ $key }}]', '[$listString]');
      }
    }

    // Parse the modified template string as a JSON object
    final jsonObject = json.decode(result);

    // Convert the JSON object to a formatted string with indentation
    final jsonEncoder = const JsonEncoder.withIndent('  ').convert(jsonObject);

    // Return the formatted JSON string
    return (StringBuffer()..writeln(jsonEncoder)).toString();
  }
}
