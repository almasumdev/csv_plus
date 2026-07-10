/// Core types and configuration for csv_plus.
///
/// Contains the shared foundation used across all layers:
///
/// - [CsvConfig]: immutable configuration with presets
///   ([CsvConfig.excel], [CsvConfig.tsv], [CsvConfig.pipe]).
/// - [QuoteMode]: controls when fields are quoted during encoding.
/// - [CsvException], [CsvParseException], [CsvValidationException]:
///   typed exception hierarchy.
library;

export 'src/core/csv_config.dart';
export 'src/core/csv_exception.dart';
export 'src/core/quote_mode.dart';
