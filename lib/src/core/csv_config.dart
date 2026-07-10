import 'quote_mode.dart';

/// Immutable configuration for CSV encoding/decoding.
class CsvConfig {
  /// Field delimiter. Supports single or multi-character.
  final String fieldDelimiter;

  /// Row delimiter for encoding. Decoding auto-detects line endings.
  final String lineDelimiter;

  /// Quote character. Must be single character.
  final String quoteCharacter;

  /// Escape character inside quoted fields.
  /// Defaults to [quoteCharacter] (RFC 4180 doubling).
  final String escapeCharacter;

  /// When to quote fields during encoding.
  final QuoteMode quoteMode;

  /// Add UTF-8 BOM at start of encoded output.
  final bool addBom;

  /// Auto-detect field delimiter from input.
  final bool autoDetect;

  /// Skip rows where all fields are empty.
  final bool skipEmptyLines;

  /// Treat first row as column headers.
  final bool hasHeader;

  /// Automatically parse numbers and booleans from string fields.
  ///
  /// Inference is guarded against silent data loss: values with leading
  /// zeros (`007`), a leading plus sign (`+1`), surrounding whitespace,
  /// or more than 15 digits stay strings, and quoted fields are never
  /// inferred. See `FastDecoder.inferType` for the full rules.
  final bool dynamicTyping;

  /// Throw [CsvParseException] on structurally malformed input instead of
  /// recovering: a character after a closing quote, or an unterminated
  /// quoted field at end of input.
  ///
  /// When `false` (the default), malformed quotes degrade gracefully:
  /// text after a closing quote is appended to the field (Excel behavior)
  /// and an unterminated quote consumes the rest of the input as content.
  final bool strict;

  /// Transform each field after decoding.
  final dynamic Function(dynamic value, int index, String? header)?
  decoderTransform;

  /// Transform each field before encoding.
  final dynamic Function(dynamic value, int index, String? header)?
  encoderTransform;

  /// Create a CSV configuration.
  ///
  /// All parameters have sensible defaults (RFC 4180 compatible).
  /// Named presets [CsvConfig.excel], [CsvConfig.tsv], [CsvConfig.pipe]
  /// are available for common formats.
  const CsvConfig({
    this.fieldDelimiter = ',',
    this.lineDelimiter = '\r\n',
    this.quoteCharacter = '"',
    String? escapeCharacter,
    this.quoteMode = QuoteMode.necessary,
    this.addBom = false,
    this.autoDetect = true,
    this.skipEmptyLines = true,
    this.hasHeader = false,
    this.dynamicTyping = true,
    this.strict = false,
    this.decoderTransform,
    this.encoderTransform,
  }) : escapeCharacter = escapeCharacter ?? quoteCharacter;

  /// Excel-compatible preset: `;` delimiter, UTF-8 BOM, no auto-detect.
  const CsvConfig.excel({
    this.lineDelimiter = '\r\n',
    this.quoteCharacter = '"',
    String? escapeCharacter,
    this.quoteMode = QuoteMode.necessary,
    this.skipEmptyLines = true,
    this.hasHeader = false,
    this.dynamicTyping = true,
    this.strict = false,
    this.decoderTransform,
    this.encoderTransform,
  }) : fieldDelimiter = ';',
       addBom = true,
       autoDetect = false,
       escapeCharacter = escapeCharacter ?? quoteCharacter;

  /// Tab-separated values preset.
  const CsvConfig.tsv({
    this.lineDelimiter = '\r\n',
    this.quoteCharacter = '"',
    String? escapeCharacter,
    this.quoteMode = QuoteMode.necessary,
    this.addBom = false,
    this.skipEmptyLines = true,
    this.hasHeader = false,
    this.dynamicTyping = true,
    this.strict = false,
    this.decoderTransform,
    this.encoderTransform,
  }) : fieldDelimiter = '\t',
       autoDetect = false,
       escapeCharacter = escapeCharacter ?? quoteCharacter;

  /// Pipe-separated values preset.
  const CsvConfig.pipe({
    this.lineDelimiter = '\r\n',
    this.quoteCharacter = '"',
    String? escapeCharacter,
    this.quoteMode = QuoteMode.necessary,
    this.addBom = false,
    this.skipEmptyLines = true,
    this.hasHeader = false,
    this.dynamicTyping = true,
    this.strict = false,
    this.decoderTransform,
    this.encoderTransform,
  }) : fieldDelimiter = '|',
       autoDetect = false,
       escapeCharacter = escapeCharacter ?? quoteCharacter;

  /// Create a modified copy, overriding only the specified fields.
  ///
  /// ```dart
  /// final tsv = config.copyWith(fieldDelimiter: '\t');
  /// ```
  CsvConfig copyWith({
    String? fieldDelimiter,
    String? lineDelimiter,
    String? quoteCharacter,
    String? escapeCharacter,
    QuoteMode? quoteMode,
    bool? addBom,
    bool? autoDetect,
    bool? skipEmptyLines,
    bool? hasHeader,
    bool? dynamicTyping,
    bool? strict,
    dynamic Function(dynamic value, int index, String? header)?
    decoderTransform,
    dynamic Function(dynamic value, int index, String? header)?
    encoderTransform,
  }) {
    return CsvConfig(
      fieldDelimiter: fieldDelimiter ?? this.fieldDelimiter,
      lineDelimiter: lineDelimiter ?? this.lineDelimiter,
      quoteCharacter: quoteCharacter ?? this.quoteCharacter,
      escapeCharacter: escapeCharacter ?? this.escapeCharacter,
      quoteMode: quoteMode ?? this.quoteMode,
      addBom: addBom ?? this.addBom,
      autoDetect: autoDetect ?? this.autoDetect,
      skipEmptyLines: skipEmptyLines ?? this.skipEmptyLines,
      hasHeader: hasHeader ?? this.hasHeader,
      dynamicTyping: dynamicTyping ?? this.dynamicTyping,
      strict: strict ?? this.strict,
      decoderTransform: decoderTransform ?? this.decoderTransform,
      encoderTransform: encoderTransform ?? this.encoderTransform,
    );
  }

  /// Whether [value] must be quoted when encoding with this config.
  ///
  /// A field needs quoting when it is empty, contains the field delimiter,
  /// CR, LF, the quote character, or starts/ends with a space.
  static bool needsQuoting(String value, String delim, String quote) {
    final units = value.codeUnits;
    final len = units.length;
    if (len == 0) return true;

    if (units[0] == 0x20 || units[len - 1] == 0x20) return true;

    final delimUnits = delim.codeUnits;
    final delimLen = delimUnits.length;
    final quoteCode = quote.codeUnitAt(0);

    for (var i = 0; i < len; i++) {
      final ch = units[i];
      if (ch == 0x0A || ch == 0x0D || ch == quoteCode) return true;
      if (ch == delimUnits[0] && i + delimLen <= len) {
        var match = true;
        for (var d = 1; d < delimLen; d++) {
          if (units[i + d] != delimUnits[d]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }
    }
    return false;
  }
}
