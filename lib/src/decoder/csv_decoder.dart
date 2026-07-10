import 'dart:async';
import 'dart:convert';

import '../core/csv_config.dart';
import '../core/csv_exception.dart';
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
    final machine = _StateMachine(config, rows.add);
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
        final machine = _StateMachine(config, controller.add);
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

enum _State { fieldStart, unquotedField, quotedField, afterQuote, quoteJunk }

/// Chunked CSV parsing state machine. Preserves state across chunk boundaries.
class _StateMachine {
  final CsvConfig config;
  final void Function(List<dynamic> row) _emit;

  late final int _quoteCode = config.quoteCharacter.codeUnitAt(0);
  late final int _escapeCode = config.escapeCharacter.codeUnitAt(0);
  late final List<int> _delimCodes = config.fieldDelimiter.codeUnits;
  late final bool _singleDelim = _delimCodes.length == 1;
  late final bool _dynamicTyping = config.dynamicTyping;
  late final bool _skipEmpty = config.skipEmptyLines;
  late final bool _hasHeader = config.hasHeader;
  late final bool _strict = config.strict;

  _State _state = _State.fieldStart;
  final _buf = StringBuffer();
  var _currentRow = <dynamic>[];
  var _isQuoted = false;
  var _pendingCr = false;
  var _pendingEscape = false;
  var _bomChecked = false;
  // Number of delimiter code units already matched at a chunk boundary.
  var _pendingDelim = 0;
  var _rowIndex = 0;
  List<String>? _headers;

  _StateMachine(this.config, this._emit);

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
        case _State.fieldStart:
          _isQuoted = false;
          if (_pendingCr) {
            _pendingCr = false;
            if (ch == 10) {
              i++;
              continue;
            }
          }
          if (ch == _quoteCode) {
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

  void finish() {
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
    final raw = _buf.toString();
    _buf.clear();

    final isHeaderRow = _hasHeader && _headers == null;
    dynamic value;
    if (_isQuoted) {
      value = raw;
    } else if (_dynamicTyping && !isHeaderRow) {
      value = FastDecoder.inferType(raw);
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

    // A row of a single empty field is an empty line per RFC 4180.
    if (_skipEmpty && row.length == 1) {
      final only = row[0];
      if (only == null || only == '') return;
    }

    if (_hasHeader && _headers == null) {
      _headers = List<String>.generate(row.length, (i) => row[i] as String);
      return;
    }

    _emit(row);
  }
}

/// Chunked conversion sink for [CsvDecoder].
class _CsvDecoderSink extends StringConversionSinkBase {
  final _StateMachine _machine;
  final Sink<List<dynamic>> _output;

  _CsvDecoderSink(CsvConfig config, this._output)
      : _machine = _StateMachine(config, _output.add);

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
