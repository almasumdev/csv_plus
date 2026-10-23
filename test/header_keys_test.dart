import 'package:csv_plus/csv_plus.dart';
import 'package:csv_plus/src/table/header_keys.dart';
import 'package:test/test.dart';

void main() {
  const config = CsvConfig(autoDetect: false, hasHeader: true);
  const codec = CsvCodec(config);

  group('Repeated Header Names', () {
    test('a repeated name no longer loses its column', () {
      // Each keyed view used to keep only the last of the repeats, dropping
      // the first column's values while they were still there by position.
      expect(codec.decodeToMaps('a,a,b\n1,2,3'), [
        {'a': 1, 'a_2': 2, 'b': 3},
      ]);
    });

    test('decodeWithHeaders keeps every column', () {
      final row = codec.decodeWithHeaders('a,a,b\n1,2,3').single;
      expect(row.toMap(), {'a': 1, 'a_2': 2, 'b': 3});
      expect(row.headers, ['a', 'a_2', 'b']);
    });

    test('the first of the repeats keeps the plain name', () {
      final row = codec.decodeWithHeaders('a,a\n1,2').single;
      expect(row['a'], 1);
      expect(row['a_2'], 2);
    });

    test('positional access is unchanged', () {
      final row = codec.decodeWithHeaders('a,a,b\n1,2,3').single;
      expect([row[0], row[1], row[2]], [1, 2, 3]);
    });

    test('three repeats number on from two', () {
      expect(codec.decodeToMaps('x,x,x\n1,2,3'), [
        {'x': 1, 'x_2': 2, 'x_3': 3},
      ]);
    });

    test('a real column already named like a suffix is not overwritten', () {
      expect(codec.decodeToMaps('a,a,a_2\n1,2,3'), [
        {'a': 1, 'a_3': 2, 'a_2': 3},
      ]);
    });

    test('a header row with no repeats is unchanged', () {
      expect(codec.decodeToMaps('name,age\nx,1'), [
        {'name': 'x', 'age': 1},
      ]);
    });

    test('two empty header cells do not collide', () {
      final map = codec.decodeToMaps('a,,\n1,2,3').single;
      expect(map.values, [1, 2, 3]);
      expect(map.keys.toSet(), hasLength(3));
    });

    test('a table built from headers keeps every column too', () {
      final table = codec.decodeToTable('a,a\n1,2');
      expect(table.toMaps(), [
        {'a': 1, 'a_2': 2},
      ]);
      expect(table.rows.first.toMap(), {'a': 1, 'a_2': 2});
    });
  });

  group('Unique Header Keys', () {
    test('it returns the names unchanged when none repeat', () {
      expect(uniqueHeaderKeys(['a', 'b', 'c']), ['a', 'b', 'c']);
    });

    test('every key it returns is distinct', () {
      final keys = uniqueHeaderKeys(['a', 'a', 'a_2', 'a', 'a_3']);
      expect(keys.toSet(), hasLength(keys.length));
    });
  });
}
