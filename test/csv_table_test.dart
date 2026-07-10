import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvTable', () {
    group('constructors', () {
      test('CsvTable() from raw rows', () {
        final table = CsvTable([
          [1, 2],
          [3, 4],
        ]);
        expect(table.rowCount, 2);
        expect(table.hasHeaders, false);
        expect(table.cell(0, 0), 1);
      });

      test('CsvTable.withHeaders()', () {
        final table = CsvTable.withHeaders([
          ['name', 'age'],
          ['Alice', 30],
        ]);
        expect(table.headers, ['name', 'age']);
        expect(table.rowCount, 1);
        expect(table.cell(0, 0), 'Alice');
      });

      test('CsvTable.fromData()', () {
        final table = CsvTable.fromData(
          headers: ['a', 'b'],
          rows: [
            [1, 2],
          ],
        );
        expect(table.headers, ['a', 'b']);
        expect(table.rowCount, 1);
      });

      test('CsvTable.fromMaps()', () {
        final table = CsvTable.fromMaps([
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ]);
        expect(table.headers, ['name', 'age']);
        expect(table.rowCount, 2);
        expect(table.cell(0, 0), 'Alice');
      });

      test('CsvTable.fromMaps() with empty list', () {
        final table = CsvTable.fromMaps([]);
        expect(table.rowCount, 0);
        expect(table.headers, isEmpty);
      });

      test('CsvTable.parse()', () {
        final table = CsvTable.parse('name,age\nAlice,30\nBob,25');
        expect(table.headers, ['name', 'age']);
        expect(table.rowCount, 2);
      });

      test('CsvTable.parse() empty', () {
        final table = CsvTable.parse('');
        expect(table.rowCount, 0);
      });

      test('CsvTable.empty()', () {
        final table = CsvTable.empty(headers: ['a', 'b']);
        expect(table.headers, ['a', 'b']);
        expect(table.rowCount, 0);
      });
    });

    group('properties', () {
      test('columnCount from headers', () {
        final table = CsvTable.fromData(headers: ['a', 'b', 'c'], rows: []);
        expect(table.columnCount, 3);
      });

      test('columnCount from data', () {
        final table = CsvTable([
          [1, 2, 3],
        ]);
        expect(table.columnCount, 3);
      });

      test('isEmpty / isNotEmpty', () {
        final empty = CsvTable([]);
        final full = CsvTable([
          [1],
        ]);
        expect(empty.isEmpty, true);
        expect(empty.isNotEmpty, false);
        expect(full.isEmpty, false);
        expect(full.isNotEmpty, true);
      });
    });

    group('row access', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
            ['Bob', 25],
          ],
        );
      });

      test('operator []', () {
        final row = table[0];
        expect(row[0], 'Alice');
        expect(row['name'], 'Alice');
      });

      test('operator []=', () {
        table[0] = ['Charlie', 35];
        expect(table.cell(0, 0), 'Charlie');
      });

      test('rows getter', () {
        expect(table.rows.length, 2);
        expect(table.rows[0]['name'], 'Alice');
      });

      test('first and last', () {
        expect(table.first['name'], 'Alice');
        expect(table.last['name'], 'Bob');
      });
    });

    group('column access', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
            ['Bob', 25],
          ],
        );
      });

      test('column() by name', () {
        expect(table.column('name'), ['Alice', 'Bob']);
      });

      test('columnAt() by index', () {
        expect(table.columnAt(1), [30, 25]);
      });

      test('getColumn()', () {
        final col = table.getColumn('age');
        expect(col.name, 'age');
        expect(col.index, 1);
        expect(col.values, [30, 25]);
      });

      test('getColumnAt()', () {
        final col = table.getColumnAt(0);
        expect(col.name, 'name');
        expect(col.nonNullCount, 2);
      });

      test('column() throws for unknown column', () {
        expect(() => table.column('unknown'), throwsA(isA<CsvException>()));
      });
    });

    group('cell access', () {
      test('cell and cellByName', () {
        final table = CsvTable.fromData(
          headers: ['x', 'y'],
          rows: [
            [10, 20],
          ],
        );
        expect(table.cell(0, 0), 10);
        expect(table.cellByName(0, 'y'), 20);
      });

      test('setCell and setCellByName', () {
        final table = CsvTable.fromData(
          headers: ['x', 'y'],
          rows: [
            [10, 20],
          ],
        );
        table.setCell(0, 0, 99);
        expect(table.cell(0, 0), 99);
        table.setCellByName(0, 'y', 88);
        expect(table.cellByName(0, 'y'), 88);
      });
    });

    group('row manipulation', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
            [2],
          ],
        );
      });

      test('addRow', () {
        table.addRow([3]);
        expect(table.rowCount, 3);
        expect(table.cell(2, 0), 3);
      });

      test('addRowFromMap', () {
        table.addRowFromMap({'a': 99});
        expect(table.cell(2, 0), 99);
      });

      test('insertRow', () {
        table.insertRow(0, [0]);
        expect(table.rowCount, 3);
        expect(table.cell(0, 0), 0);
      });

      test('removeRow', () {
        final removed = table.removeRow(0);
        expect(removed[0], 1);
        expect(table.rowCount, 1);
      });

      test('removeWhere', () {
        final count = table.removeWhere((row) => row[0] == 1);
        expect(count, 1);
        expect(table.rowCount, 1);
      });

      test('addRows', () {
        table.addRows([
          [3],
          [4],
        ]);
        expect(table.rowCount, 4);
      });
    });

    group('column manipulation', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['a', 'b'],
          rows: [
            [1, 2],
          ],
        );
      });

      test('addColumn', () {
        table.addColumn('c', defaultValue: 0);
        expect(table.headers, ['a', 'b', 'c']);
        expect(table.cell(0, 2), 0);
      });

      test('insertColumn', () {
        table.insertColumn(0, 'z', defaultValue: 9);
        expect(table.headers, ['z', 'a', 'b']);
        expect(table.cell(0, 0), 9);
      });

      test('removeColumn', () {
        final vals = table.removeColumn('a');
        expect(vals, [1]);
        expect(table.headers, ['b']);
      });

      test('removeColumnAt', () {
        final vals = table.removeColumnAt(1);
        expect(vals, [2]);
      });

      test('renameColumn', () {
        table.renameColumn('a', 'x');
        expect(table.headers, ['x', 'b']);
      });

      test('reorderColumns', () {
        table.reorderColumns(['b', 'a']);
        expect(table.headers, ['b', 'a']);
        expect(table.cell(0, 0), 2);
        expect(table.cell(0, 1), 1);
      });
    });

    group('querying', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
            ['Bob', 25],
            ['Charlie', 30],
          ],
        );
      });

      test('where', () {
        final result = table.where((row) => row['age'] == 30);
        expect(result.rowCount, 2);
      });

      test('firstWhere', () {
        final row = table.firstWhere((row) => row['age'] == 25);
        expect(row?['name'], 'Bob');
      });

      test('firstWhere returns null', () {
        expect(table.firstWhere((row) => row['age'] == 99), null);
      });

      test('any', () {
        expect(table.any((row) => row['name'] == 'Bob'), true);
        expect(table.any((row) => row['name'] == 'Dave'), false);
      });

      test('every', () {
        expect(table.every((row) => row['age'] is int), true);
        expect(table.every((row) => row['age'] == 30), false);
      });

      test('range', () {
        final result = table.range(1, 3);
        expect(result.rowCount, 2);
        expect(result.cell(0, 0), 'Bob');
      });

      test('take', () {
        expect(table.take(1).rowCount, 1);
      });

      test('skip', () {
        expect(table.skip(2).rowCount, 1);
      });

      test('distinct', () {
        table.addRow(['Alice', 30]);
        final result = table.distinct();
        expect(result.rowCount, 3);
      });

      test('distinct by columns', () {
        final result = table.distinct(columns: ['age']);
        expect(result.rowCount, 2);
      });
    });

    group('sorting', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['name', 'score'],
          rows: [
            ['Charlie', 80],
            ['Alice', 95],
            ['Bob', 80],
          ],
        );
      });

      test('sortBy ascending', () {
        table.sortBy('name');
        expect(table.cell(0, 0), 'Alice');
        expect(table.cell(2, 0), 'Charlie');
      });

      test('sortBy descending', () {
        table.sortBy('score', ascending: false);
        expect(table.cell(0, 1), 95);
      });

      test('sortByIndex', () {
        table.sortByIndex(0);
        expect(table.cell(0, 0), 'Alice');
      });

      test('sortByMultiple', () {
        table.sortByMultiple([('score', true), ('name', true)]);
        expect(table.cell(0, 0), 'Bob');
        expect(table.cell(1, 0), 'Charlie');
        expect(table.cell(2, 0), 'Alice');
      });

      test('sort with custom comparator', () {
        table.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String));
        expect(table.cell(0, 0), 'Alice');
      });
    });

    group('transformation', () {
      test('transformColumn', () {
        final table = CsvTable.fromData(
          headers: ['val'],
          rows: [
            [1],
            [2],
          ],
        );
        table.transformColumn('val', (v) => (v as int) * 10);
        expect(table.column('val'), [10, 20]);
      });

      test('map', () {
        final table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
            [2],
          ],
        );
        final mapped = table.map((row) {
          row[0] = (row[0] as int) + 100;
          return row;
        });
        expect(mapped.column('a'), [101, 102]);
      });

      test('fold', () {
        final table = CsvTable.fromData(
          headers: ['val'],
          rows: [
            [1],
            [2],
            [3],
          ],
        );
        final sum = table.fold<int>(0, (acc, row) => acc + (row[0] as int));
        expect(sum, 6);
      });
    });

    group('aggregation', () {
      late CsvTable table;
      setUp(() {
        table = CsvTable.fromData(
          headers: ['name', 'score'],
          rows: [
            ['Alice', 90],
            ['Bob', 80],
            [null, 70],
          ],
        );
      });

      test('count', () {
        expect(table.count('name'), 2);
        expect(table.count('score'), 3);
      });

      test('sum', () {
        expect(table.sum('score'), 240);
      });

      test('avg', () {
        expect(table.avg('score'), 80);
      });

      test('min', () {
        expect(table.min('score'), 70);
      });

      test('max', () {
        expect(table.max('score'), 90);
      });

      test('groupBy', () {
        final t = CsvTable.fromData(
          headers: ['dept', 'score'],
          rows: [
            ['A', 1],
            ['B', 2],
            ['A', 3],
          ],
        );
        final groups = t.groupBy('dept');
        expect(groups.length, 2);
        expect(groups['A']!.rowCount, 2);
        expect(groups['B']!.rowCount, 1);
      });
    });

    group('conversion', () {
      test('toList without headers', () {
        final table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
          ],
        );
        expect(table.toList(), [
          [1],
        ]);
      });

      test('toList with headers', () {
        final table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
          ],
        );
        expect(table.toList(includeHeaders: true), [
          ['a'],
          [1],
        ]);
      });

      test('toMaps', () {
        final table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
          ],
        );
        expect(table.toMaps(), [
          {'name': 'Alice', 'age': 30},
        ]);
      });

      test('toCsv', () {
        final table = CsvTable.fromData(
          headers: ['a', 'b'],
          rows: [
            [1, 2],
          ],
        );
        final csv = table.toCsv();
        expect(csv, 'a,b\r\n1,2');
      });

      test('parse and toCsv round-trip preserves data', () {
        const input = 'name,age\r\nAlice,30\r\nBob,25';
        final table = CsvTable.parse(input);
        expect(table.toCsv(), input);
      });
    });

    group('schema validation', () {
      test('valid data passes', () {
        final table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
          ],
        );
        final schema = CsvSchema(columns: [
          CsvColumnDef(name: 'name', type: String),
          CsvColumnDef(name: 'age', type: int),
        ]);
        expect(table.validate(schema), isEmpty);
        expect(table.conformsTo(schema), true);
      });

      test('missing required column', () {
        final table = CsvTable.fromData(headers: ['name'], rows: []);
        final schema = CsvSchema(columns: [
          CsvColumnDef(name: 'name'),
          CsvColumnDef(name: 'age', required: true),
        ]);
        final errors = table.validate(schema);
        expect(errors, hasLength(1));
        expect(errors.first.constraint, 'required');
      });

      test('null in non-nullable column', () {
        final table = CsvTable.fromData(
          headers: ['val'],
          rows: [
            [null],
          ],
        );
        final schema = CsvSchema(columns: [
          CsvColumnDef(name: 'val', nullable: false),
        ]);
        final errors = table.validate(schema);
        expect(errors, hasLength(1));
        expect(errors.first.constraint, 'non_nullable');
      });

      test('type mismatch', () {
        final table = CsvTable.fromData(
          headers: ['age'],
          rows: [
            ['thirty'],
          ],
        );
        final schema = CsvSchema(columns: [
          CsvColumnDef(name: 'age', type: int),
        ]);
        expect(table.validate(schema).first.constraint, startsWith('type'));
      });

      test('pattern validation', () {
        final table = CsvTable.fromData(
          headers: ['email'],
          rows: [
            ['bad'],
          ],
        );
        final schema = CsvSchema(columns: [
          CsvColumnDef(name: 'email', pattern: r'^[\w.]+@[\w.]+$'),
        ]);
        expect(table.validate(schema), hasLength(1));
      });

      test('custom validator', () {
        final table = CsvTable.fromData(
          headers: ['score'],
          rows: [
            [150],
          ],
        );
        final schema = CsvSchema(columns: [
          CsvColumnDef(name: 'score', validator: (v) => v is int && v <= 100),
        ]);
        expect(table.validate(schema), hasLength(1));
      });

      test('extra columns blocked', () {
        final table = CsvTable.fromData(
          headers: ['a', 'b'],
          rows: [],
        );
        final schema = CsvSchema(
          columns: [CsvColumnDef(name: 'a')],
          allowExtraColumns: false,
        );
        final errors = table.validate(schema);
        expect(errors.any((e) => e.constraint == 'no_extra_columns'), true);
      });
    });

    group('copy', () {
      test('deep copy', () {
        final table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
          ],
        );
        final copy = table.copy();
        copy.setCell(0, 0, 99);
        expect(table.cell(0, 0), 1); // original unchanged
        expect(copy.cell(0, 0), 99);
      });
    });

    group('toString / toFormattedString', () {
      test('toString includes dimensions', () {
        final table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
          ],
        );
        expect(table.toString(), contains('1 rows'));
      });

      test('toFormattedString', () {
        final table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
          ],
        );
        final formatted = table.toFormattedString();
        expect(formatted, contains('name'));
        expect(formatted, contains('Alice'));
        expect(formatted, contains('---'));
      });

      test('toFormattedString empty', () {
        final table = CsvTable.empty();
        expect(table.toFormattedString(), '(empty table)');
      });
    });

    group('copy-returning operations leave the source untouched', () {
      test('map cannot corrupt the source through row writes', () {
        final table = CsvTable.fromData(
          headers: ['a'],
          rows: [
            [1],
            [2],
          ],
        );
        final mapped = table.map((row) {
          row[0] = (row[0] as int) + 100;
          return row;
        });
        expect(mapped.column('a'), [101, 102]);
        expect(table.column('a'), [1, 2],
            reason: 'map must not mutate its source');
      });

      test('sortedBy returns a sorted copy and keeps the source order', () {
        final table = CsvTable.fromData(
          headers: ['n'],
          rows: [
            [3],
            [1],
            [2],
          ],
        );
        final sorted = table.sortedBy('n');
        expect(sorted.column('n'), [1, 2, 3]);
        expect(table.column('n'), [3, 1, 2]);
      });
    });

    group('sorting order guarantees', () {
      test('sorts are stable: a second sort preserves prior order', () {
        final table = CsvTable.fromData(
          headers: ['grp', 'name'],
          rows: [
            ['b', 'x'],
            ['a', 'z'],
            ['a', 'y'],
            ['b', 'w'],
          ],
        );
        table.sortBy('name');
        table.sortBy('grp');
        expect(table.column('name'), ['y', 'z', 'w', 'x']);
      });

      test('nulls sort last in both directions', () {
        final table = CsvTable.fromData(
          headers: ['n'],
          rows: [
            [2],
            [null],
            [1],
          ],
        );
        table.sortBy('n');
        expect(table.column('n'), [1, 2, null]);
        table.sortBy('n', ascending: false);
        expect(table.column('n'), [2, 1, null]);
      });

      test('mixed types sort numbers before their string look-alikes', () {
        final table = CsvTable.fromData(
          headers: ['v'],
          rows: [
            ['9'],
            [10],
            ['10'],
            [9],
          ],
        );
        table.sortBy('v');
        expect(table.column('v'), [9, 10, '10', '9']);
      });
    });

    group('distinct keys', () {
      test('distinguishes equal-looking values of different types', () {
        final table = CsvTable.fromData(
          headers: ['v'],
          rows: [
            [1],
            ['1'],
            [1.0],
            [true],
            ['true'],
          ],
        );
        // int 1 and double 1.0 are equal in Dart collections, and both
        // differ from the string form.
        expect(table.distinct().rowCount, 5);
      });

      test('string content cannot forge a key collision', () {
        final table = CsvTable.fromData(
          headers: ['a', 'b'],
          rows: [
            ['x\x00y', 'z'],
            ['x', 'y\x00z'],
          ],
        );
        expect(table.distinct().rowCount, 2);
      });
    });

    group('parse header consistency', () {
      test('headers are read raw, so 01 stays 01', () {
        final table = CsvTable.parse('01,name\n1,Alice');
        expect(table.headers, ['01', 'name']);
        expect(table.cell(0, 0), 1);
      });
    });
  });
}
