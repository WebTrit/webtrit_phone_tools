import '../constants.dart';

abstract class CommandHelpFormatter {
  /// Formats a command description with consistent indentation and delimiters.
  static String formatDescription({
    required String title,
    required String parameter,
    required String description,
    required String note,
  }) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..write(parameterIndent)
      ..write(parameter)
      ..write(parameterDelimiter)
      ..writeln(description);

    final paddingSize = parameterIndent.length + parameter.length + parameterDelimiter.length;
    buffer
      ..write(' ' * paddingSize)
      ..write(note);

    return buffer.toString();
  }
}
