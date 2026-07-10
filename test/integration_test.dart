import 'package:csv_plus/csv_plus.dart';
import 'package:csv_plus/decoder.dart';
import 'package:test/test.dart';

void main() {
  group('Round-trip integration', () {
    test('encode then decode preserves data types', () {
      final codec = CsvCodec();
      final original = [
        ['name', 'age', 'score', 'active'],
        ['Alice', 30, 95.5, true],
        ['Bob', 25, 88.0, false],
        ['Charlie', 35, 72.3, true],
      ];
      final csv = codec.encode(original);
      final decoded = codec.decode(csv);
      expect(decoded, original);
    });

    test('encode then decode with null values', () {
      final codec = CsvCodec();
      final original = [
        ['a', 'b'],
        [1, null],
        [null, 2],
      ];
      final csv = codec.encode(original);
      final decoded = codec.decode(csv);
      expect(decoded, original);
    });

    test('encode then decode with quoted strings', () {
      final codec = CsvCodec();
      final original = [
        ['has,comma', 'has"quote', 'has\nnewline'],
        ['normal', 'also "normal"', 'ok'],
      ];
      final csv = codec.encode(original);
      final decoded = codec.decode(csv);
      expect(decoded, original);
    });

    test('encode strings then decode strings round-trip', () {
      final codec = CsvCodec();
      final original = [
        ['Alice', '30', '95.5'],
        ['Bob', '25', '88.0'],
      ];
      final csv = codec.encodeStrings(original);
      final decoded = codec.decodeStrings(csv);
      expect(decoded, original);
    });

    test('CsvTable round-trip through CSV string', () {
      final table = CsvTable.fromData(
        headers: ['name', 'age', 'score'],
        rows: [
          ['Alice', 30, 95.5],
          ['Bob', 25, 88.0],
        ],
      );
      final csv = table.toCsv();
      final restored = CsvTable.parse(csv);
      expect(restored.headers, table.headers);
      expect(restored.rowCount, table.rowCount);
      for (var i = 0; i < table.rowCount; i++) {
        expect(restored[i].toList(), table[i].toList());
      }
    });

    test('CsvTable fromMaps then toMaps round-trip', () {
      final maps = [
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
      ];
      final table = CsvTable.fromMaps(maps);
      final result = table.toMaps();
      expect(result, maps);
    });

    test('stream encode then stream decode round-trip', () async {
      final config = const CsvConfig();
      final rows = [
        ['a', 'b'],
        [1, 2],
        [3, 4],
      ];
      final encoder = CsvEncoder(config);
      final decoder = CsvDecoder(config);

      final rowStream = Stream.fromIterable(rows);
      final csvStream = encoder.bind(rowStream);
      final decodedStream = decoder.bind(csvStream);

      final result = await decodedStream.toList();
      expect(result, rows);
    });
  });

  group('Excel compatibility', () {
    test('BOM prefix', () {
      final codec = CsvCodec(const CsvConfig(addBom: true));
      final csv = codec.encode([
        ['a', 'b'],
        [1, 2],
      ]);
      expect(csv.codeUnitAt(0), 0xFEFF);
      // Decode should strip BOM
      final decoded = codec.decode(csv);
      expect(decoded, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('Excel preset with semicolons', () {
      final codec = CsvCodec.excel();
      final csv = codec.encode([
        ['name', 'value'],
        ['test', 42],
      ]);
      expect(csv.contains(';'), true);
      final decoded = codec.decode(csv);
      expect(decoded, [
        ['name', 'value'],
        ['test', 42],
      ]);
    });

    test('CRLF line endings preserved', () {
      final codec = CsvCodec();
      final csv = codec.encode([
        ['a'],
        ['b'],
      ]);
      expect(csv.contains('\r\n'), true);
    });

    test('sep= hint decoding via DelimiterDetector', () {
      final csv = 'sep=;\na;b\n1;2';
      final detector = DelimiterDetector();
      final delimiter = detector.detectDelimiter(csv);
      expect(delimiter, ';');
    });
  });

  group('TSV round-trip', () {
    test('tab-separated encode then decode', () {
      final codec = CsvCodec.tsv();
      final data = [
        ['name', 'value'],
        ['Alice', 42],
      ];
      final csv = codec.encode(data);
      expect(csv.contains('\t'), true);
      final decoded = codec.decode(csv);
      expect(decoded, data);
    });
  });

  group('Multi-char delimiter round-trip', () {
    test('pipe delimiter', () {
      final codec = CsvCodec.pipe();
      final data = [
        ['a', 'b', 'c'],
        [1, 2, 3],
      ];
      final csv = codec.encode(data);
      expect(csv.contains('|'), true);
      final decoded = codec.decode(csv);
      expect(decoded, data);
    });

    test('custom multi-char delimiter', () {
      final codec = CsvCodec(const CsvConfig(fieldDelimiter: '::'));
      final data = [
        ['a', 'b'],
        [1, 2],
      ];
      final csv = codec.encode(data);
      expect(csv.contains('::'), true);
      final decoded = codec.decode(csv);
      expect(decoded, data);
    });
  });

  group('Large dataset', () {
    test('1000 rows round-trip', () {
      final codec = CsvCodec();
      final data = List.generate(
        1000,
        (i) => [i, 'row_$i', i * 1.5, i % 2 == 0],
      );
      final csv = codec.encode(data);
      final decoded = codec.decode(csv);
      expect(decoded.length, 1000);
      expect(decoded.first, data.first);
      expect(decoded.last, data.last);
    });
  });

  group('CsvTable full workflow', () {
    test('parse, filter, sort, export pipeline', () {
      final csv = 'name,age,city\nAlice,30,NYC\nBob,25,LA\nCharlie,35,NYC';
      final table = CsvTable.parse(csv);

      // Filter
      final nyc = table.where((row) => row['city'] == 'NYC');
      expect(nyc.rowCount, 2);

      // Sort
      nyc.sortBy('age');
      expect(nyc[0]['name'], 'Alice');
      expect(nyc[1]['name'], 'Charlie');

      // Export
      final exported = nyc.toCsv();
      expect(exported.contains('Alice'), true);
      expect(exported.contains('Bob'), false);
    });

    test('schema validation integration', () {
      final table = CsvTable.fromData(
        headers: ['name', 'age'],
        rows: [
          ['Alice', 30],
          ['Bob', 25],
        ],
      );
      final schema = table.inferSchema();
      final errors = table.validate(schema);
      expect(errors, isEmpty);
    });

    test('manipulate + export round-trip', () {
      final table = CsvTable.fromData(
        headers: ['a', 'b'],
        rows: [
          [1, 2],
          [3, 4],
        ],
      );

      table.addColumn('c', defaultValue: 0);
      expect(table.columnCount, 3);

      final csv = table.toCsv();
      final restored = CsvTable.parse(csv);
      expect(restored.columnCount, 3);
      expect(restored.headers, ['a', 'b', 'c']);
    });
  });

  group('CsvCodecAdapter dart:convert integration', () {
    test('works in a pipeline with fuse', () {
      final adapter = CsvCodecAdapter();
      final encoded = adapter.encode([
        ['a', 'b'],
        [1, 2],
      ]);
      final decoded = adapter.decode(encoded);
      expect(decoded, [
        ['a', 'b'],
        [1, 2],
      ]);
    });
  });
}
