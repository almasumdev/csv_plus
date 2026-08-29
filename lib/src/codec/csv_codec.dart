import 'dart:convert';
import 'dart:typed_data';

import 'codec_adapter.dart';
import '../core/charset.dart';
import '../core/csv_config.dart';
import '../decoder/csv_decoder.dart';
import '../decoder/delimiter_detector.dart';
import '../decoder/fast_decoder.dart';
import '../decoder/fast_decoder_ext.dart';
import '../encoder/csv_encoder.dart';
import '../encoder/fast_encoder.dart';
import '../table/csv_row.dart';
import '../table/csv_schema.dart';
import '../table/csv_table.dart';

const _fastDecoder = FastDecoder();
const _fastEncoder = FastEncoder();
const _detector = DelimiterDetector();

/// Main facade for CSV encoding and decoding.
///
/// Wraps [FastEncoder] and [FastDecoder] with shared [CsvConfig].
class CsvCodec {
  /// Configuration for this codec.
  final CsvConfig config;

  /// Create a codec with the given [config] (defaults to standard CSV).
  const CsvCodec([this.config = const CsvConfig()]);

  /// Excel-compatible preset: `;` delimiter, UTF-8 BOM.
  const CsvCodec.excel() : config = const CsvConfig.excel();

  /// Tab-separated values preset.
  const CsvCodec.tsv() : config = const CsvConfig.tsv();

  /// Pipe-separated values preset.
  const CsvCodec.pipe() : config = const CsvConfig.pipe();

  // ---------------------------------------------------------------------------
  // Batch decode
  // ---------------------------------------------------------------------------

  /// Resolve config with auto-detected delimiter if [CsvConfig.autoDetect] is
  /// enabled and the input contains a recognisable delimiter or `sep=` hint.
  /// Returns (preprocessed input, resolved config).
  ///
  /// Auto-detection is skipped when the user has explicitly set a non-default
  /// field delimiter (anything other than `,`), since that signals intent.
  (String, CsvConfig) _resolve(String input) {
    if (!config.autoDetect || config.fieldDelimiter != ',') {
      return (input, config);
    }

    final (bomStripped, _) = _detector.stripBom(input);
    final (remaining, sepDelim) = _detector.checkSepHint(bomStripped);

    if (sepDelim != null) {
      // sep= hint found: strip that line and use the hinted delimiter
      return (remaining, config.copyWith(fieldDelimiter: sepDelim));
    }

    final detected = _detector.detectDelimiter(bomStripped);
    if (detected != config.fieldDelimiter) {
      return (input, config.copyWith(fieldDelimiter: detected));
    }
    return (input, config);
  }

  /// Decode CSV string to list of rows.
  List<List<dynamic>> decode(String input) {
    final (resolved, cfg) = _resolve(input);
    return _fastDecoder.decode(resolved, cfg);
  }

  /// Decode with first row as headers. Returns [CsvRow] objects.
  ///
  /// Header cells are read as raw strings (no type inference), so a
  /// header like `01` keeps its name. Parses the input in a single pass.
  List<CsvRow> decodeWithHeaders(String input) {
    final (resolved, cfg) = _resolve(input);
    final decoded = _fastDecoder.decodeWithHeaders(resolved, cfg);

    final headers = decoded.headers;
    final headerMap = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      headerMap[headers[i]] = i;
    }

    return decoded.rows.map((row) => CsvRow(row, headerMap)).toList();
  }

  /// Decode all fields as strings (no type inference).
  List<List<String>> decodeStrings(String input) {
    final (resolved, cfg) = _resolve(input);
    return _fastDecoder.decodeStrings(resolved, cfg);
  }

  /// Decode with lenient parsing: trims whitespace, treats unmatched quotes
  /// as literal characters.
  List<List<dynamic>> decodeFlexible(String input) {
    final (resolved, cfg) = _resolve(input);
    return _fastDecoder.decodeFlexible(resolved, cfg);
  }

  /// Decode all fields as integers.
  ///
  /// Throws [CsvParseException] on any non-integer field. Empty fields
  /// throw too, unless [emptyAs] provides an explicit fill value.
  List<List<int>> decodeIntegers(String input, {int? emptyAs}) {
    final (resolved, cfg) = _resolve(input);
    return _fastDecoder.decodeIntegers(resolved, cfg, emptyAs: emptyAs);
  }

  /// Decode all fields as doubles.
  ///
  /// Throws [CsvParseException] on any non-double field. Empty fields
  /// throw too, unless [emptyAs] provides an explicit fill value.
  List<List<double>> decodeDoubles(String input, {double? emptyAs}) {
    final (resolved, cfg) = _resolve(input);
    return _fastDecoder.decodeDoubles(resolved, cfg, emptyAs: emptyAs);
  }

  /// Decode all fields as booleans.
  ///
  /// Truth table (case-insensitive): `true`/`1` and `false`/`0`. Anything
  /// else throws [CsvParseException]. Empty fields throw too, unless
  /// [emptyAs] provides an explicit fill value.
  List<List<bool>> decodeBooleans(String input, {bool? emptyAs}) {
    final (resolved, cfg) = _resolve(input);
    return _fastDecoder.decodeBooleans(resolved, cfg, emptyAs: emptyAs);
  }

  // ---------------------------------------------------------------------------
  // Batch decode from bytes
  // ---------------------------------------------------------------------------

  /// Decode CSV [bytes] to a list of rows.
  ///
  /// This is the entry point for the bytes Flutter hands you: `PlatformFile.bytes`
  /// from a file picker, `rootBundle.load()` for a bundled asset, or an HTTP
  /// response body. It decodes the bytes with [charset] and then follows the
  /// same path as [decode], so the byte order mark, the `sep=` hint, and
  /// delimiter auto-detection are all handled.
  ///
  /// [charset] defaults to [CsvCharset.utf8]. Pass [CsvCharset.windows1252] for
  /// a file exported by Excel on Windows that is not UTF-8.
  List<List<dynamic>> decodeBytes(
    List<int> bytes, {
    CsvCharset charset = CsvCharset.utf8,
  }) {
    return decode(charset.decodeBytes(bytes));
  }

  /// Decode CSV [bytes] with the first row as headers. Returns [CsvRow] objects.
  ///
  /// See [decodeBytes] for how [charset] is applied.
  List<CsvRow> decodeBytesWithHeaders(
    List<int> bytes, {
    CsvCharset charset = CsvCharset.utf8,
  }) {
    return decodeWithHeaders(charset.decodeBytes(bytes));
  }

  /// Decode CSV [bytes] into a [CsvTable] with headers.
  ///
  /// See [decodeBytes] for how [charset] is applied.
  CsvTable decodeBytesToTable(
    List<int> bytes, {
    CsvCharset charset = CsvCharset.utf8,
  }) {
    return decodeToTable(charset.decodeBytes(bytes));
  }

  /// Decode CSV [bytes] into a list of maps keyed by header name.
  ///
  /// Together with `dart:convert`'s `jsonEncode` this is the whole of a CSV to
  /// JSON conversion. See [decodeBytes] for how [charset] is applied.
  List<Map<String, dynamic>> decodeBytesToMaps(
    List<int> bytes, {
    CsvCharset charset = CsvCharset.utf8,
  }) {
    return decodeToMaps(charset.decodeBytes(bytes));
  }

  // ---------------------------------------------------------------------------
  // Batch encode
  // ---------------------------------------------------------------------------

  /// Encode rows to UTF-8 CSV bytes.
  ///
  /// The counterpart to [decodeBytes], for handing a file straight to
  /// `File.writeAsBytes`, a web download, or an HTTP request body. When
  /// [CsvConfig.addBom] is set the returned bytes start with the UTF-8 byte
  /// order mark, which is what Excel needs to open the file as UTF-8.
  Uint8List encodeToBytes(List<List<dynamic>> rows) {
    return utf8.encode(encode(rows));
  }

  /// Encode rows to CSV string.
  String encode(List<List<dynamic>> rows) {
    return _fastEncoder.encode(rows, config);
  }

  /// Encode all-string data (optimized fast path).
  String encodeStrings(List<List<String>> rows) {
    return _fastEncoder.encodeStrings(rows, config);
  }

  /// Encode uniform-typed data (no quoting). Ideal for numeric/bool grids.
  String encodeGeneric<T>(List<List<T>> rows) {
    return _fastEncoder.encodeGeneric<T>(rows, config);
  }

  // ---------------------------------------------------------------------------
  // Decode to table
  // ---------------------------------------------------------------------------

  /// Decode CSV string into a [CsvTable] with headers.
  ///
  /// The first row is always the header row and is read as raw strings;
  /// data rows follow [CsvConfig.dynamicTyping]. Single pass.
  CsvTable decodeToTable(String input) {
    final (resolved, cfg) = _resolve(input);
    final decoded = _fastDecoder.decodeWithHeaders(resolved, cfg);
    // Both lists are freshly allocated by the decoder, so the no-copy
    // constructor is safe here.
    return CsvTable.internal(decoded.headers, decoded.rows);
  }

  /// Decode CSV string into a list of maps keyed by header name.
  ///
  /// The first row supplies the keys; each later row becomes a
  /// `Map<String, dynamic>` whose values follow [CsvConfig.dynamicTyping].
  /// A convenience wrapper over [decodeToTable] and `CsvTable.toMaps`.
  List<Map<String, dynamic>> decodeToMaps(String input) {
    return decodeToTable(input).toMaps();
  }

  /// Decode CSV string into a [CsvTable] whose columns are coerced to the types
  /// declared in [schema].
  ///
  /// Parses with headers (like [decodeToTable]), then applies
  /// [CsvTable.coerce]: every column named in [schema] has its values converted
  /// to the declared type (`int`, `double`, `num`, `bool`, `String`, or
  /// `DateTime`). Throws [CsvParseException] when a value cannot be converted,
  /// or when a null appears in a column declared `nullable: false`.
  CsvTable decodeWithSchema(String input, CsvSchema schema) {
    return decodeToTable(input).coerce(schema);
  }

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  /// Streaming decoder for use with `Stream.transform()`.
  CsvDecoder get decoder => CsvDecoder(config);

  /// Streaming encoder for use with `Stream.transform()`.
  CsvEncoder get encoder => CsvEncoder(config);

  // ---------------------------------------------------------------------------
  // dart:convert Codec adapter
  // ---------------------------------------------------------------------------

  /// Returns a `dart:convert` compatible [Codec] for pipeline use (`.fuse()`).
  CsvCodecAdapter asCodec() => CsvCodecAdapter(config);

  // ---------------------------------------------------------------------------
  // Map conversion
  // ---------------------------------------------------------------------------

  /// Encode a Map as two-column CSV (key, value).
  String encodeMap(Map<String, dynamic> map) {
    return _fastEncoder.encodeMap(map, config);
  }

  /// Decode two-column CSV into Map.
  Map<String, dynamic> decodeMap(String input) {
    final rows = decode(input);
    final map = <String, dynamic>{};
    for (final row in rows) {
      if (row.length >= 2) {
        map[row[0].toString()] = row[1];
      }
    }
    return map;
  }
}

/// Default codec instance with standard settings.
const csvPlus = CsvCodec();

/// Excel-compatible codec instance.
const csvExcel = CsvCodec.excel();

/// Tab-separated codec instance.
const csvTsv = CsvCodec.tsv();
