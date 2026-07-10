import 'package:csv_plus/csv_plus.dart';
import 'package:csv_plus/decoder.dart';

/// Advanced features: flexible decoding, type-specific decoding,
/// schema validation, codec adapter.
void main() {
  // --- Flexible decoding (lenient mode) ---
  print('=== Flexible Decoding ===');
  final messy = '  Alice , 30 \n  Bob , 25 ';
  final rows = CsvCodec().decodeFlexible(messy);
  print('Flexible: $rows');
  print('');

  // --- Type-specific decoding ---
  print('=== Type-Specific Decoding ===');
  final intCsv = '1,2,3\n4,5,6';
  final ints = CsvCodec().decodeIntegers(intCsv);
  print('Integers: $ints');

  final doubleCsv = '1.5,2.5\n3.5,4.5';
  final doubles = CsvCodec().decodeDoubles(doubleCsv);
  print('Doubles: $doubles');
  print('');

  // --- Schema validation ---
  print('=== Schema Validation ===');
  final schema = CsvSchema(
    columns: [
      CsvColumnDef(name: 'name', type: String, required: true, nullable: false),
      CsvColumnDef(name: 'age', type: int, required: true, nullable: false),
    ],
  );

  final table = CsvTable.fromData(
    headers: ['name', 'age'],
    rows: [
      ['Alice', 30],
      ['Bob', null], // Invalid: age is non-nullable
    ],
  );

  final errors = table.validate(schema);
  print('Validation errors: ${errors.length}');
  for (final e in errors) {
    print('  ${e.message}');
  }
  print('');

  // --- dart:convert Codec adapter ---
  print('=== Codec Adapter ===');
  final adapter = CsvCodecAdapter();
  final encoded = adapter.encode([
    ['a', 'b'],
    [1, 2],
  ]);
  print('Encoded: $encoded');
  final decoded = adapter.decode(encoded);
  print('Decoded: $decoded');
  print('');

  // --- Delimiter detection ---
  print('=== Delimiter Detection ===');
  final tsvData = 'a\tb\n1\t2';
  // Use auto-detect config to detect TSV
  final detected = DelimiterDetector().detectDelimiter(tsvData);
  print('Detected delimiter: ${detected == '\t' ? 'TAB' : detected}');
}
