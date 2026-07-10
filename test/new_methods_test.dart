import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('FastDecoder.decodeFlexible', () {
    const decoder = FastDecoder();
    const config = CsvConfig();

    test('trims whitespace from unquoted fields', () {
      final result =
          decoder.decodeFlexible('  hello , world  \n  1 , 2 ', config);
      expect(result, [
        ['hello', 'world'],
        [1, 2],
      ]);
    });

    test('unmatched quote treated as literal', () {
      final result = decoder.decodeFlexible('"hello,world\n1,2', config);
      expect(result[0][0], startsWith('"'));
    });

    test('valid quoted fields still work', () {
      final result = decoder.decodeFlexible('"hello","world"\n1,2', config);
      expect(result, [
        ['hello', 'world'],
        [1, 2],
      ]);
    });

    test('empty input returns empty', () {
      expect(decoder.decodeFlexible('', config), isEmpty);
    });

    test('dynamic typing still works', () {
      final result = decoder.decodeFlexible('true,false,42,3.14', config);
      expect(result, [
        [true, false, 42, 3.14],
      ]);
    });

    test('empty fields become null with dynamic typing', () {
      final result = decoder.decodeFlexible(',', config);
      expect(result, [
        [null, null],
      ]);
    });
  });

  group('FastDecoder.decodeIntegers', () {
    const decoder = FastDecoder();
    const config = CsvConfig();

    test('basic integers', () {
      final result = decoder.decodeIntegers('1,2,3\n4,5,6', config);
      expect(result, [
        [1, 2, 3],
        [4, 5, 6],
      ]);
    });

    test('empty fields throw unless emptyAs provides a fill', () {
      expect(
        () => decoder.decodeIntegers('1,,3', config),
        throwsA(isA<CsvParseException>()),
      );
      final filled = decoder.decodeIntegers('1,,3', config, emptyAs: 0);
      expect(filled, [
        [1, 0, 3],
      ]);
    });

    test('non-integer fields throw with row and column', () {
      expect(
        () => decoder.decodeIntegers('1,2\n3,x', config),
        throwsA(
          isA<CsvParseException>()
              .having((e) => e.row, 'row', 1)
              .having((e) => e.column, 'column', 1),
        ),
      );
    });
  });

  group('FastDecoder.decodeDoubles', () {
    const decoder = FastDecoder();
    const config = CsvConfig();

    test('basic doubles', () {
      final result = decoder.decodeDoubles('1.5,2.5\n3.0,4.0', config);
      expect(result, [
        [1.5, 2.5],
        [3.0, 4.0],
      ]);
    });

    test('empty fields throw unless emptyAs provides a fill', () {
      expect(
        () => decoder.decodeDoubles('1.5,,3.5', config),
        throwsA(isA<CsvParseException>()),
      );
      final filled = decoder.decodeDoubles('1.5,,3.5', config, emptyAs: 0.0);
      expect(filled, [
        [1.5, 0.0, 3.5],
      ]);
    });

    test('integers parsed as doubles', () {
      final result = decoder.decodeDoubles('1,2,3', config);
      expect(result, [
        [1.0, 2.0, 3.0],
      ]);
    });
  });

  group('FastDecoder.decodeBooleans', () {
    const decoder = FastDecoder();
    const config = CsvConfig();

    test('basic booleans', () {
      final result = decoder.decodeBooleans('true,false\nTrue,False', config);
      expect(result, [
        [true, false],
        [true, false],
      ]);
    });

    test('accepts 1 and 0 from the documented truth table', () {
      final result = decoder.decodeBooleans('1,0', config);
      expect(result, [
        [true, false],
      ]);
    });

    test('values outside the truth table throw', () {
      expect(
        () => decoder.decodeBooleans('yes,no', config),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('empty fields throw unless emptyAs provides a fill', () {
      expect(
        () => decoder.decodeBooleans('true,', config),
        throwsA(isA<CsvParseException>()),
      );
      final filled = decoder.decodeBooleans('true,', config, emptyAs: false);
      expect(filled, [
        [true, false],
      ]);
    });
  });

  group('CsvCodec type-specific decoders', () {
    test('decodeFlexible trims whitespace', () {
      final codec = CsvCodec();
      final result = codec.decodeFlexible('  a , b \n  1 , 2 ');
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('decodeIntegers', () {
      final codec = CsvCodec();
      final result = codec.decodeIntegers('1,2\n3,4');
      expect(result, [
        [1, 2],
        [3, 4],
      ]);
    });

    test('decodeDoubles', () {
      final codec = CsvCodec();
      final result = codec.decodeDoubles('1.5,2.5\n3.5,4.5');
      expect(result, [
        [1.5, 2.5],
        [3.5, 4.5],
      ]);
    });
  });

  group('CsvDecoder.startChunkedConversion', () {
    test('basic chunked decode', () {
      final decoder = CsvDecoder(const CsvConfig());
      final results = <List<dynamic>>[];
      final sink = decoder.startChunkedConversion(
        ChunkedConversionSink.withCallback((chunks) {
          results.addAll(chunks);
        }),
      );
      sink.add('a,b\n1,');
      sink.add('2\n3,4');
      sink.close();
      expect(results, [
        ['a', 'b'],
        [1, 2],
        [3, 4],
      ]);
    });

    test('empty input produces no rows', () {
      final decoder = CsvDecoder(const CsvConfig());
      final results = <List<dynamic>>[];
      final sink = decoder.startChunkedConversion(
        ChunkedConversionSink.withCallback((chunks) {
          results.addAll(chunks);
        }),
      );
      sink.close();
      expect(results, isEmpty);
    });
  });

  group('CsvEncoder.startChunkedConversion', () {
    test('basic chunked encode', () {
      final encoder = CsvEncoder(const CsvConfig());
      final output = StringBuffer();
      final sink = encoder.startChunkedConversion(
        StringConversionSink.fromStringSink(output),
      );
      sink.add(['a', 'b']);
      sink.add([1, 2]);
      sink.close();
      expect(output.toString(), 'a,b\r\n1,2');
    });

    test('single row encoding', () {
      final encoder = CsvEncoder(const CsvConfig());
      final output = StringBuffer();
      final sink = encoder.startChunkedConversion(
        StringConversionSink.fromStringSink(output),
      );
      sink.add(['hello', 'world']);
      sink.close();
      expect(output.toString(), 'hello,world');
    });
  });

  group('CsvSchema.infer', () {
    test('infers types from uniform data', () {
      final schema = CsvSchema.infer(
        ['name', 'age', 'active'],
        [
          ['Alice', 30, true],
          ['Bob', 25, false],
        ],
      );
      expect(schema.columns.length, 3);
      expect(schema.columns[0].name, 'name');
      expect(schema.columns[0].type, String);
      expect(schema.columns[1].name, 'age');
      expect(schema.columns[1].type, int);
      expect(schema.columns[2].name, 'active');
      expect(schema.columns[2].type, bool);
    });

    test('detects nullable columns', () {
      final schema = CsvSchema.infer(
        ['name', 'value'],
        [
          ['Alice', 10],
          ['Bob', null],
        ],
      );
      expect(schema.columns[0].nullable, false);
      expect(schema.columns[1].nullable, true);
    });

    test('mixed types result in null type', () {
      final schema = CsvSchema.infer(
        ['data'],
        [
          [42],
          ['text'],
        ],
      );
      expect(schema.columns[0].type, null);
    });

    test('all null column', () {
      final schema = CsvSchema.infer(
        ['empty'],
        [
          [null],
          [null],
        ],
      );
      expect(schema.columns[0].type, null);
      expect(schema.columns[0].nullable, true);
    });

    test('empty rows infer correctly', () {
      final schema = CsvSchema.infer(['a', 'b'], []);
      expect(schema.columns.length, 2);
      expect(schema.columns[0].type, null);
    });
  });

  group('CsvTable.iterator', () {
    test('iterates over rows', () {
      final table = CsvTable.fromData(
        headers: ['a', 'b'],
        rows: [
          [1, 2],
          [3, 4],
        ],
      );
      final iter = table.iterator;
      expect(iter.moveNext(), true);
      expect(iter.current[0], 1);
      expect(iter.moveNext(), true);
      expect(iter.current[0], 3);
      expect(iter.moveNext(), false);
    });

    test('header-aware access via iterator', () {
      final table = CsvTable.fromData(
        headers: ['name', 'age'],
        rows: [
          ['Alice', 30],
        ],
      );
      final iter = table.iterator;
      iter.moveNext();
      expect(iter.current['name'], 'Alice');
      expect(iter.current['age'], 30);
    });
  });

  group('CsvTable.inferSchema', () {
    test('infers schema from table data', () {
      final table = CsvTable.fromData(
        headers: ['name', 'age'],
        rows: [
          ['Alice', 30],
          ['Bob', 25],
        ],
      );
      final schema = table.inferSchema();
      expect(schema.columns.length, 2);
      expect(schema.columns[0].type, String);
      expect(schema.columns[1].type, int);
    });

    test('throws without headers', () {
      final table = CsvTable([
        [1, 2],
        [3, 4],
      ]);
      expect(() => table.inferSchema(), throwsA(isA<CsvException>()));
    });
  });
}
