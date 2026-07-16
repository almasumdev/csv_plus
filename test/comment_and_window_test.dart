import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('Comment Lines', () {
    const cfg = CsvConfig(autoDetect: false, comment: '#');

    test('a comment line at the top is skipped', () {
      expect(const CsvCodec(cfg).decode('# generated\na,b\n1,2'), [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('comment lines are not skipped by default', () {
      expect(const CsvCodec(CsvConfig(autoDetect: false)).decode('#c\na,b'), [
        ['#c'],
        ['a', 'b'],
      ]);
    });

    test('a comment line between rows is skipped', () {
      expect(const CsvCodec(cfg).decode('a,b\n# note\n1,2'), [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('a marker inside a quoted field is not a comment', () {
      expect(const CsvCodec(cfg).decode('"#x",1\n"#y",2'), [
        ['#x', 1],
        ['#y', 2],
      ]);
    });

    test('a marker mid-field is ordinary content', () {
      expect(const CsvCodec(cfg).decode('a#b,1'), [
        ['a#b', 1],
      ]);
    });

    test('a custom marker is honored', () {
      const semi = CsvConfig(autoDetect: false, comment: ';');
      expect(const CsvCodec(semi).decode('; note\na,b'), [
        ['a', 'b'],
      ]);
    });

    test('only the first character of a longer marker is used', () {
      const slashes = CsvConfig(autoDetect: false, comment: '//');
      expect(const CsvCodec(slashes).decode('/comment\na,b'), [
        ['a', 'b'],
      ]);
    });

    test('comment skipping applies to decodeStrings', () {
      expect(const CsvCodec(cfg).decodeStrings('#c\na,b'), [
        ['a', 'b'],
      ]);
    });

    test('the typed decoders inherit comment skipping', () {
      expect(const CsvCodec(cfg).decodeIntegers('# nums\n1,2\n3,4'), [
        [1, 2],
        [3, 4],
      ]);
    });

    test('comment skipping keeps a table header correct', () {
      final table = const CsvCodec(
        cfg,
      ).decodeToTable('# pre\nname,age\nAlice,30');
      expect(table.headers, ['name', 'age']);
      expect(table.toMaps(), [
        {'name': 'Alice', 'age': 30},
      ]);
    });

    test('a comment-only input yields no rows', () {
      expect(const CsvCodec(cfg).decode('# only\n# lines'), isEmpty);
    });
  });

  group('Row Windowing skipRows', () {
    test('skipRows drops leading rows before the header', () {
      const cfg = CsvConfig(autoDetect: false, hasHeader: true, skipRows: 2);
      expect(const CsvCodec(cfg).decode('j1\nj2\nname,age\nAlice,30'), [
        ['Alice', 30],
      ]);
    });

    test('skipRows without a header skips leading data rows', () {
      const cfg = CsvConfig(autoDetect: false, skipRows: 1);
      expect(const CsvCodec(cfg).decode('a,b\n1,2\n3,4'), [
        [1, 2],
        [3, 4],
      ]);
    });

    test('empty lines do not count toward skipRows', () {
      const cfg = CsvConfig(autoDetect: false, skipRows: 1);
      expect(const CsvCodec(cfg).decode('\n\na,b\n1,2'), [
        [1, 2],
      ]);
    });

    test('comment lines do not count toward skipRows', () {
      const cfg = CsvConfig(autoDetect: false, comment: '#', skipRows: 1);
      expect(const CsvCodec(cfg).decode('#c\njunk\na,b\n1,2'), [
        ['a', 'b'],
        [1, 2],
      ]);
    });
  });

  group('Row Windowing maxRows', () {
    test('maxRows limits the number of data rows', () {
      const cfg = CsvConfig(autoDetect: false, maxRows: 2);
      expect(const CsvCodec(cfg).decode('1\n2\n3\n4'), [
        [1],
        [2],
      ]);
    });

    test('maxRows does not count the header', () {
      const cfg = CsvConfig(autoDetect: false, hasHeader: true, maxRows: 2);
      expect(const CsvCodec(cfg).decode('h\n1\n2\n3'), [
        [1],
        [2],
      ]);
    });

    test('maxRows of zero yields no data rows', () {
      const cfg = CsvConfig(autoDetect: false, maxRows: 0);
      expect(const CsvCodec(cfg).decode('1\n2'), isEmpty);
    });

    test('skipRows and maxRows combine into a window', () {
      const cfg = CsvConfig(autoDetect: false, skipRows: 1, maxRows: 2);
      expect(const CsvCodec(cfg).decode('1\n2\n3\n4\n5'), [
        [2],
        [3],
      ]);
    });

    test('maxRows limits decodeStrings too', () {
      const cfg = CsvConfig(
        autoDetect: false,
        dynamicTyping: false,
        maxRows: 1,
      );
      expect(const CsvCodec(cfg).decodeStrings('a\nb\nc'), [
        ['a'],
      ]);
    });
  });

  group('decodeToMaps', () {
    test('decodeToMaps keys each row by header name', () {
      expect(
        const CsvCodec(
          CsvConfig(autoDetect: false),
        ).decodeToMaps('name,age\nAlice,30\nBob,25'),
        [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
      );
    });

    test('decodeToMaps honors maxRows', () {
      const cfg = CsvConfig(autoDetect: false, maxRows: 1);
      expect(const CsvCodec(cfg).decodeToMaps('name,age\nAlice,30\nBob,25'), [
        {'name': 'Alice', 'age': 30},
      ]);
    });
  });

  group('decodeFlexible', () {
    test('decodeFlexible honors comment, skipRows, and maxRows', () {
      const cfg = CsvConfig(
        autoDetect: false,
        comment: '#',
        skipRows: 1,
        maxRows: 1,
      );
      expect(const CsvCodec(cfg).decodeFlexible('#c\njunk\n a , b \n x , y '), [
        ['a', 'b'],
      ]);
    });
  });
}
