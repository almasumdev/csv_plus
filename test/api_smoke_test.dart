/// Smoke test: verify every public API function is callable.
/// This is NOT a correctness test; it just confirms the API surface compiles
/// and every method is accessible from a single import.
library;

import 'package:csv_plus/csv_plus.dart';
import 'package:csv_plus/decoder.dart';
import 'package:test/test.dart';

void main() {
  const csv = 'name,age,active\nAlice,30,true\nBob,25,false\n';
  const csvNoHeader = 'Alice,30,true\nBob,25,false\n';

  group('CsvConfig', () {
    test('constructors and presets', () {
      const c1 = CsvConfig();
      const c2 = CsvConfig.excel();
      const c3 = CsvConfig.tsv();
      const c4 = CsvConfig.pipe();
      final c5 = c1.copyWith(fieldDelimiter: ';');
      expect(c1.fieldDelimiter, ',');
      expect(c2.fieldDelimiter, ';');
      expect(c3.fieldDelimiter, '\t');
      expect(c4.fieldDelimiter, '|');
      expect(c5.fieldDelimiter, ';');
    });

    test('needsQuoting static method', () {
      expect(CsvConfig.needsQuoting('hello', ',', '"'), false);
      expect(CsvConfig.needsQuoting('hel,lo', ',', '"'), true);
      expect(CsvConfig.needsQuoting('', ',', '"'), true);
    });
  });

  group('QuoteMode', () {
    test('all values accessible', () {
      expect(QuoteMode.values, hasLength(3));
      expect(QuoteMode.necessary, isNotNull);
      expect(QuoteMode.always, isNotNull);
      expect(QuoteMode.strings, isNotNull);
    });
  });

  group('CsvException hierarchy', () {
    test('all exceptions constructable', () {
      const e1 = CsvException('test');
      const e2 = CsvParseException('test', row: 1, column: 2, offset: 3);
      const e3 = CsvValidationException('test',
          columnName: 'a', rowIndex: 0, value: 'x', constraint: 'type');
      expect(e1.toString(), contains('CsvException'));
      expect(e2.toString(), contains('row: 1'));
      expect(e3.toString(), contains('column: "a"'));
    });
  });

  group('CsvCodec Facade', () {
    test('constructors', () {
      const c1 = CsvCodec();
      const c2 = CsvCodec.excel();
      const c3 = CsvCodec.tsv();
      const c4 = CsvCodec.pipe();
      expect(c1.config.fieldDelimiter, ',');
      expect(c2.config.fieldDelimiter, ';');
      expect(c3.config.fieldDelimiter, '\t');
      expect(c4.config.fieldDelimiter, '|');
    });

    test('decode methods', () {
      final codec = CsvCodec(const CsvConfig(hasHeader: true));
      expect(codec.decode(csv), isNotEmpty);
      expect(codec.decodeWithHeaders(csv), isNotEmpty);
      expect(codec.decodeStrings(csv), isNotEmpty);
      expect(codec.decodeFlexible(csv), isNotEmpty);
    });

    test('typed decoders', () {
      final codec = CsvCodec();
      expect(codec.decodeIntegers('1,2\n3,4'), isNotEmpty);
      expect(codec.decodeDoubles('1.1,2.2\n3.3,4.4'), isNotEmpty);
      expect(codec.decodeBooleans('true,false\ntrue,true'), isNotEmpty);
    });

    test('encode methods', () {
      final codec = CsvCodec();
      expect(
          codec.encode([
            ['a', 1]
          ]),
          isNotEmpty);
      expect(
          codec.encodeStrings([
            ['a', 'b']
          ]),
          isNotEmpty);
      expect(
          codec.encodeGeneric([
            [1, 2]
          ]),
          isNotEmpty);
    });

    test('table and map methods', () {
      final codec = CsvCodec();
      expect(codec.decodeToTable(csv), isA<CsvTable>());
      expect(codec.encodeMap({'a': 1, 'b': 2}), isNotEmpty);
      expect(codec.decodeMap('"a",1\n"b",2'), isA<Map>());
    });

    test('streaming accessors', () {
      final codec = CsvCodec();
      expect(codec.decoder, isA<CsvDecoder>());
      expect(codec.encoder, isA<CsvEncoder>());
      expect(codec.asCodec(), isA<CsvCodecAdapter>());
    });

    test('top-level constants', () {
      expect(csvPlus, isA<CsvCodec>());
      expect(csvExcel, isA<CsvCodec>());
      expect(csvTsv, isA<CsvCodec>());
    });
  });

  group('CsvCodecAdapter (dart:convert)', () {
    test('codec interface', () {
      final adapter = CsvCodecAdapter();
      final encoded = adapter.encoder.convert([
        ['a', 'b'],
        [1, 2]
      ]);
      final decoded = adapter.decoder.convert(encoded);
      expect(decoded, isNotEmpty);
    });
  });

  group('FastEncoder', () {
    test('all encode methods', () {
      const enc = FastEncoder();
      const cfg = CsvConfig();
      expect(
          enc.encode([
            ['a', 1]
          ], cfg),
          isNotEmpty);
      expect(
          enc.encodeStrings([
            ['a', 'b']
          ], cfg),
          isNotEmpty);
      expect(
          enc.encodeGeneric([
            [1, 2]
          ], cfg),
          isNotEmpty);
      expect(enc.encodeMap({'key': 'val'}, cfg), isNotEmpty);
    });
  });

  group('CsvEncoder (streaming)', () {
    test('convert and encodeField', () {
      const enc = CsvEncoder();
      expect(
          enc.convert([
            ['a', 'b']
          ]),
          isNotEmpty);
      expect(
        CsvEncoder.encodeField('hello, world',
            fieldDelimiter: ',',
            quoteCharacter: '"',
            escapeCharacter: '"',
            quoteMode: QuoteMode.necessary),
        contains('"'),
      );
    });
  });

  group('FastDecoder', () {
    test('decode and decodeStrings', () {
      const dec = FastDecoder();
      const cfg = CsvConfig();
      expect(dec.decode(csvNoHeader, cfg), isNotEmpty);
      expect(dec.decodeStrings(csvNoHeader, cfg), isNotEmpty);
    });

    test('public static utilities', () {
      expect(FastDecoder.inferType('42'), 42);
      expect(FastDecoder.inferType('true'), true);
      expect(FastDecoder.inferType('hello'), 'hello');
    });

    test('extension methods (flexible, typed)', () {
      const dec = FastDecoder();
      const cfg = CsvConfig();
      expect(dec.decodeFlexible(csvNoHeader, cfg), isNotEmpty);
      expect(dec.decodeIntegers('1,2\n3,4', cfg), isNotEmpty);
      expect(dec.decodeDoubles('1.0,2.0', cfg), isNotEmpty);
      expect(dec.decodeBooleans('true,false', cfg), isNotEmpty);
    });
  });

  group('CsvDecoder (streaming)', () {
    test('convert and bind', () async {
      const dec = CsvDecoder();
      expect(dec.convert('a,b\n1,2'), isNotEmpty);

      final stream = Stream.fromIterable(['a,b\n', '1,2']);
      final rows = await dec.bind(stream).toList();
      expect(rows, hasLength(2));
    });
  });

  group('DelimiterDetector', () {
    test('detect and utilities', () {
      const det = DelimiterDetector();
      expect(det.detectDelimiter('a;b;c\n1;2;3'), ';');
      final (stripped, hadBom) = det.stripBom('\uFEFFhello');
      expect(stripped, 'hello');
      expect(hadBom, true);
      final (remaining, hint) = det.checkSepHint('sep=;\na;b');
      expect(hint, ';');
      expect(remaining, isNotEmpty);
    });
  });

  group('CsvTable', () {
    test('constructors', () {
      final t1 = CsvTable([
        ['a', 1],
        ['b', 2]
      ]);
      final t2 = CsvTable.withHeaders([
        ['name', 'age'],
        ['Alice', 30]
      ]);
      final t3 = CsvTable.fromData(headers: [
        'name'
      ], rows: [
        ['Alice'],
        ['Bob']
      ]);
      final t4 = CsvTable.fromMaps([
        {'name': 'Alice'},
        {'name': 'Bob'}
      ]);
      final t5 = CsvTable.parse(csv);
      final t6 = CsvTable.empty(headers: ['a', 'b']);
      expect(t1.rowCount, 2);
      expect(t2.hasHeaders, true);
      expect(t3.headers, ['name']);
      expect(t4.rowCount, 2);
      expect(t5.rowCount, greaterThan(0));
      expect(t6.isEmpty, true);
    });

    test('properties', () {
      final t = CsvTable.parse(csv);
      expect(t.hasHeaders, true);
      expect(t.rowCount, greaterThan(0));
      expect(t.columnCount, 3);
      expect(t.isEmpty, false);
      expect(t.isNotEmpty, true);
    });

    test('row access', () {
      final t = CsvTable.parse(csv);
      expect(t[0], isA<CsvRow>());
      expect(t.first, isA<CsvRow>());
      expect(t.last, isA<CsvRow>());
      expect(t.rows, isNotEmpty);
    });

    test('column access', () {
      final t = CsvTable.parse(csv);
      expect(t.column('name'), isNotEmpty);
      expect(t.columnAt(0), isNotEmpty);
      expect(t.getColumn('name'), isA<CsvColumn>());
      expect(t.getColumnAt(0), isA<CsvColumn>());
    });

    test('cell access', () {
      final t = CsvTable.parse(csv);
      expect(t.cell(0, 0), isNotNull);
      expect(t.cellByName(0, 'name'), isNotNull);
      t.setCell(0, 0, 'changed');
      expect(t.cell(0, 0), 'changed');
      t.setCellByName(0, 'name', 'restored');
      expect(t.cellByName(0, 'name'), 'restored');
    });

    test('row manipulation', () {
      final t = CsvTable.parse(csv);
      final count = t.rowCount;
      t.addRow(['Charlie', 35, true]);
      expect(t.rowCount, count + 1);
      t.addRowFromMap({'name': 'Dave', 'age': 40, 'active': false});
      expect(t.rowCount, count + 2);
      t.insertRow(0, ['First', 0, false]);
      expect(t.rowCount, count + 3);
      t.removeRow(0);
      expect(t.rowCount, count + 2);
      t.addRows([
        ['E', 1, true],
        ['F', 2, false]
      ]);
      t.removeWhere((row) => row['name'] == 'E');
    });

    test('conversion', () {
      final t = CsvTable.parse(csv);
      expect(t.toList(), isNotEmpty);
      expect(t.toList(includeHeaders: true).first, ['name', 'age', 'active']);
      expect(t.toMaps(), isNotEmpty);
      expect(t.toCsv(), isNotEmpty);
      expect(t.copy(), isA<CsvTable>());
    });

    test('schema and validation', () {
      final t = CsvTable.parse(csv);
      final schema = t.inferSchema();
      expect(schema, isA<CsvSchema>());
      expect(t.validate(schema), isEmpty);
      expect(t.conformsTo(schema), true);
    });

    test('display', () {
      final t = CsvTable.parse(csv);
      expect(t.toString(), isNotEmpty);
      expect(t.toFormattedString(), contains('name'));
    });

    test('iterator', () {
      final t = CsvTable.parse(csv);
      var count = 0;
      final iter = t.iterator;
      while (iter.moveNext()) {
        expect(iter.current, isA<CsvRow>());
        count++;
      }
      expect(count, t.rowCount);
      // Also test via rows getter
      for (final row in t.rows) {
        expect(row, isA<CsvRow>());
      }
    });
  });

  group('CsvRow', () {
    test('positional and named access', () {
      final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
      expect(row[0], 'Alice');
      expect(row['name'], 'Alice');
      expect(row[1], 30);
      expect(row['age'], 30);
      row[0] = 'Bob';
      expect(row[0], 'Bob');
      row.set('age', 40);
      expect(row['age'], 40);
    });

    test('header queries', () {
      final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
      expect(row.hasHeaders, true);
      expect(row.headers, ['name', 'age']);
      expect(row.containsHeader('name'), true);
      expect(row.containsHeader('foo'), false);
      expect(row.getHeaderName(0), 'name');
    });

    test('conversion', () {
      final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
      expect(row.toMap(), {'name': 'Alice', 'age': 30});
      expect(row.length, 2);
    });
  });

  group('CsvColumn', () {
    test('properties', () {
      final col = CsvColumn(name: 'age', index: 1, values: [30, null, 25]);
      expect(col.name, 'age');
      expect(col.index, 1);
      expect(col.values, [30, null, 25]);
      expect(col.nonNullCount, 2);
      expect(col.nullCount, 1);
      expect(col.uniqueCount, 3); // 30, null, 25 are all distinct
      expect(col.inferredType, int);
    });
  });

  group('CsvSchema', () {
    test('infer and validate', () {
      final schema = CsvSchema.infer(
        ['name', 'age'],
        [
          ['Alice', 30],
          ['Bob', 25]
        ],
      );
      expect(schema.columns, hasLength(2));
      final errors = schema.validate(
        ['name', 'age'],
        [
          ['Alice', 30]
        ],
      );
      expect(errors, isEmpty);
    });

    test('CsvColumnDef', () {
      const col = CsvColumnDef(name: 'age', type: int, required: true);
      expect(col.name, 'age');
      expect(col.type, int);
      expect(col.required, true);
    });
  });

  group('Query Filtering', () {
    test('all filter methods', () {
      final t = CsvTable.parse(csv);
      expect(t.where((row) => row['name'] == 'Alice').rowCount, 1);
      expect(t.firstWhere((row) => row['name'] == 'Alice'), isNotNull);
      expect(t.any((row) => row['name'] == 'Alice'), true);
      expect(t.every((row) => row['age'] != null), true);
      expect(t.range(0, 1).rowCount, 1);
      expect(t.take(1).rowCount, 1);
      expect(t.skip(1).rowCount, t.rowCount - 1);
      expect(t.distinct().rowCount, t.rowCount);
    });
  });

  group('Query Sorting', () {
    test('all sort methods', () {
      final t = CsvTable.parse(csv);
      t.sortBy('name');
      expect(t[0]['name'], 'Alice');
      t.sortByIndex(0, ascending: false);
      expect(t[0]['name'], 'Bob');
      t.sortByMultiple([('name', true)]);
      t.sort((a, b) => (a['age'] as int).compareTo(b['age'] as int));
    });
  });

  group('Transform Manipulation', () {
    test('column operations', () {
      final t = CsvTable.parse(csv);
      t.addColumn('score', defaultValue: 0);
      expect(t.headers.contains('score'), true);
      t.insertColumn(0, 'id', defaultValue: 1);
      expect(t.headers.first, 'id');
      t.renameColumn('score', 'points');
      expect(t.headers.contains('points'), true);
      t.transformColumn('points', (v) => 100);
      expect(t.cell(0, t.headers.indexOf('points')), 100);
      t.removeColumn('points');
      expect(t.headers.contains('points'), false);
      t.removeColumnAt(0); // remove 'id'
      t.reorderColumns(['active', 'age', 'name']);
      expect(t.headers, ['active', 'age', 'name']);
    });

    test('row operations', () {
      final t = CsvTable.parse(csv);
      final mapped = t.map((row) => row);
      expect(mapped.rowCount, t.rowCount);
      final sum = t.fold<int>(0, (acc, row) => acc + (row['age'] as int));
      expect(sum, greaterThan(0));
    });
  });

  group('Transform Aggregation', () {
    test('all aggregation methods', () {
      final t = CsvTable.parse(csv);
      expect(t.count('name'), t.rowCount);
      expect(t.sum('age'), greaterThan(0));
      expect(t.avg('age'), greaterThan(0));
      expect(t.min('age'), isNotNull);
      expect(t.max('age'), isNotNull);
      final groups = t.groupBy('active');
      expect(groups, isNotEmpty);
      expect(groups.values.first, isA<CsvTable>());
    });
  });
}
