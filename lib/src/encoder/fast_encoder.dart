import '../core/csv_config.dart';
import '../core/quote_mode.dart';

/// High-performance batch CSV encoder using per-call [StringBuffer].
///
/// Thread-safe: no global mutable state.
///
/// Null handling per [QuoteMode]: `necessary` and `strings` write nulls
/// as an empty unquoted field (so null and `''` round-trip differently:
/// `necessary` quotes empty strings as `""`); `always` writes nulls as
/// `""` like every other field.
class FastEncoder {
  /// Create a batch encoder instance (stateless, reusable).
  const FastEncoder();

  /// Encode rows to CSV string with type-aware quoting.
  ///
  /// With [CsvConfig.hasHeader], the first row is treated as the header
  /// row: it is written verbatim (no [CsvConfig.encoderTransform]) and
  /// its names are passed to the transform for the data rows.
  String encode(List<List<dynamic>> data, CsvConfig config) {
    if (data.isEmpty) return config.addBom ? '﻿' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;
    final mode = config.quoteMode;
    final transform = config.encoderTransform;
    final hasHeader = config.hasHeader;

    List<String>? headerNames;
    if (transform != null && hasHeader) {
      headerNames =
          data.first.map((e) => e?.toString() ?? '').toList(growable: false);
    }

    for (var r = 0; r < data.length; r++) {
      final row = data[r];
      final isHeaderRow = hasHeader && r == 0;
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        var cell = row[c];
        if (transform != null && !isHeaderRow) {
          final hdr = (headerNames != null && c < headerNames.length)
              ? headerNames[c]
              : null;
          cell = transform(cell, c, hdr);
        }
        writeCell(buf, cell, delim, quote, escape, mode);
      }
      if (r < data.length - 1) buf.write(lineDelim);
    }

    return buf.toString();
  }

  /// Encode all-string data (skip type checks, always quote).
  String encodeStrings(List<List<String>> data, CsvConfig config) {
    if (data.isEmpty) return config.addBom ? '﻿' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;

    for (var r = 0; r < data.length; r++) {
      final row = data[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        buf.write(quote);
        buf.write(row[c].replaceAll(quote, '$escape$quote'));
        buf.write(quote);
      }
      if (r < data.length - 1) buf.write(lineDelim);
    }

    return buf.toString();
  }

  /// Encode uniform-typed data. Ideal for numeric/bool grids.
  ///
  /// Non-string values are written without any quoting checks. String
  /// values still get RFC quoting when they contain the delimiter, a
  /// quote, or a newline, so `T == String` cannot produce corrupt CSV.
  String encodeGeneric<T>(List<List<T>> data, CsvConfig config) {
    if (data.isEmpty) return config.addBom ? '﻿' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;

    for (var r = 0; r < data.length; r++) {
      final row = data[r];
      for (var c = 0; c < row.length; c++) {
        if (c > 0) buf.write(delim);
        final cell = row[c];
        if (cell is String) {
          if (CsvConfig.needsQuoting(cell, delim, quote)) {
            buf.write(quote);
            buf.write(cell.replaceAll(quote, '$escape$quote'));
            buf.write(quote);
          } else {
            buf.write(cell);
          }
        } else {
          buf.write(cell.toString());
        }
      }
      if (r < data.length - 1) buf.write(lineDelim);
    }

    return buf.toString();
  }

  /// Encode a Map as two-column CSV (key, value).
  String encodeMap(Map<String, dynamic> map, CsvConfig config) {
    if (map.isEmpty) return config.addBom ? '﻿' : '';

    final buf = StringBuffer();
    if (config.addBom) buf.writeCharCode(0xFEFF);

    final delim = config.fieldDelimiter;
    final lineDelim = config.lineDelimiter;
    final quote = config.quoteCharacter;
    final escape = config.escapeCharacter;
    final mode = config.quoteMode;

    var first = true;
    for (final entry in map.entries) {
      if (!first) buf.write(lineDelim);
      first = false;

      // Key is always a string
      buf.write(quote);
      buf.write(entry.key.replaceAll(quote, '$escape$quote'));
      buf.write(quote);

      buf.write(delim);
      writeCell(buf, entry.value, delim, quote, escape, mode);
    }

    return buf.toString();
  }

  /// Write one cell into [buf], applying quoting per [mode].
  ///
  /// This is the single cell-writing implementation shared by the batch
  /// and streaming encoders, so their outputs cannot diverge.
  static void writeCell(
    StringBuffer buf,
    dynamic cell,
    String delim,
    String quote,
    String escape,
    QuoteMode mode,
  ) {
    if (cell == null) {
      // Null reads back as null (typed decode); only QuoteMode.always
      // materializes it as a quoted empty string.
      if (mode == QuoteMode.always) {
        buf.write(quote);
        buf.write(quote);
      }
      return;
    }

    final str = cell.toString();

    switch (mode) {
      case QuoteMode.always:
        buf.write(quote);
        buf.write(str.replaceAll(quote, '$escape$quote'));
        buf.write(quote);
      case QuoteMode.strings:
        if (cell is String) {
          buf.write(quote);
          buf.write(str.replaceAll(quote, '$escape$quote'));
          buf.write(quote);
        } else {
          buf.write(str);
        }
      case QuoteMode.necessary:
        if (cell is num || cell is bool) {
          buf.write(str);
        } else if (_needsQuoting(str, delim, quote)) {
          buf.write(quote);
          buf.write(str.replaceAll(quote, '$escape$quote'));
          buf.write(quote);
        } else {
          buf.write(str);
        }
    }
  }

  static bool _needsQuoting(String value, String delim, String quote) =>
      CsvConfig.needsQuoting(value, delim, quote);
}
