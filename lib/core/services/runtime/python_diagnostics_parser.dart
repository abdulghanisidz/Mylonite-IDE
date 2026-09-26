import '../../models/diagnostic.dart';

/// PythonDiagnosticsParser — Parses Python tracebacks into Diagnostic objects.
///
/// Handles:
/// - Standard Python tracebacks
/// - Syntax errors with line/column info
/// - Runtime exceptions with stack traces
/// - Multiple errors in one output
///
/// Example traceback:
/// ```
/// Traceback (most recent call last):
///   File "test.py", line 5, in <module>
///     result = divide(10, 0)
///   File "test.py", line 2, in divide
///     return a / b
/// ZeroDivisionError: division by zero
/// ```
///
/// Architecture: 04-RUNTIME-SYSTEM.md §5
class PythonDiagnosticsParser {
  /// Parse Python stderr output into diagnostics.
  static List<Diagnostic> parse(String stderr, {String? filePath}) {
    if (stderr.trim().isEmpty) return [];

    final diagnostics = <Diagnostic>[];
    final lines = stderr.split('\n');

    // Check for syntax errors first (different format)
    final syntaxError = _parseSyntaxError(lines, filePath);
    if (syntaxError != null) {
      diagnostics.add(syntaxError);
      return diagnostics;
    }

    // Parse standard tracebacks
    final traceback = _parseTraceback(lines, filePath);
    if (traceback != null) {
      diagnostics.add(traceback);
    }

    return diagnostics;
  }

  /// Parse syntax error format:
  /// ```
  ///   File "test.py", line 3
  ///     print("Hello"
  ///                  ^
  /// SyntaxError: unexpected EOF while parsing
  /// ```
  static Diagnostic? _parseSyntaxError(List<String> lines, String? filePath) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Look for "SyntaxError:" or "IndentationError:"
      if (line.startsWith('SyntaxError:') ||
          line.startsWith('IndentationError:') ||
          line.startsWith('TabError:')) {
        // Find the "File ..." line above
        String? file = filePath;
        int? lineNumber;
        int? column;

        // Search backwards for file info
        for (int j = i - 1; j >= 0 && j >= i - 5; j--) {
          final prevLine = lines[j].trim();

          // Match: File "test.py", line 3
          final fileMatch = RegExp(r'File "([^"]+)", line (\d+)')
              .firstMatch(prevLine);
          if (fileMatch != null) {
            file = fileMatch.group(1);
            lineNumber = int.tryParse(fileMatch.group(2)!);
            break;
          }
        }

        // Try to extract column from caret line (^)
        if (i > 0) {
          final caretLine = lines[i - 1];
          final caretIndex = caretLine.indexOf('^');
          if (caretIndex >= 0) {
            column = caretIndex;
          }
        }

        return Diagnostic(
          severity: DiagnosticSeverity.error,
          message: line,
          file: file,
          line: lineNumber,
          column: column,
          source: 'python',
        );
      }
    }

    return null;
  }

  /// Parse standard traceback format:
  /// ```
  /// Traceback (most recent call last):
  ///   File "test.py", line 5, in <module>
  ///     result = divide(10, 0)
  ///   File "test.py", line 2, in divide
  ///     return a / b
  /// ZeroDivisionError: division by zero
  /// ```
  static Diagnostic? _parseTraceback(List<String> lines, String? filePath) {
    int? tracebackStart;

    // Find "Traceback (most recent call last):"
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith('Traceback (most recent call last):')) {
        tracebackStart = i;
        break;
      }
    }

    if (tracebackStart == null) return null;

    // Find the error message (last non-empty line)
    String? errorMessage;
    String? file = filePath;
    int? lineNumber;

    for (int i = tracebackStart + 1; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      // Match: File "test.py", line 5, in <module>
      final fileMatch = RegExp(r'File "([^"]+)", line (\d+)').firstMatch(line);
      if (fileMatch != null) {
        file = fileMatch.group(1);
        lineNumber = int.tryParse(fileMatch.group(2)!);
        continue;
      }

      // If not a file line and not indented code, it's the error message
      if (!line.startsWith('File ') && !lines[i].startsWith('  ')) {
        errorMessage = line;
      }
    }

    if (errorMessage == null) return null;

    return Diagnostic(
      severity: DiagnosticSeverity.error,
      message: errorMessage,
      file: file,
      line: lineNumber,
      source: 'python',
    );
  }
}
