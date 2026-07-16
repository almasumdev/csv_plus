import '../core/csv_config.dart';
import '../core/csv_exception.dart';
import 'fast_decoder.dart';

// ASCII constants for byte-level comparison
const _lf = 10;
const _cr = 13;
const _bom = 0xFEFF;

/// Flexible and typed decode operations for [FastDecoder].
extension FastDecoderFlexible on FastDecoder {
  /// Decode with lenient parsing: unquoted strings, whitespace trimming.
  ///
  /// Like [FastDecoder.decode] but trims leading/trailing whitespace from
  /// unquoted fields and treats an unmatched quote as a literal character.
  /// [CsvConfig.strict] and [CsvConfig.decoderTransform] are ignored:
  /// this path never throws on malformed quoting.
  List<List<dynamic>> decodeFlexible(String input, CsvConfig config) {
    if (input.isEmpty) return [];

    final bytes = input.codeUnits;
    final len = bytes.length;
    final delimBytes = config.fieldDelimiter.codeUnits;
    final delimLen = delimBytes.length;
    final firstDelim = delimBytes[0];
    final singleCharDelim = delimLen == 1;
    final quoteCode = config.quoteCharacter.codeUnitAt(0);
    final escapeCode = config.escapeCharacter.codeUnitAt(0);
    final skipEmpty = config.skipEmptyLines;
    final dynamicTyping = config.dynamicTyping;
    final hasHeader = config.hasHeader;
    final hasComment = config.comment != null && config.comment!.isNotEmpty;
    final commentCode = hasComment ? config.comment!.codeUnitAt(0) : -1;
    final skipRows = config.skipRows;
    final maxRows = config.maxRows;

    final rows = <List<dynamic>>[];
    var headerDone = false;
    var cursor = 0;
    var skipped = 0;
    var dataCount = 0;

    if (len > 0 && bytes[0] == _bom) cursor = 1;

    while (cursor < len) {
      // Comment line: drop the whole physical line before parsing it.
      if (hasComment && bytes[cursor] == commentCode) {
        cursor++;
        while (cursor < len && bytes[cursor] != _lf && bytes[cursor] != _cr) {
          cursor++;
        }
        if (cursor < len) {
          final term = bytes[cursor];
          cursor++;
          if (term == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
        }
        continue;
      }

      // Zero-length line: skipped under skipEmptyLines, otherwise the cell
      // loop below reads it as one empty field.
      if (bytes[cursor] == _cr || bytes[cursor] == _lf) {
        if (skipEmpty) {
          final ch = bytes[cursor];
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          continue;
        }
      }

      final currentRow = <dynamic>[];

      while (true) {
        if (cursor >= len) {
          currentRow.add(dynamicTyping ? null : '');
          break;
        }

        final ch = bytes[cursor];

        if (ch == _cr || ch == _lf) {
          currentRow.add(dynamicTyping ? null : '');
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }

        if (ch == quoteCode) {
          // Quoted field: try to parse normally
          cursor++;
          final buf = StringBuffer();
          var closed = false;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              buf.writeCharCode(quoteCode);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              closed = true;
              break;
            } else {
              buf.writeCharCode(c);
              cursor++;
            }
          }
          var value = buf.toString();
          if (!closed) {
            // Unmatched quote: treat the quote character as literal
            value = '${config.quoteCharacter}$value';
          } else if (cursor < len) {
            // Text after the closing quote up to the next boundary is
            // appended (same rule as the standard decoders).
            final after = bytes[cursor];
            final atBoundary =
                after == _cr ||
                after == _lf ||
                FastDecoder.isDelimiterAt(
                  bytes,
                  cursor,
                  singleCharDelim,
                  firstDelim,
                  delimBytes,
                  delimLen,
                  len,
                );
            if (!atBoundary) {
              final junkStart = cursor;
              while (cursor < len) {
                final c = bytes[cursor];
                if (c == _cr || c == _lf) break;
                if (FastDecoder.isDelimiterAt(
                  bytes,
                  cursor,
                  singleCharDelim,
                  firstDelim,
                  delimBytes,
                  delimLen,
                  len,
                )) {
                  break;
                }
                cursor++;
              }
              value = value + input.substring(junkStart, cursor);
            }
          }
          currentRow.add(value);
        } else if (FastDecoder.isDelimiterAt(
          bytes,
          cursor,
          singleCharDelim,
          firstDelim,
          delimBytes,
          delimLen,
          len,
        )) {
          currentRow.add(dynamicTyping ? null : '');
        } else {
          // Unquoted field: read and trim whitespace
          final start = cursor;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == _cr || c == _lf) break;
            if (FastDecoder.isDelimiterAt(
              bytes,
              cursor,
              singleCharDelim,
              firstDelim,
              delimBytes,
              delimLen,
              len,
            )) {
              break;
            }
            cursor++;
          }
          final value = input.substring(start, cursor).trim();
          if (dynamicTyping) {
            currentRow.add(FastDecoder.inferType(value));
          } else {
            currentRow.add(value);
          }
        }

        // Consume separator
        if (cursor >= len) break;
        final next = bytes[cursor];
        if (next == _cr || next == _lf) {
          cursor++;
          if (next == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }
        if (singleCharDelim && next == firstDelim) {
          cursor++;
        } else if (!singleCharDelim &&
            FastDecoder.matchDelimiter(
              bytes,
              cursor,
              delimBytes,
              delimLen,
              len,
            )) {
          cursor += delimLen;
        }
      }

      // A row of a single empty field is an empty line per RFC 4180.
      if (skipEmpty && currentRow.length == 1) {
        final only = currentRow[0];
        if (only == null || only == '') continue;
      }

      // Skip leading rows (a preamble) before the header row is read.
      if (skipped < skipRows) {
        skipped++;
        continue;
      }

      if (hasHeader && !headerDone) {
        headerDone = true;
        continue;
      }

      // Stop once the data-row limit is reached.
      if (maxRows != null && dataCount >= maxRows) break;

      rows.add(currentRow);
      dataCount++;
    }

    return rows;
  }

  /// Decode all fields as integers.
  ///
  /// Throws [CsvParseException] (with row and column) for any field that
  /// is not a valid integer. Empty fields throw too, unless [emptyAs]
  /// provides an explicit fill value.
  List<List<int>> decodeIntegers(
    String input,
    CsvConfig config, {
    int? emptyAs,
  }) {
    final stringRows = decodeStrings(input, config);
    final result = <List<int>>[];
    for (var r = 0; r < stringRows.length; r++) {
      final row = stringRows[r];
      final out = <int>[];
      for (var c = 0; c < row.length; c++) {
        final s = row[c];
        if (s.isEmpty) {
          if (emptyAs == null) {
            throw CsvParseException(
              'Empty field is not a valid integer '
              '(pass emptyAs to fill empty fields)',
              row: r,
              column: c,
            );
          }
          out.add(emptyAs);
        } else {
          final v = int.tryParse(s);
          if (v == null) {
            throw CsvParseException(
              'Field "$s" is not a valid integer',
              row: r,
              column: c,
            );
          }
          out.add(v);
        }
      }
      result.add(out);
    }
    return result;
  }

  /// Decode all fields as doubles.
  ///
  /// Throws [CsvParseException] (with row and column) for any field that
  /// is not a valid double. Empty fields throw too, unless [emptyAs]
  /// provides an explicit fill value.
  List<List<double>> decodeDoubles(
    String input,
    CsvConfig config, {
    double? emptyAs,
  }) {
    final stringRows = decodeStrings(input, config);
    final result = <List<double>>[];
    for (var r = 0; r < stringRows.length; r++) {
      final row = stringRows[r];
      final out = <double>[];
      for (var c = 0; c < row.length; c++) {
        final s = row[c];
        if (s.isEmpty) {
          if (emptyAs == null) {
            throw CsvParseException(
              'Empty field is not a valid double '
              '(pass emptyAs to fill empty fields)',
              row: r,
              column: c,
            );
          }
          out.add(emptyAs);
        } else {
          final v = double.tryParse(s);
          if (v == null) {
            throw CsvParseException(
              'Field "$s" is not a valid double',
              row: r,
              column: c,
            );
          }
          out.add(v);
        }
      }
      result.add(out);
    }
    return result;
  }

  /// Decode all fields as booleans.
  ///
  /// Truth table (case-insensitive): `true` and `1` read as `true`;
  /// `false` and `0` read as `false`. Anything else throws
  /// [CsvParseException]. Empty fields throw too, unless [emptyAs]
  /// provides an explicit fill value.
  List<List<bool>> decodeBooleans(
    String input,
    CsvConfig config, {
    bool? emptyAs,
  }) {
    final stringRows = decodeStrings(input, config);
    final result = <List<bool>>[];
    for (var r = 0; r < stringRows.length; r++) {
      final row = stringRows[r];
      final out = <bool>[];
      for (var c = 0; c < row.length; c++) {
        final s = row[c];
        if (s.isEmpty) {
          if (emptyAs == null) {
            throw CsvParseException(
              'Empty field is not a valid boolean '
              '(pass emptyAs to fill empty fields)',
              row: r,
              column: c,
            );
          }
          out.add(emptyAs);
          continue;
        }
        switch (s.toLowerCase()) {
          case 'true' || '1':
            out.add(true);
          case 'false' || '0':
            out.add(false);
          default:
            throw CsvParseException(
              'Field "$s" is not a valid boolean '
              '(expected true/false/1/0)',
              row: r,
              column: c,
            );
        }
      }
      result.add(out);
    }
    return result;
  }
}
