import '../core/csv_config.dart';
import '../core/csv_exception.dart';

// ASCII constants for hot-loop byte comparison
const _lf = 10; // \n
const _cr = 13; // \r
const _dot = 46; // .
const _minus = 45; // -
const _zero = 48; // 0
const _nine = 57; // 9
const _lowerE = 101; // e
const _upperE = 69; // E
const _lowerF = 102; // f
const _lowerT = 116; // t
const _plus = 43; // +
const _bom = 0xFEFF;

// 'true' / 'false' byte sequences
const _lowerR = 114;
const _lowerU = 117;
const _lowerA = 97;
const _lowerL = 108;
const _lowerS = 115;

/// High-performance batch CSV decoder using byte-level (`codeUnits`) parsing.
///
/// Techniques:
/// - Direct codeUnit array indexing (no string ops in hot loop)
/// - Labeled loop control flow (`outerLoop`, `cell_loop`)
/// - Type inference by first-byte detection
/// - substring + replaceRange for quoted fields (avoids StringBuffer)
/// - Row pre-sizing after first row for fewer allocations
///
/// ## Parsing semantics
///
/// All csv_plus decoders (this batch decoder, [decodeStrings], and the
/// streaming `CsvDecoder`) implement one shared semantics:
///
/// - An empty line reads as a row with one empty field, per RFC 4180.
///   With [CsvConfig.skipEmptyLines] (the default), rows consisting of a
///   single empty field are dropped; rows of several empty fields (`,,`)
///   are always kept.
/// - Text after a closing quote is appended to the field, so `"a"x` reads
///   `ax` (Excel behavior). With [CsvConfig.strict] it throws instead.
/// - An unterminated quote consumes the rest of the input as field content
///   (throws under [CsvConfig.strict]).
/// - With [CsvConfig.hasHeader], the first surviving row is the header row.
///   Header cells are read as raw strings: no type inference, no
///   [CsvConfig.decoderTransform].
/// - Quoted fields are never type-inferred; quoting opts a value out of
///   [CsvConfig.dynamicTyping].
class FastDecoder {
  /// Create a batch decoder instance (stateless, reusable).
  const FastDecoder();

  /// Decode CSV string with automatic type inference.
  ///
  /// When [CsvConfig.hasHeader] is set, the header row is consumed (its
  /// names feed [CsvConfig.decoderTransform]) and only data rows are
  /// returned. Use [decodeWithHeaders] to also get the header names.
  List<List<dynamic>> decode(String input, CsvConfig config) {
    return _decodeTyped(input, config, null);
  }

  /// Decode CSV string, returning the header row and typed data rows in a
  /// single pass.
  ///
  /// The first surviving row is always treated as the header row (as if
  /// [CsvConfig.hasHeader] were set) and is returned as raw strings.
  ({List<String> headers, List<List<dynamic>> rows}) decodeWithHeaders(
    String input,
    CsvConfig config,
  ) {
    final headers = <String>[];
    final rows = _decodeTyped(
      input,
      config.hasHeader ? config : config.copyWith(hasHeader: true),
      headers,
    );
    return (headers: headers, rows: rows);
  }

  List<List<dynamic>> _decodeTyped(
    String input,
    CsvConfig config,
    List<String>? headerSink,
  ) {
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
    final transform = config.decoderTransform;
    final hasHeader = config.hasHeader;
    final strict = config.strict;
    final hasComment = config.comment != null && config.comment!.isNotEmpty;
    final commentCode = hasComment ? config.comment!.codeUnitAt(0) : -1;
    final skipRows = config.skipRows;
    final maxRows = config.maxRows;

    final rows = <List<dynamic>>[];
    List<String>? headers;
    var headerDone = false;
    var cursor = 0;
    var colCount = -1;
    var rowIndex = 0;
    var skipped = 0;
    var dataCount = 0;

    // Strip BOM
    if (len > 0 && bytes[0] == _bom) cursor = 1;

    outerLoop:
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
        rowIndex++;
        continue outerLoop;
      }

      // Fast path: zero-length line skipped under skipEmptyLines. When not
      // skipping, fall through so the cell loop reads it as one empty field.
      final rowCh = bytes[cursor];
      if (rowCh <= _cr && (rowCh == _cr || rowCh == _lf)) {
        if (skipEmpty) {
          cursor++;
          if (rowCh == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          rowIndex++;
          continue outerLoop;
        }
      }

      final isHeaderRow = hasHeader && !headerDone;
      final rowTyping = dynamicTyping && !isHeaderRow;
      final rowTransform = isHeaderRow ? null : transform;
      final hasTransform = rowTransform != null;

      final currentRow = colCount > 0
          ? List<dynamic>.generate(colCount, (_) => null, growable: true)
          : <dynamic>[];
      var cellIdx = 0;

      // Read cells in this row
      while (true) {
        if (cursor >= len) {
          _addCell(currentRow, cellIdx, colCount, rowTyping ? null : '');
          cellIdx++;
          break;
        }

        final ch = bytes[cursor];

        if (ch <= _cr && (ch == _cr || ch == _lf)) {
          _addCell(currentRow, cellIdx, colCount, rowTyping ? null : '');
          cellIdx++;
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }

        if (ch == quoteCode) {
          // --- Quoted string: substring approach ---
          cursor++;
          final start = cursor;
          List<int>? escapePositions;
          var closed = false;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              (escapePositions ??= []).add(cursor - start);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              closed = true;
              break;
            } else {
              cursor++;
            }
          }
          if (!closed && strict) {
            throw CsvParseException(
              'Unterminated quoted field',
              row: rowIndex,
              column: cellIdx,
              offset: start - 1,
            );
          }
          String value = input.substring(start, closed ? cursor - 1 : cursor);
          if (escapePositions != null) {
            for (var i = escapePositions.length - 1; i >= 0; i--) {
              value = value.replaceRange(
                escapePositions[i],
                escapePositions[i] + 1,
                '',
              );
            }
          }
          // Text after the closing quote up to the next boundary is
          // appended to the field (Excel behavior); strict mode throws.
          if (closed && cursor < len) {
            final after = bytes[cursor];
            final atBoundary =
                (after <= _cr && (after == _cr || after == _lf)) ||
                (singleCharDelim
                    ? after == firstDelim
                    : _matchDelim(bytes, cursor, delimBytes, delimLen, len));
            if (!atBoundary) {
              if (strict) {
                throw CsvParseException(
                  'Unexpected character after closing quote',
                  row: rowIndex,
                  column: cellIdx,
                  offset: cursor,
                );
              }
              final junkStart = cursor;
              while (cursor < len) {
                final c = bytes[cursor];
                if (c == firstDelim) {
                  if (singleCharDelim ||
                      _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                    break;
                  }
                } else if (c <= _cr && (c == _lf || c == _cr)) {
                  break;
                }
                cursor++;
              }
              value = value + input.substring(junkStart, cursor);
            }
          }
          dynamic cell = value;
          if (hasTransform) {
            final hdr = (headers != null && cellIdx < headers.length)
                ? headers[cellIdx]
                : null;
            cell = rowTransform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        } else if (singleCharDelim
            ? ch == firstDelim
            : _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
          // --- Empty field (consecutive delimiter) ---
          dynamic cell = rowTyping ? null : '';
          if (hasTransform) {
            final hdr = (headers != null && cellIdx < headers.length)
                ? headers[cellIdx]
                : null;
            cell = rowTransform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        } else if (rowTyping && (ch == _lowerT || ch == _lowerF)) {
          // --- Try boolean by individual byte check ---
          var matched = false;
          if (ch == _lowerT) {
            if (cursor + 4 <= len &&
                bytes[cursor + 1] == _lowerR &&
                bytes[cursor + 2] == _lowerU &&
                bytes[cursor + 3] == _lowerE) {
              final after = cursor + 4;
              if (after >= len ||
                  bytes[after] == _cr ||
                  bytes[after] == _lf ||
                  (singleCharDelim
                      ? bytes[after] == firstDelim
                      : _matchDelim(bytes, after, delimBytes, delimLen, len))) {
                dynamic cell = true;
                cursor += 4;
                if (hasTransform) {
                  final hdr = (headers != null && cellIdx < headers.length)
                      ? headers[cellIdx]
                      : null;
                  cell = rowTransform(cell, cellIdx, hdr);
                }
                _addCell(currentRow, cellIdx, colCount, cell);
                cellIdx++;
                matched = true;
              }
            }
          } else {
            if (cursor + 5 <= len &&
                bytes[cursor + 1] == _lowerA &&
                bytes[cursor + 2] == _lowerL &&
                bytes[cursor + 3] == _lowerS &&
                bytes[cursor + 4] == _lowerE) {
              final after = cursor + 5;
              if (after >= len ||
                  bytes[after] == _cr ||
                  bytes[after] == _lf ||
                  (singleCharDelim
                      ? bytes[after] == firstDelim
                      : _matchDelim(bytes, after, delimBytes, delimLen, len))) {
                dynamic cell = false;
                cursor += 5;
                if (hasTransform) {
                  final hdr = (headers != null && cellIdx < headers.length)
                      ? headers[cellIdx]
                      : null;
                  cell = rowTransform(cell, cellIdx, hdr);
                }
                _addCell(currentRow, cellIdx, colCount, cell);
                cellIdx++;
                matched = true;
              }
            }
          }
          if (!matched) {
            // Fall through to unquoted string
            final start = cursor;
            cursor++;
            while (cursor < len) {
              final c = bytes[cursor];
              if (c == firstDelim) {
                if (singleCharDelim ||
                    _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                  break;
                }
              } else if (c <= _cr && (c == _lf || c == _cr)) {
                break;
              }
              cursor++;
            }
            dynamic cell = input.substring(start, cursor);
            if (hasTransform) {
              final hdr = (headers != null && cellIdx < headers.length)
                  ? headers[cellIdx]
                  : null;
              cell = rowTransform(cell, cellIdx, hdr);
            }
            _addCell(currentRow, cellIdx, colCount, cell);
            cellIdx++;
          }
        } else if (rowTyping &&
            (ch == _minus || (ch >= _zero && ch <= _nine))) {
          // --- Number (int or double) ---
          final start = cursor;
          // Data-loss guard: a multi-digit run starting with 0 stays text
          // (007 is an identifier, not the number 7).
          final digitIdx = ch == _minus ? cursor + 1 : cursor;
          final zeroLed =
              digitIdx + 1 < len &&
              bytes[digitIdx] == _zero &&
              bytes[digitIdx + 1] >= _zero &&
              bytes[digitIdx + 1] <= _nine;
          var isDouble = false;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c >= _zero && c <= _nine) {
              cursor++;
            } else if (c == _dot || c == _lowerE || c == _upperE) {
              isDouble = true;
              cursor++;
            } else if (c == _plus || c == _minus) {
              cursor++;
            } else {
              break;
            }
          }

          // Verify the field ends at a boundary (delimiter/CR/LF/EOF)
          final atBoundary =
              cursor >= len ||
              (bytes[cursor] <= _cr &&
                  (bytes[cursor] == _cr || bytes[cursor] == _lf)) ||
              (singleCharDelim
                  ? bytes[cursor] == firstDelim
                  : _matchDelim(bytes, cursor, delimBytes, delimLen, len));

          dynamic cell;
          if (atBoundary && !zeroLed) {
            final numStr = input.substring(start, cursor);
            if (isDouble) {
              // Non-finite results (1e999) would corrupt the value.
              final d = double.tryParse(numStr);
              cell = (d != null && d.isFinite) ? d : numStr;
            } else if (cursor - start - (ch == _minus ? 1 : 0) > 15) {
              // Data-loss guard: past 15 digits, web (and Excel) precision
              // is not exact, so long digit runs stay text everywhere.
              // Mid-string signs can overcount the length, but those
              // strings fail int.tryParse and stay text regardless.
              cell = numStr;
            } else {
              cell = int.tryParse(numStr) ?? numStr;
            }
          } else {
            // Not a clean number: rescan to the boundary as a string
            while (cursor < len) {
              final c = bytes[cursor];
              if (c == firstDelim) {
                if (singleCharDelim ||
                    _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                  break;
                }
              } else if (c <= _cr && (c == _lf || c == _cr)) {
                break;
              }
              cursor++;
            }
            cell = input.substring(start, cursor);
          }
          if (hasTransform) {
            final hdr = (headers != null && cellIdx < headers.length)
                ? headers[cellIdx]
                : null;
            cell = rowTransform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        } else {
          // --- Unquoted string ---
          final start = cursor;
          cursor++;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == firstDelim) {
              if (singleCharDelim ||
                  _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                break;
              }
            } else if (c <= _cr && (c == _lf || c == _cr)) {
              break;
            }
            cursor++;
          }
          dynamic cell = input.substring(start, cursor);
          if (hasTransform) {
            final hdr = (headers != null && cellIdx < headers.length)
                ? headers[cellIdx]
                : null;
            cell = rowTransform(cell, cellIdx, hdr);
          }
          _addCell(currentRow, cellIdx, colCount, cell);
          cellIdx++;
        }

        // --- After cell: consume separator or end row ---
        if (cursor >= len) break;
        final next = bytes[cursor];
        if (next <= _cr && (next == _cr || next == _lf)) {
          cursor++;
          if (next == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }
        if (singleCharDelim && next == firstDelim) {
          cursor++;
        } else if (!singleCharDelim &&
            _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
          cursor += delimLen;
        }
      }

      rowIndex++;

      // Trim pre-sized row if fewer cells than expected
      final row = (colCount > 0 && cellIdx < colCount)
          ? currentRow.sublist(0, cellIdx)
          : currentRow;

      // A row of a single empty field is an empty line per RFC 4180.
      if (skipEmpty && cellIdx == 1) {
        final only = row[0];
        if (only == null || only == '') continue;
      }

      // Skip leading rows (a preamble) before the header row is read.
      if (skipped < skipRows) {
        skipped++;
        continue;
      }

      if (isHeaderRow) {
        headers = List<String>.generate(row.length, (i) => row[i] as String);
        headerDone = true;
        colCount = headers.length;
        headerSink?.addAll(headers);
        continue;
      }

      // Stop once the data-row limit is reached.
      if (maxRows != null && dataCount >= maxRows) break outerLoop;

      if (colCount < 0) colCount = cellIdx;
      rows.add(row);
      dataCount++;
    }

    return rows;
  }

  /// Decode all fields as strings (no type inference overhead).
  ///
  /// Follows the same structural semantics as [decode] (empty lines,
  /// quote handling, [CsvConfig.skipEmptyLines], [CsvConfig.hasHeader],
  /// [CsvConfig.strict]); it only skips typing and
  /// [CsvConfig.decoderTransform].
  List<List<String>> decodeStrings(String input, CsvConfig config) {
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
    final hasHeader = config.hasHeader;
    final strict = config.strict;
    final hasComment = config.comment != null && config.comment!.isNotEmpty;
    final commentCode = hasComment ? config.comment!.codeUnitAt(0) : -1;
    final skipRows = config.skipRows;
    final maxRows = config.maxRows;

    final rows = <List<String>>[];
    var headerDone = false;
    var cursor = 0;
    var colCount = -1;
    var rowIndex = 0;
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
        rowIndex++;
        continue;
      }

      // Fast path: zero-length line skipped under skipEmptyLines. When not
      // skipping, fall through so the cell loop reads it as one empty field.
      final rowCh = bytes[cursor];
      if (rowCh <= _cr && (rowCh == _cr || rowCh == _lf)) {
        if (skipEmpty) {
          cursor++;
          if (rowCh == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          rowIndex++;
          continue;
        }
      }

      final currentRow = colCount > 0
          ? List<String>.generate(colCount, (_) => '', growable: true)
          : <String>[];
      var cellIdx = 0;

      while (true) {
        if (cursor >= len) {
          _addStr(currentRow, cellIdx, colCount, '');
          cellIdx++;
          break;
        }

        final ch = bytes[cursor];

        if (ch <= _cr && (ch == _cr || ch == _lf)) {
          _addStr(currentRow, cellIdx, colCount, '');
          cellIdx++;
          cursor++;
          if (ch == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }

        if (ch == quoteCode) {
          // --- Quoted field ---
          cursor++;
          final start = cursor;
          List<int>? escapePositions;
          var closed = false;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == escapeCode &&
                cursor + 1 < len &&
                bytes[cursor + 1] == quoteCode) {
              (escapePositions ??= []).add(cursor - start);
              cursor += 2;
            } else if (c == quoteCode) {
              cursor++;
              closed = true;
              break;
            } else {
              cursor++;
            }
          }
          if (!closed && strict) {
            throw CsvParseException(
              'Unterminated quoted field',
              row: rowIndex,
              column: cellIdx,
              offset: start - 1,
            );
          }
          String value = input.substring(start, closed ? cursor - 1 : cursor);
          if (escapePositions != null) {
            for (var i = escapePositions.length - 1; i >= 0; i--) {
              value = value.replaceRange(
                escapePositions[i],
                escapePositions[i] + 1,
                '',
              );
            }
          }
          // Text after the closing quote up to the next boundary is
          // appended to the field (Excel behavior); strict mode throws.
          if (closed && cursor < len) {
            final after = bytes[cursor];
            final atBoundary =
                (after <= _cr && (after == _cr || after == _lf)) ||
                (singleCharDelim
                    ? after == firstDelim
                    : _matchDelim(bytes, cursor, delimBytes, delimLen, len));
            if (!atBoundary) {
              if (strict) {
                throw CsvParseException(
                  'Unexpected character after closing quote',
                  row: rowIndex,
                  column: cellIdx,
                  offset: cursor,
                );
              }
              final junkStart = cursor;
              while (cursor < len) {
                final c = bytes[cursor];
                if (c == firstDelim) {
                  if (singleCharDelim ||
                      _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                    break;
                  }
                } else if (c <= _cr && (c == _lf || c == _cr)) {
                  break;
                }
                cursor++;
              }
              value = value + input.substring(junkStart, cursor);
            }
          }
          _addStr(currentRow, cellIdx, colCount, value);
          cellIdx++;
        } else {
          // --- Unquoted field ---
          final start = cursor;
          while (cursor < len) {
            final c = bytes[cursor];
            if (c == firstDelim) {
              if (singleCharDelim ||
                  _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
                break;
              }
            } else if (c <= _cr && (c == _lf || c == _cr)) {
              break;
            }
            cursor++;
          }
          final value = input.substring(start, cursor);
          _addStr(currentRow, cellIdx, colCount, value);
          cellIdx++;
        }

        // After cell: consume delimiter or end row
        if (cursor >= len) break;
        final next = bytes[cursor];
        if (next <= _cr && (next == _cr || next == _lf)) {
          cursor++;
          if (next == _cr && cursor < len && bytes[cursor] == _lf) cursor++;
          break;
        }
        if (singleCharDelim && next == firstDelim) {
          cursor++;
        } else if (!singleCharDelim &&
            _matchDelim(bytes, cursor, delimBytes, delimLen, len)) {
          cursor += delimLen;
        }
      }

      rowIndex++;

      final row = (colCount > 0 && cellIdx < colCount)
          ? currentRow.sublist(0, cellIdx)
          : currentRow;

      // A row of a single empty field is an empty line per RFC 4180.
      if (skipEmpty && cellIdx == 1 && row[0].isEmpty) continue;

      // Skip leading rows (a preamble) before the header row is read.
      if (skipped < skipRows) {
        skipped++;
        continue;
      }

      if (hasHeader && !headerDone) {
        headerDone = true;
        colCount = row.length;
        continue;
      }

      // Stop once the data-row limit is reached.
      if (maxRows != null && dataCount >= maxRows) break;

      if (colCount < 0) colCount = cellIdx;
      rows.add(row);
      dataCount++;
    }

    return rows;
  }

  // --- Helpers (static for inlining) ---

  static bool _matchDelim(
    List<int> bytes,
    int pos,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) {
    if (pos + delimLen > totalLen) return false;
    for (var i = 0; i < delimLen; i++) {
      if (bytes[pos + i] != delimBytes[i]) return false;
    }
    return true;
  }

  /// Check if bytes match multi-char delimiter at position.
  static bool matchDelimiter(
    List<int> bytes,
    int pos,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) => _matchDelim(bytes, pos, delimBytes, delimLen, totalLen);

  /// Check if current position is a field delimiter.
  static bool isDelimiterAt(
    List<int> bytes,
    int pos,
    bool singleCharDelim,
    int firstDelim,
    List<int> delimBytes,
    int delimLen,
    int totalLen,
  ) {
    if (singleCharDelim) return bytes[pos] == firstDelim;
    return bytes[pos] == firstDelim &&
        _matchDelim(bytes, pos, delimBytes, delimLen, totalLen);
  }

  /// Infer a dynamic type from a string value.
  ///
  /// This is the shared inference used by every typed decode path. Rules:
  ///
  /// - `''` reads as `null`; `true`/`false` (lowercase only) read as bool.
  /// - Integers and doubles (including scientific notation) are parsed.
  /// - Data-loss guards keep identifier-like values as text: leading zeros
  ///   (`007`), a leading plus sign (`+1`), surrounding whitespace, digit
  ///   runs longer than 15 (exact on VM but not on the web), and values
  ///   that would parse to a non-finite double (`1e999`).
  static dynamic inferType(String value) {
    if (value.isEmpty) return null;
    if (value == 'true') return true;
    if (value == 'false') return false;

    final bytes = value.codeUnits;
    final len = bytes.length;
    final first = bytes[0];
    if (first != _minus && (first < _zero || first > _nine)) return value;

    var hasDot = false;
    var hasExp = false;
    var digits = 0;
    for (var i = 0; i < len; i++) {
      final c = bytes[i];
      if (c >= _zero && c <= _nine) {
        digits++;
      } else if (c == _dot) {
        hasDot = true;
      } else if (c == _lowerE || c == _upperE) {
        if (i == 0) return value;
        hasExp = true;
      } else if (c == _plus || c == _minus) {
        // Sign characters are validated by the final parse.
      } else {
        return value;
      }
    }

    // Data-loss guard: a multi-digit run starting with 0 stays text.
    final digitIdx = first == _minus ? 1 : 0;
    if (digitIdx + 1 < len &&
        bytes[digitIdx] == _zero &&
        bytes[digitIdx + 1] >= _zero &&
        bytes[digitIdx + 1] <= _nine) {
      return value;
    }

    if (hasDot || hasExp) {
      final d = double.tryParse(value);
      return (d != null && d.isFinite) ? d : value;
    }
    if (digits > 15) return value;
    return int.tryParse(value) ?? value;
  }

  // Add cell to pre-sized or growing row
  static void _addCell(
    List<dynamic> row,
    int idx,
    int colCount,
    dynamic value,
  ) {
    if (colCount > 0 && idx < colCount) {
      row[idx] = value;
    } else {
      row.add(value);
    }
  }

  static void _addStr(List<String> row, int idx, int colCount, String value) {
    if (colCount > 0 && idx < colCount) {
      row[idx] = value;
    } else {
      row.add(value);
    }
  }
}
