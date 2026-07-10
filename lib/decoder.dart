/// CSV decoding: batch, streaming, and auto-detection.
///
/// Two decoder implementations are provided:
///
/// - [FastDecoder]: high-performance batch decoder using byte-level
///   parsing. Supports typed output (`decode`), string-only (`decodeStrings`),
///   flexible/lenient (`decodeFlexible`), and per-type decoders
///   (`decodeIntegers`, `decodeDoubles`, `decodeBooleans`).
/// - [CsvDecoder]: streaming decoder extending `StreamTransformerBase`.
///   Handles arbitrary chunk boundaries (mid-field, mid-escape, mid-CRLF).
///
/// [DelimiterDetector] provides automatic delimiter detection by analyzing
/// the first few rows of input data.
library;

export 'src/decoder/fast_decoder.dart';
export 'src/decoder/fast_decoder_ext.dart';
export 'src/decoder/csv_decoder.dart';
export 'src/decoder/delimiter_detector.dart';
