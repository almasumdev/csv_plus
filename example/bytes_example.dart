import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';

/// Reading and writing CSV as bytes.
///
/// This is the shape Flutter hands you: `PlatformFile.bytes` from a file
/// picker, `rootBundle.load()` for a bundled asset, and `response.bodyBytes`
/// from an HTTP call are all byte lists, on every platform including web where
/// there is no file path to open.
void main() {
  const codec = CsvCodec();

  // --- Bytes in ---
  // Stand-in for the bytes a picker or an asset would give you.
  final picked = utf8.encode('name,qty,price\nbolt,4,0.25\nnut,10,0.05\n');

  final rows = codec.decodeBytes(picked);
  print('Rows from bytes:');
  for (final row in rows) {
    print('  $row');
  }
  print('');

  // The byte order mark, the `sep=` hint and delimiter detection are all
  // handled on the way in, exactly as they are for a string.
  final excelExport = utf8.encode('\u{FEFF}sep=;\nname;qty\nbolt;4\n');
  print('Excel style export: ${codec.decodeBytes(excelExport)}');
  print('');

  // --- Straight to maps, which is most of a CSV to JSON conversion ---
  final maps = codec.decodeBytesToMaps(picked);
  print('As JSON: ${jsonEncode(maps)}');
  print('');

  // --- A table, for querying and validating ---
  final table = codec.decodeBytesToTable(picked);
  print('Columns: ${table.headers}, total qty ${table.sum('qty')}');
  print('');

  // --- Files that are not UTF-8 ---
  // Excel on Western European Windows writes Windows-1252, not UTF-8, so an
  // accented name or a currency symbol arrives as a byte UTF-8 cannot read.
  // 0xE9 is an e with an acute accent, 0x80 is the euro sign.
  final windowsExport = <int>[
    ...'name;price\n'.codeUnits,
    0x4A, 0x6F, 0x73, 0xE9, // Jose
    0x3B, // ;
    0x80, 0x35, // euro sign, 5
    0x0A,
  ];
  print('As UTF-8    : ${codec.decodeBytes(windowsExport)}');
  print(
    'As cp1252   : '
    '${codec.decodeBytes(windowsExport, charset: CsvCharset.windows1252)}',
  );
  print('');

  // --- Bytes out ---
  // Hand these to File.writeAsBytes, a web download, or an HTTP body.
  final out = codec.encodeToBytes([
    ['name', 'note'],
    ['bolt', 'a, b'],
    ['nut', 'says "hi"'],
  ]);
  print(
    'Encoded ${out.length} bytes, round-trips to ${codec.decodeBytes(out)}',
  );

  // Excel needs a byte order mark to open the file as UTF-8.
  const forExcel = CsvCodec(CsvConfig(addBom: true));
  final withBom = forExcel.encodeToBytes([
    ['name', 'price'],
    ['caf\u{E9}', 3.5],
  ]);
  print('First three bytes with addBom: ${withBom.take(3).toList()}');
}
