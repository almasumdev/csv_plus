@TestOn('vm')
library;

import 'dart:io';

import 'package:csv_plus/csv_plus.dart';
import 'package:csv_plus/src/io/csv_file.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('csv_plus_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String tempPath(String name) => '${tempDir.path}/$name';

  group('CsvFile', () {
    group('read/write', () {
      test('write then read async', () async {
        final path = tempPath('test.csv');
        final table = CsvTable.fromData(
          headers: ['name', 'age'],
          rows: [
            ['Alice', 30],
            ['Bob', 25],
          ],
        );
        await CsvFile.write(path, table);
        final restored = await CsvFile.read(path);
        expect(restored.headers, ['name', 'age']);
        expect(restored.rowCount, 2);
        expect(restored[0]['name'], 'Alice');
        expect(restored[1]['age'], 25);
      });

      test('writeSync then readSync', () {
        final path = tempPath('test_sync.csv');
        final table = CsvTable.fromData(
          headers: ['x', 'y'],
          rows: [
            [1, 2],
            [3, 4],
          ],
        );
        CsvFile.writeSync(path, table);
        final restored = CsvFile.readSync(path);
        expect(restored.headers, ['x', 'y']);
        expect(restored[0][0], 1);
        expect(restored[1][1], 4);
      });
    });

    group('writeRows', () {
      test('writes raw rows', () async {
        final path = tempPath('rows.csv');
        await CsvFile.writeRows(path, [
          ['a', 'b'],
          [1, 2],
        ]);
        final content = await File(path).readAsString();
        expect(content, 'a,b\r\n1,2');
      });
    });

    group('stream', () {
      test('streams rows from file', () async {
        final path = tempPath('stream.csv');
        await File(path).writeAsString('a,b\n1,2\n3,4');
        final rows = await CsvFile.stream(path).toList();
        expect(rows.length, 3);
        expect(rows[0], ['a', 'b']);
        expect(rows[1], [1, 2]);
        expect(rows[2], [3, 4]);
      });

      test('streams a semicolon file the same way read does', () async {
        for (final text in [
          'name;age\nAnn;30\nBob;25\n',
          'sep=;\nname;age\nAnn;30\nBob;25\n',
        ]) {
          final path = tempPath('semicolon.csv');
          await File(path).writeAsString(text);
          final table = await CsvFile.read(path);
          final rows = await CsvFile.stream(path).toList();
          expect(rows, [
            ['name', 'age'],
            ['Ann', 30],
            ['Bob', 25],
          ]);
          expect(rows.first, table.headers);
        }
      });
    });

    group('writeStream', () {
      test('writes stream of rows to file', () async {
        final path = tempPath('write_stream.csv');
        final rows = Stream.fromIterable([
          ['x', 'y'],
          [10, 20],
          [30, 40],
        ]);
        await CsvFile.writeStream(path, rows);
        final content = await File(path).readAsString();
        expect(content.contains('x,y'), true);
        expect(content.contains('10,20'), true);
        expect(content.contains('30,40'), true);
      });
    });

    group('append', () {
      test('appends rows to existing file', () async {
        final path = tempPath('append.csv');
        await File(path).writeAsString('a,b\r\n1,2');
        await CsvFile.append(path, [
          [3, 4],
        ]);
        final content = await File(path).readAsString();
        expect(content, 'a,b\r\n1,2\r\n3,4');
      });

      test('creates file if not exists', () async {
        final path = tempPath('new_append.csv');
        await CsvFile.append(path, [
          ['a', 'b'],
        ]);
        final content = await File(path).readAsString();
        expect(content, 'a,b');
      });
    });

    group('custom config', () {
      test('write and read with TSV config', () async {
        final path = tempPath('tsv.csv');
        final config = const CsvConfig.tsv();
        final table = CsvTable.fromData(
          headers: ['col1', 'col2'],
          rows: [
            ['hello', 'world'],
          ],
        );
        await CsvFile.write(path, table, config: config);
        final restored = await CsvFile.read(path, config: config);
        expect(restored.headers, ['col1', 'col2']);
        expect(restored[0][0], 'hello');
      });
    });
  });
}
