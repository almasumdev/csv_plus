import 'package:csv_plus/csv_plus.dart';

/// Basic encoding and decoding examples.
void main() {
  // --- Encoding ---
  final csv = CsvCodec().encode([
    ['name', 'age', 'score'],
    ['Alice', 30, 95.5],
    ['Bob', 25, 88.0],
  ]);
  print('Encoded CSV:');
  print(csv);
  print('');

  // --- Decoding (with type inference) ---
  final rows = CsvCodec().decode(csv);
  print('Decoded rows:');
  for (final row in rows) {
    print('  $row (types: ${row.map((e) => e.runtimeType).toList()})');
  }
  print('');

  // --- Decode as strings only ---
  final stringRows = CsvCodec().decodeStrings(csv);
  print('String rows: $stringRows');
  print('');

  // --- Decode with headers ---
  final headerRows = CsvCodec().decodeWithHeaders(csv);
  for (final row in headerRows) {
    print('  ${row['name']} is ${row['age']} years old');
  }
  print('');

  // --- Presets ---
  print('TSV:');
  print(
    CsvCodec.tsv().encode([
      ['a', 'b'],
      [1, 2],
    ]),
  );
  print('');

  print('Excel (semicolons + BOM):');
  final excelCsv = CsvCodec.excel().encode([
    ['a', 'b'],
    [1, 2],
  ]);
  print('Has BOM: ${excelCsv.codeUnitAt(0) == 0xFEFF}');
  print(excelCsv.substring(1));
}
