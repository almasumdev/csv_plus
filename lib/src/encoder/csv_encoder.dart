import 'dart:async';
import 'dart:convert';

import '../core/csv_config.dart';
import '../core/quote_mode.dart';
import 'fast_encoder.dart';

/// Streaming CSV encoder that transforms rows to CSV string chunks.
///
/// Supports three modes via [CsvConfig.quoteMode]:
/// - [QuoteMode.necessary]: quote only when the field contains delimiters,
///   newlines, quotes, or leading/trailing whitespace.
/// - [QuoteMode.always]: unconditionally quote every field.
/// - [QuoteMode.strings]: quote only [String]-typed fields.
///
/// Cell formatting is shared with [FastEncoder], so batch and streaming
/// output are always identical for the same rows and config.
///
/// [bind] honors downstream backpressure: when the listener pauses, the
/// upstream subscription is paused.
class CsvEncoder extends StreamTransformerBase<List<dynamic>, String> {
  /// Configuration for this encoder.
  final CsvConfig config;

  /// Create with the given [config] (defaults to [CsvConfig] defaults).
  const CsvEncoder([this.config = const CsvConfig()]);

  /// Batch: encode all rows to a single CSV string.
  String convert(List<List<dynamic>> rows) {
    return const FastEncoder().encode(rows, config);
  }

  @override
  Stream<String> bind(Stream<List<dynamic>> stream) {
    StreamSubscription<List<dynamic>>? subscription;
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        final formatter = _RowFormatter(config);
        subscription = stream.listen(
          (row) {
            try {
              controller.add(formatter.format(row));
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
          onDone: controller.close,
          cancelOnError: true,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  /// Encode rows to a UTF-8 byte stream (for file or socket sinks),
  /// without wiring `utf8.encoder` by hand.
  Stream<List<int>> bindBytes(Stream<List<dynamic>> stream) =>
      utf8.encoder.bind(bind(stream));

  /// Chunked conversion sink for `dart:convert` pipeline compatibility.
  Sink<List<dynamic>> startChunkedConversion(Sink<String> sink) {
    return _CsvEncoderSink(config, sink);
  }

  /// Encode a single field to a properly quoted string.
  static String encodeField(
    dynamic field, {
    required String fieldDelimiter,
    required String quoteCharacter,
    required String escapeCharacter,
    required QuoteMode quoteMode,
  }) {
    final buf = StringBuffer();
    FastEncoder.writeCell(
        buf, field, fieldDelimiter, quoteCharacter, escapeCharacter, quoteMode);
    return buf.toString();
  }
}

/// Formats one row per call, tracking BOM/line-delimiter state and the
/// header row (when [CsvConfig.hasHeader] is set, the first row is
/// written verbatim and provides names for [CsvConfig.encoderTransform]).
class _RowFormatter {
  final CsvConfig config;
  var _first = true;
  List<String>? _headerNames;

  _RowFormatter(this.config);

  String format(List<dynamic> row) {
    final buf = StringBuffer();
    var isHeaderRow = false;
    if (_first) {
      _first = false;
      if (config.addBom) buf.writeCharCode(0xFEFF);
      if (config.hasHeader) {
        isHeaderRow = true;
        if (config.encoderTransform != null) {
          _headerNames =
              row.map((e) => e?.toString() ?? '').toList(growable: false);
        }
      }
    } else {
      buf.write(config.lineDelimiter);
    }

    final transform = config.encoderTransform;
    final headerNames = _headerNames;
    for (var c = 0; c < row.length; c++) {
      if (c > 0) buf.write(config.fieldDelimiter);
      var cell = row[c];
      if (transform != null && !isHeaderRow) {
        final hdr = (headerNames != null && c < headerNames.length)
            ? headerNames[c]
            : null;
        cell = transform(cell, c, hdr);
      }
      FastEncoder.writeCell(buf, cell, config.fieldDelimiter,
          config.quoteCharacter, config.escapeCharacter, config.quoteMode);
    }

    return buf.toString();
  }
}

/// Chunked conversion sink for [CsvEncoder].
class _CsvEncoderSink implements Sink<List<dynamic>> {
  final _RowFormatter _formatter;
  final Sink<String> _output;

  _CsvEncoderSink(CsvConfig config, this._output)
      : _formatter = _RowFormatter(config);

  @override
  void add(List<dynamic> row) {
    _output.add(_formatter.format(row));
  }

  @override
  void close() {
    _output.close();
  }
}
