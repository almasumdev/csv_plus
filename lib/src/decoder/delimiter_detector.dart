/// Auto-detects field delimiter, BOM, and Excel `sep=` hint from input.
class DelimiterDetector {
  /// Create a delimiter detector instance (stateless, reusable).
  const DelimiterDetector();

  static const _candidates = [',', ';', '\t', '|'];
  static const _bom = 0xFEFF;
  static const _maxSampleLines = 10;

  /// Detect the most likely field delimiter from a sample string.
  ///
  /// Algorithm:
  /// 1. Check for an Excel `sep=X` hint on the first line.
  /// 2. A candidate qualifies only when it appears (outside quotes) on
  ///    every sampled non-empty line: a real delimiter shows up in every
  ///    row, so single-column text that merely contains a `;` does not
  ///    qualify.
  /// 3. Qualifying candidates are ranked by count consistency across
  ///    lines, then by column count; ties keep the earlier candidate
  ///    (`,` before `;`, `\t`, `|`).
  /// 4. When nothing qualifies, the default `,` is returned.
  String detectDelimiter(String sample) {
    final (stripped, sepDelim) = checkSepHint(stripBom(sample).$1);
    if (sepDelim != null) return sepDelim;

    final lines = _sampleLines(stripped);
    if (lines.isEmpty) return ',';

    var bestCandidate = ',';
    var bestUniform = false;
    var bestMinCount = 0;

    for (final candidate in _candidates) {
      var minCount = -1;
      var maxCount = 0;
      var qualifies = true;

      for (final line in lines) {
        final count = _countOutsideQuotes(line, candidate);
        if (count == 0) {
          qualifies = false;
          break;
        }
        if (minCount < 0 || count < minCount) minCount = count;
        if (count > maxCount) maxCount = count;
      }

      if (!qualifies) continue;
      final uniform = minCount == maxCount;

      final better = bestMinCount == 0 ||
          (uniform && !bestUniform) ||
          (uniform == bestUniform && minCount > bestMinCount);
      if (better) {
        bestCandidate = candidate;
        bestUniform = uniform;
        bestMinCount = minCount;
      }
    }

    return bestCandidate;
  }

  /// Strip UTF-8 BOM if present. Returns (stripped string, had BOM).
  (String, bool) stripBom(String input) {
    if (input.isNotEmpty && input.codeUnitAt(0) == _bom) {
      return (input.substring(1), true);
    }
    return (input, false);
  }

  /// Check for Excel `sep=X` hint on first line.
  /// Returns (remaining string, detected delimiter or null).
  (String, String?) checkSepHint(String input) {
    if (input.length < 5) return (input, null);

    // Look for sep=X followed by newline
    if (input.startsWith('sep=')) {
      final newlineIdx = input.indexOf('\n');
      final crIdx = input.indexOf('\r');
      final endIdx =
          crIdx >= 0 && crIdx < (newlineIdx < 0 ? input.length : newlineIdx)
              ? crIdx
              : newlineIdx;

      if (endIdx > 4) {
        final delimiter = input.substring(4, endIdx);
        var remaining = input.substring(endIdx);
        // Skip the newline(s)
        if (remaining.startsWith('\r\n')) {
          remaining = remaining.substring(2);
        } else if (remaining.startsWith('\r') || remaining.startsWith('\n')) {
          remaining = remaining.substring(1);
        }
        return (remaining, delimiter);
      }
    }
    return (input, null);
  }

  List<String> _sampleLines(String input) {
    final lines = <String>[];
    var start = 0;
    var inQuotes = false;

    for (var i = 0; i < input.length && lines.length < _maxSampleLines; i++) {
      final ch = input.codeUnitAt(i);
      if (ch == 34) {
        // "
        inQuotes = !inQuotes;
      } else if (!inQuotes && (ch == 10 || ch == 13)) {
        // \n or \r
        if (i > start) lines.add(input.substring(start, i));
        if (ch == 13 && i + 1 < input.length && input.codeUnitAt(i + 1) == 10) {
          i++;
        }
        start = i + 1;
      }
    }

    if (start < input.length && lines.length < _maxSampleLines) {
      lines.add(input.substring(start));
    }

    return lines;
  }

  static int _countOutsideQuotes(String line, String delimiter) {
    var count = 0;
    var inQuotes = false;
    final delimLen = delimiter.length;

    for (var i = 0; i < line.length; i++) {
      if (line.codeUnitAt(i) == 34) {
        // "
        inQuotes = !inQuotes;
      } else if (!inQuotes) {
        if (delimLen == 1) {
          if (line.codeUnitAt(i) == delimiter.codeUnitAt(0)) count++;
        } else if (i + delimLen <= line.length &&
            line.substring(i, i + delimLen) == delimiter) {
          count++;
          i += delimLen - 1;
        }
      }
    }

    return count;
  }
}
