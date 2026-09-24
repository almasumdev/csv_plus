import 'date_order.dart';
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

  /// Automatically parse ISO-8601 dates and date-times into [DateTime].
  ///
  /// Off by default, and only applied when [dynamicTyping] is on. A field is
  /// converted when it starts with `YYYY-MM-DD`, optionally followed by a time
  /// (`2024-01-31T09:30:00`); a space in place of the `T`, fractional seconds,
  /// and a trailing `Z` or `+05:30` offset are all accepted. Anything else
  /// stays text, including ambiguous locale formats such as `03/04/2024` and
  /// impossible dates such as `2024-13-45`.
  ///
  /// A value with no offset reads as a local [DateTime]; one with a `Z` or a
  /// numeric offset reads as UTC. Quoted fields are never inferred, so
  /// `"2024-01-31"` stays a string.
  final bool parseDates;

  /// Throw [CsvParseException] on structurally malformed input instead of
  /// recovering: a character after a closing quote, or an unterminated
  /// quoted field at end of input.
  ///
  /// When `false` (the default), malformed quotes degrade gracefully:
  /// text after a closing quote is appended to the field (Excel behavior)
  /// and an unterminated quote consumes the rest of the input as content.
  final bool strict;

  /// Marker for comment lines to skip while decoding (for example `#`).
  ///
  /// A physical line whose first character equals this marker is dropped
  /// before it is parsed as a record. Detection happens only at the very
  /// start of a line, so the marker inside a quoted field (`"a#b"`) or
  /// mid-field (`a#b`) is ordinary content. The marker is a single
  /// character; if a longer string is given only its first character is
  /// used. Comment lines never count toward [skipRows]. Decode-only;
  /// `null` (the default) disables comment skipping.
  final String? comment;

  /// Number of leading rows to skip before decoding begins.
  ///
  /// Counted after comment lines and (under [skipEmptyLines]) empty lines
  /// are dropped, and before the header row (if [hasHeader]) is read, so it
  /// skips a preamble sitting above the real table. Decode-only; defaults
  /// to `0`.
  final int skipRows;

  /// Maximum number of data rows to return, or `null` (the default) for no
  /// limit.
  ///
  /// The header row (under [hasHeader]) is not counted. The batch decoders
  /// stop reading once the limit is reached; the streaming decoder stops
  /// emitting further rows. Decode-only.
  final int? maxRows;

  /// Transform each field after decoding.
  final dynamic Function(dynamic value, int index, String? header)?
  decoderTransform;

  /// Transform each field before encoding.
  final dynamic Function(dynamic value, int index, String? header)?
  encoderTransform;

  /// Drop spaces sitting between a delimiter and the start of a field.
  ///
  /// RFC 4180 treats a space before a quote as ordinary content, so
  /// `a, "b, c"` is three fields by the letter of the spec. Spreadsheets and
  /// several exporters instead read it as two, with the quoted field starting
  /// after the space. Off by default so the strict reading stays the default;
  /// turn it on for files written by a tool that pads after the delimiter.
  ///
  /// Only spaces in an unquoted position at the start of a field are dropped.
  /// A space inside a quoted field, or after the first non-space character, is
  /// always content. Decode-only.
  final bool skipInitialSpace;

  /// Unquoted field values that decode to `null` instead of their own text.
  ///
  /// Exports commonly write a missing value as `NULL`, `NA` or `N/A` rather
  /// than leaving the field empty, and it otherwise arrives as that string.
  /// Matching is exact and case-sensitive, so list every spelling the file
  /// uses.
  ///
  /// Only applies to a field that would otherwise read as **text**. A quoted
  /// field is never matched, so a genuine `"NULL"` in the data survives; and an
  /// entry that type inference would turn into a number or a bool (`0`,
  /// `false`) never reaches the check, so putting one here has no effect. That
  /// restriction is what keeps the batch and streaming decoders in agreement.
  ///
  /// Empty by default, which costs nothing on the hot path. Decode-only.
  final Set<String> nullValues;

  /// Text written for a `null` value when encoding.
  ///
  /// A null encodes as an empty field by default, which is what most readers
  /// expect. Some destinations want a sentinel instead: Postgres `COPY` reads
  /// `\N`, and plenty of exports use `NULL`. Set this to write that instead.
  ///
  /// The placeholder goes through the normal cell writer, so it is quoted when
  /// it needs to be and a reader that knows nothing about it still sees a
  /// well-formed field. Pair it with [nullValues] to read the same file back
  /// with its nulls intact.
  ///
  /// `null` (the default) keeps the empty-field behaviour. Encode-only.
  final String? nullPlaceholder;

  /// How to read a numeric date whose field order is ambiguous.
  ///
  /// A CSV carries no locale, so `03/04/2024` is the third of April in most of
  /// the world and the fourth of March in the United States. Guessing would be
  /// wrong half the time, so the default [CsvDateOrder.iso] leaves such a value
  /// as text. Set [CsvDateOrder.dayFirst] or [CsvDateOrder.monthFirst] to say
  /// which your file uses.
  ///
  /// Only applies when [parseDates] is on. ISO-8601 is recognised whichever
  /// order is selected. Separators `/`, `-` and `.` are accepted, a two-digit
  /// year reads as 2000s up to 68 and 1900s from 69, and a trailing `HH:mm` or
  /// `HH:mm:ss` is kept.
  ///
  /// Either non-ISO order also reads dates that name their month in English,
  /// such as `3 April 2024`, `April 3, 2024`, `03-Apr-2024` and `1st Jan 24`.
  final CsvDateOrder dateOrder;

  /// Extra month names to recognise, keyed lowercase, for a language other
  /// than English.
  ///
  /// English names are built in. Add your own to read dates in another
  /// language, mapping each spelling to its month number:
  ///
  /// ```dart
  /// const CsvConfig(
  ///   parseDates: true,
  ///   dateOrder: CsvDateOrder.dayFirst,
  ///   monthNames: {'janvier': 1, 'janv': 1, 'fevrier': 2, 'février': 2},
  /// )
  /// ```
  ///
  /// Keys must already be lowercase, since the field is lowercased before the
  /// lookup. These are consulted before the English names, so a spelling both
  /// languages share can be given the meaning your file intends. Only applies
  /// when [dateOrder] is not [CsvDateOrder.iso], the same as the English
  /// names.
  final Map<String, int> monthNames;

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
    this.parseDates = false,
    this.strict = false,
    this.comment,
    this.skipRows = 0,
    this.maxRows,
    this.skipInitialSpace = false,
    this.nullValues = const <String>{},
    this.nullPlaceholder,
    this.dateOrder = CsvDateOrder.iso,
    this.monthNames = const {},
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
    this.parseDates = false,
    this.strict = false,
    this.comment,
    this.skipRows = 0,
    this.maxRows,
    this.skipInitialSpace = false,
    this.nullValues = const <String>{},
    this.nullPlaceholder,
    this.dateOrder = CsvDateOrder.iso,
    this.monthNames = const {},
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
    this.parseDates = false,
    this.strict = false,
    this.comment,
    this.skipRows = 0,
    this.maxRows,
    this.skipInitialSpace = false,
    this.nullValues = const <String>{},
    this.nullPlaceholder,
    this.dateOrder = CsvDateOrder.iso,
    this.monthNames = const {},
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
    this.parseDates = false,
    this.strict = false,
    this.comment,
    this.skipRows = 0,
    this.maxRows,
    this.skipInitialSpace = false,
    this.nullValues = const <String>{},
    this.nullPlaceholder,
    this.dateOrder = CsvDateOrder.iso,
    this.monthNames = const {},
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
    bool? parseDates,
    bool? strict,
    String? comment,
    int? skipRows,
    int? maxRows,
    bool? skipInitialSpace,
    Set<String>? nullValues,
    String? nullPlaceholder,
    CsvDateOrder? dateOrder,
    Map<String, int>? monthNames,
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
      parseDates: parseDates ?? this.parseDates,
      strict: strict ?? this.strict,
      comment: comment ?? this.comment,
      skipRows: skipRows ?? this.skipRows,
      maxRows: maxRows ?? this.maxRows,
      skipInitialSpace: skipInitialSpace ?? this.skipInitialSpace,
      nullValues: nullValues ?? this.nullValues,
      nullPlaceholder: nullPlaceholder ?? this.nullPlaceholder,
      dateOrder: dateOrder ?? this.dateOrder,
      monthNames: monthNames ?? this.monthNames,
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
