import '../core/date_order.dart';
import 'dart:async';
import 'dart:convert';

import '../core/csv_config.dart';
import '../core/csv_exception.dart';
import 'auto_detect.dart';
import 'fast_decoder.dart';

/// Streaming CSV decoder using a chunked state machine.
///
/// Handles chunk boundaries that split mid-field, mid-escape, mid-CRLF,
/// or mid-delimiter (multi-character delimiters included). Use for
/// memory-efficient processing of large inputs.
///
/// Produces exactly the same rows as [FastDecoder.decode] for the same
/// input and [CsvConfig]; the two are held together by a conformance
/// test suite.
///
/// Streaming matches `CsvCodec.decode` too: when [CsvConfig.autoDetect] is on
/// and the delimiter is the default `,`, the decoder holds back the first ten
/// non-empty lines, detects the delimiter (or reads an Excel `sep=` line, which
/// is dropped) and then streams the rest with constant memory. If those lines
/// never complete, for example after a stray opening quote, it decides on what
/// it has once 1,000,000 code units are buffered. Set `autoDetect: false` or an
/// explicit delimiter to skip the hold-back.
///
/// [bind] honors downstream backpressure: when the listener pauses, the
/// upstream subscription is paused, so a slow consumer does not buffer
/// the whole input in memory.
class CsvDecoder extends StreamTransformerBase<String, List<dynamic>> {
  /// Configuration for this decoder.
  final CsvConfig config;

  /// Create a streaming decoder with the given [config].
  const CsvDecoder([this.config = const CsvConfig()]);

  /// Batch: decode complete CSV string to rows.
  List<List<dynamic>> convert(String input) {
    final rows = <List<dynamic>>[];
    final machine = _newParser(config, rows.add);
    machine.addChunk(input);
    machine.finish();
    return rows;
  }

  @override
  Stream<List<dynamic>> bind(Stream<String> stream) {
    StreamSubscription<String>? subscription;
    late final StreamController<List<dynamic>> controller;
    controller = StreamController<List<dynamic>>(
      onListen: () {
        final machine = _newParser(config, controller.add);
        subscription = stream.listen(
          (chunk) {
            try {
              machine.addChunk(chunk);
            } catch (error, stackTrace) {
              controller.addError(error, stackTrace);
              subscription?.cancel();
              controller.close();
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            // Rows read before the failure still come out ahead of the error.
            try {
              machine.flushHeld();
            } catch (heldError, heldStackTrace) {
              controller.addError(heldError, heldStackTrace);
            }
            controller.addError(error, stackTrace);
            controller.close();
          },
          onDone: () {
            try {
              machine.finish();
            } catch (error, stackTrace) {
              controller.addError(error, stackTrace);
            }
            controller.close();
          },
          cancelOnError: true,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Decode a UTF-8 byte stream directly (file reads, HTTP bodies),
  /// without wiring `utf8.decoder` by hand.
  Stream<List<dynamic>> bindBytes(Stream<List<int>> stream) =>
      bind(utf8.decoder.bind(stream));

  /// Chunked conversion sink for `dart:convert` pipeline compatibility.
  Sink<String> startChunkedConversion(Sink<List<dynamic>> sink) {
    return _CsvDecoderSink(config, sink);
  }
}

enum _State {
  fieldStart,
  unquotedField,
  quotedField,
  afterQuote,
  quoteJunk,
  comment,
}

/// Something that turns CSV chunks into rows.
abstract interface class _ChunkParser {
  void addChunk(String chunk);

  /// Parses anything held back, without ending the input.
  void flushHeld();
  void finish();
}

/// Builds the parser for [config]: the plain state machine, or one that first
/// resolves the delimiter when the batch decoder would.
_ChunkParser _newParser(CsvConfig config, void Function(List<dynamic>) emit) =>
    needsAutoDetect(config)
    ? _DetectingParser(config, emit)
    : _StateMachine(config, emit);

/// Holds back the start of the input until the delimiter can be decided the
/// same way `CsvCodec.decode` decides it, then hands everything to a
/// [_StateMachine].
///
/// The sample is the first [_sampleLines] non-empty lines, counted as
/// `DelimiterDetector` counts them: a `"` toggles quoting, and a CR or LF
/// outside quotes ends a line. A buffer that ends in a CR waits for one more
/// code unit so a CRLF after a `sep=` line is never split. If the sample never
/// completes, the decision is made once [_maxBuffered] code units are held.
class _DetectingParser implements _ChunkParser {
  static const _sampleLines = 10;
  static const _maxBuffered = 1000000;

  final CsvConfig _config;
  final void Function(List<dynamic> row) _emit;
  final _held = StringBuffer();
  _StateMachine? _machine;

  var _heldLength = 0;
  var _lines = 0;
  var _inQuotes = false;
  var _lineHasContent = false;
  var _endsWithCr = false;

  _DetectingParser(this._config, this._emit);

  @override
  void addChunk(String chunk) {
    final machine = _machine;
    if (machine != null) {
      machine.addChunk(chunk);
      return;
    }
    if (chunk.isEmpty) return;
    _held.write(chunk);
    final codes = chunk.codeUnits;
    final len = codes.length;
    if (_lines < _sampleLines) {
      for (var i = 0; i < len; i++) {
        final ch = codes[i];
        if (_heldLength + i == 0 && ch == 0xFEFF) continue;
        if (ch == 34) {
          _inQuotes = !_inQuotes;
          _lineHasContent = true;
        } else if (!_inQuotes && (ch == 10 || ch == 13)) {
          if (_lineHasContent) _lines++;
          _lineHasContent = false;
          if (_lines >= _sampleLines) break;
        } else {
          _lineHasContent = true;
        }
      }
    }
    _heldLength += len;
    _endsWithCr = codes[len - 1] == 13;

    final sampleReady = _lines >= _sampleLines && !_endsWithCr;
    if (sampleReady || _heldLength >= _maxBuffered) _resolve();
  }

  @override
  void flushHeld() {
    if (_machine == null) _resolve();
  }

  @override
  void finish() {
    flushHeld();
    _machine!.finish();
  }

  void _resolve() {
    final (text, config) = resolveAutoDetect(_held.toString(), _config);
    final machine = _machine = _StateMachine(config, _emit);
    _held.clear();
    machine.addChunk(text);
  }
}

/// Chunked CSV parsing state machine. Preserves state across chunk boundaries.
class _StateMachine implements _ChunkParser {
  final CsvConfig config;
  final void Function(List<dynamic> row) _emit;

  late final int _quoteCode = config.quoteCharacter.codeUnitAt(0);
  late final int _escapeCode = config.escapeCharacter.codeUnitAt(0);
  late final List<int> _delimCodes = config.fieldDelimiter.codeUnits;
  late final bool _singleDelim = _delimCodes.length == 1;
  late final bool _dynamicTyping = config.dynamicTyping;
  late final bool _parseDates = config.parseDates;
  late final CsvDateOrder _dateOrder = config.dateOrder;
  late final Map<String, int> _monthNames = config.monthNames;
  late final bool _trimFields = config.trimFields;
  late final bool _skipEmpty = config.skipEmptyLines;
  late final bool _hasHeader = config.hasHeader;
  late final bool _strict = config.strict;
  late final bool _hasComment =
      config.comment != null && config.comment!.isNotEmpty;
  late final int _commentCode = _hasComment
      ? config.comment!.codeUnitAt(0)
      : -1;
  late final int _skipRows = config.skipRows;
  late final int? _maxRows = config.maxRows;

  _State _state = _State.fieldStart;
  bool _atLineStart = true;
  final _buf = StringBuffer();
  var _currentRow = <dynamic>[];
  var _isQuoted = false;
  var _pendingCr = false;
  var _pendingEscape = false;
  var _bomChecked = false;
  // Number of delimiter code units already matched at a chunk boundary.
  var _pendingDelim = 0;
  var _rowIndex = 0;
  var _skipped = 0;
  var _dataCount = 0;
  List<String>? _headers;

  _StateMachine(this.config, this._emit);

  @override
  void addChunk(String chunk) {
    final codes = chunk.codeUnits;
    final len = codes.length;
    var i = 0;

    if (!_bomChecked) {
      if (len == 0) return;
      _bomChecked = true;
      if (codes[0] == 0xFEFF) i = 1;
    }

    // Resume a delimiter match that was split across the chunk boundary.
    if (_pendingDelim > 0) {
      i = _resumePendingDelim(codes, i, len);
    }

    while (i < len) {
      final ch = codes[i];
      switch (_state) {
        case _State.comment:
          // Consume a comment line to its terminator; emit nothing.
          if (ch == 13) {
            _state = _State.fieldStart;
            _pendingCr = true;
            i++;
          } else if (ch == 10) {
            _state = _State.fieldStart;
            i++;
          } else {
            i++;
          }

        case _State.fieldStart:
          _isQuoted = false;
          if (_pendingCr) {
            _pendingCr = false;
            if (ch == 10) {
              i++;
              continue;
            }
          }
          if (_hasComment &&
              _currentRow.isEmpty &&
              _atLineStart &&
              ch == _commentCode) {
            // Comment marker at the very start of a row: drop the line.
            _state = _State.comment;
            i++;
          } else if (config.skipInitialSpace && ch == 32) {
            // Unquoted leading space (32): drop it and stay in fieldStart, which
            // also means a run spanning a chunk boundary just keeps consuming.
            _atLineStart = false;
            i++;
          } else if (ch == _quoteCode) {
            _isQuoted = true;
            _state = _State.quotedField;
            i++;
          } else if (ch == 13) {
            _emitField();
            _emitRow();
            _pendingCr = true;
            i++;
          } else if (ch == 10) {
            _emitField();
            _emitRow();
            i++;
          } else {
            final match = _delimMatchAt(codes, i, len);
            if (match == _fullMatch) {
              _emitField();
              i += _delimCodes.length;
            } else if (match == _partialMatch) {
              _pendingDelim = len - i;
              i = len;
            } else {
              _buf.writeCharCode(ch);
              _state = _State.unquotedField;
              i++;
            }
          }

        case _State.unquotedField:
          if (ch == 13) {
            _emitField();
            _emitRow();
            _pendingCr = true;
            _state = _State.fieldStart;
            i++;
          } else if (ch == 10) {
            _emitField();
            _emitRow();
            _state = _State.fieldStart;
            i++;
          } else {
            final match = _delimMatchAt(codes, i, len);
            if (match == _fullMatch) {
              _emitField();
              _state = _State.fieldStart;
              i += _delimCodes.length;
            } else if (match == _partialMatch) {
              _pendingDelim = len - i;
              i = len;
            } else {
              _buf.writeCharCode(ch);
              i++;
            }
          }

        case _State.quotedField:
          if (_pendingEscape) {
            _pendingEscape = false;
            if (ch == _quoteCode) {
              _buf.writeCharCode(_quoteCode);
              i++;
            } else {
              _buf.writeCharCode(_escapeCode);
              // Don't advance: reprocess current char
            }
          } else if (ch == _escapeCode &&
              _escapeCode != _quoteCode &&
              i + 1 >= len) {
            // Escape at chunk boundary (only when escape != quote)
            _pendingEscape = true;
            i++;
          } else if (ch == _escapeCode &&
              i + 1 < len &&
              codes[i + 1] == _quoteCode) {
            _buf.writeCharCode(_quoteCode);
            i += 2;
          } else if (ch == _quoteCode) {
            _state = _State.afterQuote;
            i++;
          } else {
            _buf.writeCharCode(ch);
            i++;
          }

        case _State.afterQuote:
          if (ch == _quoteCode) {
            // RFC doubling that happened to split at a chunk boundary.
            _buf.writeCharCode(_quoteCode);
            _state = _State.quotedField;
            i++;
          } else if (ch == 13) {
            _emitField();
            _emitRow();
            _pendingCr = true;
            _state = _State.fieldStart;
            i++;
          } else if (ch == 10) {
            _emitField();
            _emitRow();
            _state = _State.fieldStart;
            i++;
          } else {
            final match = _delimMatchAt(codes, i, len);
            if (match == _fullMatch) {
              _emitField();
              _state = _State.fieldStart;
              i += _delimCodes.length;
            } else if (match == _partialMatch) {
              _pendingDelim = len - i;
              i = len;
            } else {
              // Text after the closing quote is appended to the field
              // (Excel behavior); strict mode throws.
              if (_strict) {
                throw CsvParseException(
                  'Unexpected character after closing quote',
                  row: _rowIndex,
                  column: _currentRow.length,
                );
              }
              _buf.writeCharCode(ch);
              _state = _State.quoteJunk;
              i++;
            }
          }

        case _State.quoteJunk:
          // After junk follows a closed quote, everything up to the next
          // boundary is literal, including quote characters.
          if (ch == 13) {
            _emitField();
            _emitRow();
            _pendingCr = true;
            _state = _State.fieldStart;
            i++;
          } else if (ch == 10) {
            _emitField();
            _emitRow();
            _state = _State.fieldStart;
            i++;
          } else {
            final match = _delimMatchAt(codes, i, len);
            if (match == _fullMatch) {
              _emitField();
              _state = _State.fieldStart;
              i += _delimCodes.length;
            } else if (match == _partialMatch) {
              _pendingDelim = len - i;
              i = len;
            } else {
              _buf.writeCharCode(ch);
              i++;
            }
          }
      }
    }
  }

  @override
  void flushHeld() {}

  @override
  void finish() {
    // A comment line at end of input (no trailing newline) emits nothing.
    if (_state == _State.comment) return;
    if (_pendingEscape) {
      _pendingEscape = false;
      _buf.writeCharCode(_escapeCode);
    }
    if (_pendingDelim > 0) {
      // A partial delimiter at end of input is literal field content.
      _flushPendingDelimAsContent();
    }
    if (_strict && _state == _State.quotedField) {
      throw CsvParseException(
        'Unterminated quoted field',
        row: _rowIndex,
        column: _currentRow.length,
      );
    }
    if (_buf.isNotEmpty ||
        _currentRow.isNotEmpty ||
        _state != _State.fieldStart) {
      _emitField();
      _emitRow();
    }
  }

  static const _noMatch = 0;
  static const _partialMatch = 1;
  static const _fullMatch = 2;

  /// Delimiter match at [pos]: full, partial (runs into the chunk end),
  /// or none.
  int _delimMatchAt(List<int> codes, int pos, int len) {
    if (_singleDelim) {
      return codes[pos] == _delimCodes[0] ? _fullMatch : _noMatch;
    }
    final delimLen = _delimCodes.length;
    final visible = len - pos < delimLen ? len - pos : delimLen;
    for (var j = 0; j < visible; j++) {
      if (codes[pos + j] != _delimCodes[j]) return _noMatch;
    }
    return visible == delimLen ? _fullMatch : _partialMatch;
  }

  /// Continue a delimiter match split across chunks. Returns the new
  /// scan position.
  int _resumePendingDelim(List<int> codes, int i, int len) {
    final delimLen = _delimCodes.length;
    var matched = _pendingDelim;
    var j = i;
    while (matched < delimLen && j < len && codes[j] == _delimCodes[matched]) {
      matched++;
      j++;
    }
    if (matched == delimLen) {
      // The delimiter completed across the boundary.
      _pendingDelim = 0;
      _emitField();
      _state = _State.fieldStart;
      return j;
    }
    if (j >= len) {
      // Chunk exhausted while still matching; keep waiting.
      _pendingDelim = matched;
      return j;
    }
    // Mismatch: the matched prefix was literal content after all. Chars
    // consumed from this chunk (i..j) are part of that flushed prefix.
    _pendingDelim = matched;
    _flushPendingDelimAsContent();
    return j;
  }

  void _flushPendingDelimAsContent() {
    final matched = _pendingDelim;
    _pendingDelim = 0;
    if (_state == _State.afterQuote) {
      if (_strict) {
        throw CsvParseException(
          'Unexpected character after closing quote',
          row: _rowIndex,
          column: _currentRow.length,
        );
      }
      _state = _State.quoteJunk;
    } else if (_state == _State.fieldStart) {
      _state = _State.unquotedField;
    }
    for (var k = 0; k < matched; k++) {
      _buf.writeCharCode(_delimCodes[k]);
    }
  }

  void _emitField() {
    var raw = _buf.toString();
    _buf.clear();

    // A quoted field says exactly where it begins and ends, so only an
    // unquoted one is trimmed, and it is trimmed before anything reads it.
    if (_trimFields && !_isQuoted) raw = raw.trim();

    final isHeaderRow = _hasHeader && _headers == null;
    dynamic value;
    if (_isQuoted) {
      value = raw;
    } else if (_dynamicTyping && !isHeaderRow) {
      value = FastDecoder.inferType(
        raw,
        parseDates: _parseDates,
        dateOrder: _dateOrder,
        monthNames: _monthNames,
        nullValues: config.nullValues,
        boolValues: config.boolValues,
      );
    } else {
      value = raw;
    }

    final transform = config.decoderTransform;
    if (transform != null && !isHeaderRow) {
      final hdr = (_headers != null && _currentRow.length < _headers!.length)
          ? _headers![_currentRow.length]
          : null;
      value = transform(value, _currentRow.length, hdr);
    }

    _currentRow.add(value);
    _isQuoted = false;
  }

  void _emitRow() {
    final row = _currentRow;
    _currentRow = <dynamic>[];
    _rowIndex++;
    _atLineStart = true;

    // A row of a single empty field is an empty line per RFC 4180.
    if (_skipEmpty && row.length == 1) {
      final only = row[0];
      if (only == null || only == '') return;
    }

    // Skip leading rows (a preamble) before the header row is read.
    if (_skipped < _skipRows) {
      _skipped++;
      return;
    }

    if (_hasHeader && _headers == null) {
      _headers = List<String>.generate(row.length, (i) => row[i] as String);
      return;
    }

    // Stop emitting once the data-row limit is reached.
    final max = _maxRows;
    if (max != null && _dataCount >= max) return;
    _dataCount++;
    _emit(row);
  }
}

/// Chunked conversion sink for [CsvDecoder].
class _CsvDecoderSink extends StringConversionSinkBase {
  final _ChunkParser _machine;
  final Sink<List<dynamic>> _output;

  _CsvDecoderSink(CsvConfig config, this._output)
    : _machine = _newParser(config, _output.add);

  @override
  void addSlice(String str, int start, int end, bool isLast) {
    _machine.addChunk(str.substring(start, end));
    if (isLast) close();
  }

  @override
  void close() {
    _machine.finish();
    _output.close();
  }
}
