/// Complete, high-performance CSV package for Dart.
///
/// This is the main entry point: a single import gives access to
/// encoding, decoding, table manipulation, querying, and transforms.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:csv_plus/csv_plus.dart';
///
/// // Encode
/// final csv = CsvCodec().encode([['name', 'age'], ['Alice', 30]]);
///
/// // Decode with type inference
/// final rows = CsvCodec().decode(csv); // [['name', 'age'], ['Alice', 30]]
///
/// // Full table manipulation
/// final table = CsvTable.parse(csv);
/// table.sortBy('age');
/// table.where((row) => row['age'] > 25);
/// print(table.avg('age'));
/// ```
///
/// ## Library Modules
///
/// For selective imports, use the individual library files:
///
/// | Library | Import |
/// |---------|--------|
/// | Core config & exceptions | `package:csv_plus/core.dart` |
/// | Codec facade | `package:csv_plus/codec.dart` |
/// | Encoders | `package:csv_plus/encoder.dart` |
/// | Decoders | `package:csv_plus/decoder.dart` |
/// | Table & schema | `package:csv_plus/table.dart` |
/// | Filtering & sorting | `package:csv_plus/query.dart` |
/// | Manipulation & aggregation | `package:csv_plus/transform.dart` |
/// | File I/O (dart:io) | `package:csv_plus/io.dart` |
///
/// ## File I/O
///
/// File operations require `dart:io` and must be imported separately:
///
/// ```dart
/// import 'package:csv_plus/io.dart';
///
/// final table = await CsvFile.read('data.csv');
/// ```
library;

// Core
export 'src/core/csv_config.dart';
export 'src/core/csv_exception.dart';
export 'src/core/quote_mode.dart';

// Codec
export 'src/codec/csv_codec.dart';
export 'src/codec/codec_adapter.dart';

// Encoder
export 'src/encoder/fast_encoder.dart';
export 'src/encoder/csv_encoder.dart';

// Decoder. DelimiterDetector is an implementation detail of autodetect
// and stays out of the default namespace; import
// `package:csv_plus/decoder.dart` to use it directly.
export 'src/decoder/fast_decoder.dart';
export 'src/decoder/fast_decoder_ext.dart';
export 'src/decoder/csv_decoder.dart';

// Table
export 'src/table/csv_row.dart';
export 'src/table/csv_column.dart';
export 'src/table/csv_schema.dart';
export 'src/table/csv_table.dart';

// Query
export 'src/query/filtering.dart';
export 'src/query/sorting.dart';

// Transform
export 'src/transform/manipulation.dart';
export 'src/transform/aggregation.dart';

// I/O (dart:io; import separately: `import 'package:csv_plus/io.dart';`)
