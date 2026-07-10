import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Tests for production-readiness: edge cases, error paths, and coverage gaps.
void main() {
  // ---------------------------------------------------------------------------
  // autoDetect wired into CsvCodec
  // ---------------------------------------------------------------------------
  group('CsvCodec autoDetect', () {
    test('auto-detects semicolons', () {
      final codec = CsvCodec(const CsvConfig(autoDetect: true));
      final result = codec.decode('a;b\n1;2');
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('auto-detects tabs', () {
      final codec = CsvCodec(const CsvConfig(autoDetect: true));
      final result = codec.decode('a\tb\n1\t2');
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('auto-detects from sep= hint', () {
      final codec = CsvCodec(const CsvConfig(autoDetect: true));
      final result = codec.decode('sep=;\na;b\n1;2');
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('disabled autoDetect uses config delimiter', () {
      final codec = CsvCodec(const CsvConfig(autoDetect: false));
      // Semicolons are NOT detected; the comma is used
      final result = codec.decode('a;b\n1;2');
      expect(result[0], ['a;b']);
    });

    test('autoDetect works for decodeStrings', () {
      final codec = CsvCodec(const CsvConfig(autoDetect: true));
      final result = codec.decodeStrings('a;b\n1;2');
      expect(result, [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('autoDetect works for decodeWithHeaders', () {
      final codec = CsvCodec(const CsvConfig(autoDetect: true));
      final result = codec.decodeWithHeaders('name;age\nAlice;30');
      expect(result.first['name'], 'Alice');
      expect(result.first['age'], 30);
    });
  });

  // ---------------------------------------------------------------------------
  // CsvCodec.decodeBooleans / encodeGeneric
  // ---------------------------------------------------------------------------
  group('CsvCodec newly exposed methods', () {
    test('decodeBooleans', () {
      final result = CsvCodec().decodeBooleans('true,false\nTrue,False');
      expect(result, [
        [true, false],
        [true, false],
      ]);
    });

    test('encodeGeneric with ints', () {
      final result = CsvCodec().encodeGeneric<int>([
        [1, 2, 3],
        [4, 5, 6],
      ]);
      expect(result, '1,2,3\r\n4,5,6');
    });

    test('encodeGeneric with doubles', () {
      final result = CsvCodec().encodeGeneric<double>([
        [1.5, 2.5],
      ]);
      expect(result, '1.5,2.5');
    });

    test('encodeGeneric with bools', () {
      final result = CsvCodec().encodeGeneric<bool>([
        [true, false],
      ]);
      expect(result, 'true,false');
    });
  });

  // ---------------------------------------------------------------------------
  // CsvSchema.allowMissingColumns
  // ---------------------------------------------------------------------------
  group('CsvSchema allowMissingColumns', () {
    test('suppresses missing required column errors', () {
      final schema = CsvSchema(
        columns: [
          CsvColumnDef(name: 'a', required: true),
          CsvColumnDef(name: 'b', required: true),
        ],
        allowMissingColumns: true,
      );
      final errors = schema.validate(
        ['a'],
        [
          [1],
        ],
      );
      expect(errors, isEmpty);
    });

    test('without flag reports missing required columns', () {
      final schema = CsvSchema(
        columns: [
          CsvColumnDef(name: 'a', required: true),
          CsvColumnDef(name: 'b', required: true),
        ],
        allowMissingColumns: false,
      );
      final errors = schema.validate(
        ['a'],
        [
          [1],
        ],
      );
      expect(errors.length, 1);
      expect(errors.first.constraint, 'required');
    });
  });

  // ---------------------------------------------------------------------------
  // CsvEncoder.encodeField
  // ---------------------------------------------------------------------------
  group('CsvEncoder.encodeField', () {
    test('quotes field with comma', () {
      final result = CsvEncoder.encodeField(
        'hello,world',
        fieldDelimiter: ',',
        quoteCharacter: '"',
        escapeCharacter: '"',
        quoteMode: QuoteMode.necessary,
      );
      expect(result, '"hello,world"');
    });

    test('escapes quotes in field', () {
      final result = CsvEncoder.encodeField(
        'say "hi"',
        fieldDelimiter: ',',
        quoteCharacter: '"',
        escapeCharacter: '"',
        quoteMode: QuoteMode.necessary,
      );
      expect(result, '"say ""hi"""');
    });

    test('null field returns empty string', () {
      final result = CsvEncoder.encodeField(
        null,
        fieldDelimiter: ',',
        quoteCharacter: '"',
        escapeCharacter: '"',
        quoteMode: QuoteMode.necessary,
      );
      expect(result, '');
    });

    test('always mode quotes everything', () {
      final result = CsvEncoder.encodeField(
        42,
        fieldDelimiter: ',',
        quoteCharacter: '"',
        escapeCharacter: '"',
        quoteMode: QuoteMode.always,
      );
      expect(result, '"42"');
    });

    test('strings mode only quotes strings', () {
      final strResult = CsvEncoder.encodeField(
        'text',
        fieldDelimiter: ',',
        quoteCharacter: '"',
        escapeCharacter: '"',
        quoteMode: QuoteMode.strings,
      );
      final intResult = CsvEncoder.encodeField(
        42,
        fieldDelimiter: ',',
        quoteCharacter: '"',
        escapeCharacter: '"',
        quoteMode: QuoteMode.strings,
      );
      expect(strResult, '"text"');
      expect(intResult, '42');
    });
  });

  // ---------------------------------------------------------------------------
  // CsvTable edge cases
  // ---------------------------------------------------------------------------
  group('CsvTable edge cases', () {
    test('cellByName throws on unknown column', () {
      final table = CsvTable.fromData(
        headers: ['a'],
        rows: [
          [1],
        ],
      );
      expect(() => table.cellByName(0, 'z'), throwsA(isA<CsvException>()));
    });

    test('setCellByName throws on unknown column', () {
      final table = CsvTable.fromData(
        headers: ['a'],
        rows: [
          [1],
        ],
      );
      expect(
        () => table.setCellByName(0, 'z', 99),
        throwsA(isA<CsvException>()),
      );
    });

    test('reorderColumns throws on unknown column', () {
      final table = CsvTable.fromData(
        headers: ['a', 'b'],
        rows: [
          [1, 2],
        ],
      );
      expect(
        () => table.reorderColumns(['a', 'unknown']),
        throwsA(isA<CsvException>()),
      );
    });

    test('addRowFromMap with missing headers adds null', () {
      final table = CsvTable.fromData(headers: ['a', 'b', 'c'], rows: []);
      table.addRowFromMap({'a': 1, 'c': 3});
      expect(table[0].toList(), [1, null, 3]);
    });

    test('groupBy with null keys', () {
      final table = CsvTable.fromData(
        headers: ['group', 'val'],
        rows: [
          ['x', 1],
          [null, 2],
          ['x', 3],
          [null, 4],
        ],
      );
      final groups = table.groupBy('group');
      expect(groups.keys, containsAll(['x', null]));
      expect(groups['x']!.rowCount, 2);
      expect(groups[null]!.rowCount, 2);
    });

    test('min with all-null column', () {
      final table = CsvTable.fromData(
        headers: ['val'],
        rows: [
          [null],
          [null],
        ],
      );
      expect(table.min('val'), null);
    });

    test('max with all-null column', () {
      final table = CsvTable.fromData(
        headers: ['val'],
        rows: [
          [null],
          [null],
        ],
      );
      expect(table.max('val'), null);
    });

    test('toFormattedString truncates rows', () {
      final table = CsvTable.fromData(
        headers: ['v'],
        rows: List.generate(50, (i) => [i]),
      );
      final s = table.toFormattedString(maxRows: 5);
      expect(s.contains('more rows'), true);
    });

    test('toFormattedString truncates wide columns', () {
      final table = CsvTable.fromData(
        headers: ['data'],
        rows: [
          ['A' * 100],
        ],
      );
      final s = table.toFormattedString(maxColumnWidth: 10);
      expect(s.contains('...'), true);
    });

    test('toFormattedString on empty table', () {
      final table = CsvTable.fromData(headers: [], rows: []);
      expect(table.toFormattedString(), '(empty table)');
    });

    test('distinct on data without headers', () {
      final table = CsvTable([
        [1, 2],
        [1, 2],
        [3, 4],
      ]);
      final d = table.distinct();
      expect(d.rowCount, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // CsvSchema pattern validation (valid match)
  // ---------------------------------------------------------------------------
  group('CsvSchema pattern validation', () {
    test('valid value passes pattern', () {
      final schema = CsvSchema(
        columns: [CsvColumnDef(name: 'email', pattern: r'^[\w.]+@[\w.]+$')],
      );
      final errors = schema.validate(
        ['email'],
        [
          ['user@example.com'],
        ],
      );
      expect(errors, isEmpty);
    });

    test('invalid value fails pattern', () {
      final schema = CsvSchema(
        columns: [CsvColumnDef(name: 'email', pattern: r'^[\w.]+@[\w.]+$')],
      );
      final errors = schema.validate(
        ['email'],
        [
          ['not-an-email'],
        ],
      );
      expect(errors.length, 1);
      expect(errors.first.constraint, contains('pattern'));
    });
  });

  // ---------------------------------------------------------------------------
  // FastEncoder.encodeGeneric edge cases
  // ---------------------------------------------------------------------------
  group('FastEncoder.encodeGeneric', () {
    test('empty data with BOM', () {
      final encoder = FastEncoder();
      final result = encoder.encodeGeneric<int>(
        [],
        const CsvConfig(addBom: true),
      );
      expect(result.codeUnitAt(0), 0xFEFF);
    });

    test('string type still works (no quoting)', () {
      final encoder = FastEncoder();
      final result = encoder.encodeGeneric<String>([
        ['a', 'b'],
        ['c', 'd'],
      ], const CsvConfig());
      expect(result, 'a,b\r\nc,d');
    });
  });

  // ---------------------------------------------------------------------------
  // CsvEncoder startChunkedConversion with BOM
  // ---------------------------------------------------------------------------
  group('CsvEncoder chunked with BOM', () {
    test('BOM prepended on first row', () {
      final encoder = CsvEncoder(const CsvConfig(addBom: true));
      final output = StringBuffer();
      final sink = encoder.startChunkedConversion(_StringSink(output));
      sink.add(['a', 'b']);
      sink.add([1, 2]);
      sink.close();
      final result = output.toString();
      expect(result.codeUnitAt(0), 0xFEFF);
    });
  });

  // ---------------------------------------------------------------------------
  // CsvDecoder chunked with hasHeader
  // ---------------------------------------------------------------------------
  group('CsvDecoder chunked with hasHeader', () {
    test('first row excluded when hasHeader=true', () {
      final decoder = CsvDecoder(const CsvConfig(hasHeader: true));
      final results = <List<dynamic>>[];
      final sink = decoder.startChunkedConversion(_ListSink(results));
      sink.add('name,age\nAlice,30\nBob,25');
      sink.close();
      expect(results.length, 2);
      expect(results[0], ['Alice', 30]);
    });
  });
}

class _StringSink implements Sink<String> {
  final StringBuffer _buf;
  _StringSink(this._buf);

  @override
  void add(String data) => _buf.write(data);

  @override
  void close() {}
}

class _ListSink implements Sink<List<dynamic>> {
  final List<List<dynamic>> _list;
  _ListSink(this._list);

  @override
  void add(List<dynamic> data) => _list.add(data);

  @override
  void close() {}
}
