/// CSV encoding: batch and streaming.
///
/// Two encoder implementations are provided:
///
/// - [FastEncoder]: high-performance batch encoder. Used internally by
///   [CsvCodec] for `encode()`, `encodeStrings()`, `encodeGeneric()`, and
///   `encodeMap()`.
/// - [CsvEncoder]: streaming encoder extending `StreamTransformerBase`.
///   Supports `convert()`, `bind()`, and `startChunkedConversion()` for
///   `dart:convert` pipeline compatibility.
library;

export 'src/encoder/fast_encoder.dart';
export 'src/encoder/csv_encoder.dart';
