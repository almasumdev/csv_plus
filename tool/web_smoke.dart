// Web compile smoke: exercises the core encode/decode/table API with no
// `dart:io`, so the CI web-compile gate can prove csv_plus builds on both
// dart2js and wasm. Not part of the published package.
import 'package:csv_plus/csv_plus.dart';

void main() {
  const codec = CsvCodec();

  final csv = codec.encode([
    ['name', 'age', 'active'],
    ['Alice', 30, true],
    ['Bob', 25, false],
  ]);

  final rows = codec.decode(csv);
  final table = CsvTable.parse(csv);
  table.sortBy('age');

  // Touch the streaming decoder so it is not tree-shaken out of the smoke.
  final streamed = const CsvDecoder().convert(csv);

  print(
    '${rows.length} rows, ${table.rowCount} table rows, '
    '${streamed.length} streamed, avg age ${table.avg('age')}',
  );
}
