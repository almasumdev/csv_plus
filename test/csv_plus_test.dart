import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvConfig', () {
    test('default values', () {
      const config = CsvConfig();
      expect(config.fieldDelimiter, ',');
      expect(config.lineDelimiter, '\r\n');
      expect(config.quoteCharacter, '"');
      expect(config.escapeCharacter, '"');
      expect(config.quoteMode, QuoteMode.necessary);
      expect(config.addBom, false);
      expect(config.autoDetect, true);
      expect(config.skipEmptyLines, true);
      expect(config.hasHeader, false);
      expect(config.dynamicTyping, true);
    });

    test('excel preset', () {
      const config = CsvConfig.excel();
      expect(config.fieldDelimiter, ';');
      expect(config.addBom, true);
      expect(config.autoDetect, false);
    });

    test('tsv preset', () {
      const config = CsvConfig.tsv();
      expect(config.fieldDelimiter, '\t');
    });

    test('pipe preset', () {
      const config = CsvConfig.pipe();
      expect(config.fieldDelimiter, '|');
    });

    test('copyWith', () {
      const config = CsvConfig();
      final copy = config.copyWith(fieldDelimiter: ';', addBom: true);
      expect(copy.fieldDelimiter, ';');
      expect(copy.addBom, true);
      expect(copy.lineDelimiter, '\r\n'); // unchanged
    });
  });

  group('FastDecoder', () {
    const decoder = FastDecoder();
    const config = CsvConfig();

    test('empty input', () {
      expect(decoder.decode('', config), isEmpty);
    });

    test('simple CSV', () {
      final result = decoder.decode('a,b,c\n1,2,3', config);
      expect(result, [
        ['a', 'b', 'c'],
        [1, 2, 3],
      ]);
    });

    test('CRLF line endings', () {
      final result = decoder.decode('a,b\r\n1,2', config);
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('CR only line endings', () {
      final result = decoder.decode('a,b\r1,2', config);
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('dynamic typing - integers', () {
      final result = decoder.decode('42,-7,0', config);
      expect(result[0], [42, -7, 0]);
      expect(result[0][0], isA<int>());
    });

    test('dynamic typing - doubles', () {
      final result = decoder.decode('3.14,-2.5,1e10', config);
      expect(result[0][0], 3.14);
      expect(result[0][1], -2.5);
      expect(result[0][2], isA<double>());
    });

    test('dynamic typing - booleans', () {
      final result = decoder.decode('true,false', config);
      expect(result[0], [true, false]);
    });

    test('dynamic typing - null (empty fields)', () {
      final result = decoder.decode('a,,b', config);
      expect(result[0], ['a', null, 'b']);
    });

    test('quoted strings', () {
      final result = decoder.decode('"hello","world"', config);
      expect(result[0], ['hello', 'world']);
    });

    test('quoted strings with commas', () {
      final result = decoder.decode('"a,b",c', config);
      expect(result[0], ['a,b', 'c']);
    });

    test('quoted strings with newlines', () {
      final result = decoder.decode('"line1\nline2",b', config);
      expect(result[0], ['line1\nline2', 'b']);
    });

    test('escaped quotes (doubling)', () {
      final result = decoder.decode('"say ""hello""",b', config);
      expect(result[0], ['say "hello"', 'b']);
    });

    test('UTF-8 BOM stripped', () {
      final result = decoder.decode('\uFEFFa,b\n1,2', config);
      expect(result[0], ['a', 'b']);
    });

    test('skip empty lines', () {
      final result = decoder.decode('a\n\nb', config);
      expect(result, [
        ['a'],
        ['b'],
      ]);
    });

    test('keep empty lines when configured', () {
      final cfg = config.copyWith(skipEmptyLines: false);
      final result = decoder.decode('a\n\nb', cfg);
      expect(result.length, 3);
    });

    test('trailing newline does not create phantom row', () {
      final result = decoder.decode('a,b\n1,2\n', config);
      expect(result.length, 2);
    });

    test('dynamic typing off - all strings', () {
      final cfg = config.copyWith(dynamicTyping: false);
      final result = decoder.decode('42,true,hello', cfg);
      expect(result[0], ['42', 'true', 'hello']);
      expect(result[0][0], isA<String>());
    });

    test('hasHeader strips first row', () {
      final cfg = config.copyWith(hasHeader: true);
      final result = decoder.decode('name,age\nAlice,30', cfg);
      expect(result.length, 1);
      expect(result[0], ['Alice', 30]);
    });

    test('multi-char delimiter', () {
      final cfg = config.copyWith(fieldDelimiter: '::');
      final result = decoder.decode('a::b::c\n1::2::3', cfg);
      expect(result, [
        ['a', 'b', 'c'],
        [1, 2, 3],
      ]);
    });

    test('tab delimiter', () {
      const cfg = CsvConfig.tsv();
      final result = decoder.decode('a\tb\n1\t2', cfg);
      expect(result, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('mixed types in a row', () {
      final result = decoder.decode('"Alice",30,true,3.14,', config);
      expect(result[0], ['Alice', 30, true, 3.14, null]);
    });

    test('decoder transform', () {
      final cfg = CsvConfig(
        decoderTransform: (value, index, header) {
          if (value is String) return value.toUpperCase();
          return value;
        },
      );
      final result = decoder.decode('"hello","world"', cfg);
      expect(result[0], ['HELLO', 'WORLD']);
    });

    test('decodeStrings - all strings', () {
      final result = decoder.decodeStrings('a,42,true\nhello,world,!', config);
      expect(result, [
        ['a', '42', 'true'],
        ['hello', 'world', '!'],
      ]);
      expect(result[0][1], isA<String>());
    });

    test('scientific notation', () {
      final result = decoder.decode('1.5e3,-2.3e-4', config);
      expect(result[0][0], 1500.0);
      expect(result[0][1], closeTo(-0.00023, 1e-10));
    });

    test('boolean not confused with text starting with t/f', () {
      final result = decoder.decode('test,flag', config);
      expect(result[0], ['test', 'flag']);
    });

    test('unquoted strings', () {
      final cfg = config.copyWith(dynamicTyping: false);
      final result = decoder.decode('hello,world', cfg);
      expect(result[0], ['hello', 'world']);
    });
  });

  group('FastEncoder', () {
    const encoder = FastEncoder();
    const config = CsvConfig();

    test('empty input', () {
      expect(encoder.encode([], config), '');
    });

    test('simple CSV', () {
      final result = encoder.encode([
        ['a', 'b'],
        [1, 2],
      ], config);
      expect(result, 'a,b\r\n1,2');
    });

    test('null values encoded as empty', () {
      final result = encoder.encode([
        ['a', null, 'b'],
      ], config);
      expect(result, 'a,,b');
    });

    test('booleans', () {
      final result = encoder.encode([
        [true, false],
      ], config);
      expect(result, 'true,false');
    });

    test('quoting strings with commas', () {
      final result = encoder.encode([
        ['a,b', 'c'],
      ], config);
      expect(result, '"a,b",c');
    });

    test('quoting strings with quotes', () {
      final result = encoder.encode([
        ['say "hi"', 'ok'],
      ], config);
      expect(result, '"say ""hi""",ok');
    });

    test('quoting strings with newlines', () {
      final result = encoder.encode([
        ['line1\nline2', 'ok'],
      ], config);
      expect(result, '"line1\nline2",ok');
    });

    test('quoting strings with leading spaces', () {
      final result = encoder.encode([
        [' hello', 'ok'],
      ], config);
      expect(result, '" hello",ok');
    });

    test('empty string quoted to distinguish from null', () {
      final result = encoder.encode([
        ['', null],
      ], config);
      expect(result, '"",');
    });

    test('QuoteMode.always', () {
      final cfg = config.copyWith(quoteMode: QuoteMode.always);
      final result = encoder.encode([
        ['a', 1],
      ], cfg);
      expect(result, '"a","1"');
    });

    test('QuoteMode.strings', () {
      final cfg = config.copyWith(quoteMode: QuoteMode.strings);
      final result = encoder.encode([
        ['a', 1, true],
      ], cfg);
      expect(result, '"a",1,true');
    });

    test('BOM added', () {
      final cfg = config.copyWith(addBom: true);
      final result = encoder.encode([
        ['a'],
      ], cfg);
      expect(result.codeUnitAt(0), 0xFEFF);
    });

    test('custom line delimiter', () {
      final cfg = config.copyWith(lineDelimiter: '\n');
      final result = encoder.encode([
        ['a'],
        ['b'],
      ], cfg);
      expect(result, 'a\nb');
    });

    test('encodeStrings', () {
      final result = encoder.encodeStrings([
        ['hello', 'world'],
      ], config);
      expect(result, '"hello","world"');
    });

    test('encodeGeneric int', () {
      final result = encoder.encodeGeneric<int>([
        [1, 2, 3],
      ], config);
      expect(result, '1,2,3');
    });

    test('encodeMap', () {
      final result = encoder.encodeMap({'name': 'Alice', 'age': 30}, config);
      expect(result, '"name",Alice\r\n"age",30');
    });

    test('encoder transform', () {
      final cfg = CsvConfig(
        encoderTransform: (value, index, header) {
          if (value is String) return value.toUpperCase();
          return value;
        },
      );
      final result = encoder.encode([
        ['hello', 42],
      ], cfg);
      expect(result, 'HELLO,42');
    });

    test('multi-char delimiter', () {
      final cfg = config.copyWith(fieldDelimiter: '::');
      final result = encoder.encode([
        ['a', 'b', 'c'],
      ], cfg);
      expect(result, 'a::b::c');
    });
  });

  group('CsvCodec', () {
    test('decode and encode round-trip', () {
      const codec = CsvCodec();
      final input = 'name,age\r\nAlice,30\r\nBob,25';
      final decoded = codec.decode(input);
      final encoded = codec.encode(decoded);
      expect(encoded, input);
    });

    test('decodeWithHeaders', () {
      const codec = CsvCodec();
      final rows = codec.decodeWithHeaders('name,age\nAlice,30\nBob,25');
      expect(rows.length, 2);
      expect(rows[0]['name'], 'Alice');
      expect(rows[0]['age'], 30);
      expect(rows[1]['name'], 'Bob');
    });

    test('decodeStrings', () {
      const codec = CsvCodec();
      final rows = codec.decodeStrings('a,b\n1,2');
      expect(rows[0], ['a', 'b']);
      expect(rows[1][0], '1');
    });

    test('encodeMap and decodeMap round-trip', () {
      const codec = CsvCodec();
      final map = {'key1': 'value1', 'key2': 42};
      final csv = codec.encodeMap(map);
      final decoded = codec.decodeMap(csv);
      expect(decoded['key1'], 'value1');
      expect(decoded['key2'], 42);
    });

    test('excel preset', () {
      const codec = CsvCodec.excel();
      expect(codec.config.fieldDelimiter, ';');
      expect(codec.config.addBom, true);
    });

    test('top-level instances', () {
      expect(csvPlus.config.fieldDelimiter, ',');
      expect(csvExcel.config.fieldDelimiter, ';');
      expect(csvTsv.config.fieldDelimiter, '\t');
    });
  });

  group('CsvRow', () {
    test('index access', () {
      final row = CsvRow(['Alice', 30, true]);
      expect(row[0], 'Alice');
      expect(row[1], 30);
      expect(row[2], true);
    });

    test('header access', () {
      final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
      expect(row['name'], 'Alice');
      expect(row['age'], 30);
    });

    test('missing header returns null', () {
      final row = CsvRow(['Alice'], {'name': 0});
      expect(row['missing'], null);
    });

    test('set by index', () {
      final row = CsvRow(['Alice', 30]);
      row[0] = 'Bob';
      expect(row[0], 'Bob');
    });

    test('set by header name', () {
      final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
      row.set('age', 31);
      expect(row['age'], 31);
    });

    test('toMap', () {
      final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
      expect(row.toMap(), {'name': 'Alice', 'age': 30});
    });

    test('getHeaderName', () {
      final row = CsvRow(['Alice'], {'name': 0});
      expect(row.getHeaderName(0), 'name');
      expect(row.getHeaderName(1), null);
    });

    test('length', () {
      final row = CsvRow(['a', 'b', 'c']);
      expect(row.length, 3);
    });

    test('works as List', () {
      final row = CsvRow([1, 2, 3]);
      expect(row.map((e) => e * 2).toList(), [2, 4, 6]);
    });
  });

  group('Round-trip edge cases', () {
    const codec = CsvCodec();

    test('strings with all special characters', () {
      final data = [
        ['comma,here', 'quote"here', 'newline\nhere', ' spaces '],
      ];
      final csv = codec.encode(data);
      final decoded = codec.decode(csv);
      expect(decoded[0][0], 'comma,here');
      expect(decoded[0][1], 'quote"here');
      expect(decoded[0][2], 'newline\nhere');
      expect(decoded[0][3], ' spaces ');
    });

    test('all types round-trip', () {
      final data = [
        ['text', 42, 3.14, true, false, null],
      ];
      final csv = codec.encode(data);
      final decoded = codec.decode(csv);
      expect(decoded[0][0], 'text');
      expect(decoded[0][1], 42);
      expect(decoded[0][2], 3.14);
      expect(decoded[0][3], true);
      expect(decoded[0][4], false);
      expect(decoded[0][5], null);
    });

    test('empty string vs null distinction', () {
      final csv = '"",\r\na,b';
      final decoded = codec.decode(csv);
      // empty quoted string should remain empty string
      expect(decoded[0][0], '');
      // empty unquoted field should be null
      expect(decoded[0][1], null);
    });

    test('single field', () {
      final decoded = codec.decode('hello');
      expect(decoded, [
        ['hello'],
      ]);
    });

    test('single empty field', () {
      // A row of one empty field is an empty line per RFC 4180, so the
      // default skipEmptyLines drops it; without skipping it reads [''].
      expect(codec.decode('""'), isEmpty);
      final keepEmpty = CsvCodec(CsvConfig(skipEmptyLines: false));
      expect(keepEmpty.decode('""'), [
        [''],
      ]);
    });
  });
}
