import 'dart:convert';

import '../core/csv_config.dart';
import '../decoder/csv_decoder.dart' as csv_dec;
import '../encoder/csv_encoder.dart' as csv_enc;

/// A `dart:convert` compatible [Codec] for CSV data.
///
/// Enables `.fuse()` and other `dart:convert` pipeline operations.
///
/// ```dart
/// final codec = CsvCodecAdapter();
/// final rows = codec.decode('a,b\n1,2');
/// final csv = codec.encode([[1, 2], [3, 4]]);
/// ```
class CsvCodecAdapter extends Codec<List<List<dynamic>>, String> {
  /// Configuration applied to both directions of this codec.
  final CsvConfig config;

  /// Create an adapter with the given [config] (defaults to standard CSV).
  CsvCodecAdapter([this.config = const CsvConfig()]);

  @override
  Converter<String, List<List<dynamic>>> get decoder =>
      _CsvConverterDecoder(config);

  @override
  Converter<List<List<dynamic>>, String> get encoder =>
      _CsvConverterEncoder(config);
}

class _CsvConverterDecoder extends Converter<String, List<List<dynamic>>> {
  final CsvConfig config;
  const _CsvConverterDecoder(this.config);

  @override
  List<List<dynamic>> convert(String input) {
    return csv_dec.CsvDecoder(config).convert(input);
  }

  @override
  Stream<List<List<dynamic>>> bind(Stream<String> stream) {
    return csv_dec.CsvDecoder(config).bind(stream).map((row) => [row]);
  }
}

class _CsvConverterEncoder extends Converter<List<List<dynamic>>, String> {
  final CsvConfig config;
  const _CsvConverterEncoder(this.config);

  @override
  String convert(List<List<dynamic>> input) {
    return csv_enc.CsvEncoder(config).convert(input);
  }

  @override
  Stream<String> bind(Stream<List<List<dynamic>>> stream) {
    // Flatten batches into individual rows for the streaming encoder.
    final flatStream = stream.expand<List<dynamic>>((batch) => batch);
    return csv_enc.CsvEncoder(config).bind(flatStream);
  }
}
