import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Edge-case tests verifying optimization safety.
/// Covers: c<=13 guard, delimiter-first loops, encoder _needsQuoting,
/// Boolean byte checks, empty-row tracking, and more.
void main() {
  final codec = CsvCodec();
  final typed = CsvCodec(CsvConfig(dynamicTyping: true));

  group('c<=13 guard safety', () {
    test('tab delimiter works (tab=9, within <=13 range)', () {
      final tabCodec = CsvCodec(
        CsvConfig(fieldDelimiter: '\t', dynamicTyping: true),
      );
      final result = tabCodec.decode('a\tb\tc\n1\t2\t3');
      expect(result, [
        ['a', 'b', 'c'],
        [1, 2, 3],
      ]);
    });

    test('null byte in field preserved (codeUnit 0)', () {
      final result = codec.decodeStrings('a,b\nhel\x00lo,world');
      expect(result[1][0], 'hel\x00lo');
    });

    test('vertical tab (11) and form feed (12) in fields', () {
      final result = codec.decodeStrings('a,b\nhel\x0Blo,wor\x0Cld');
      expect(result[1][0], 'hel\x0Blo');
      expect(result[1][1], 'wor\x0Cld');
    });

    test('backspace (8) in field', () {
      final result = codec.decodeStrings('a,b\nhel\x08lo,world');
      expect(result[1][0], 'hel\x08lo');
    });
  });

  group('delimiter-first loop safety', () {
    test('consecutive delimiters (empty fields) in decode', () {
      final result = typed.decode('a,,c\n1,,3');
      expect(result[0], ['a', null, 'c']);
      expect(result[1], [1, null, 3]);
    });

    test('consecutive delimiters in decodeStrings', () {
      final result = codec.decodeStrings('a,,c\n1,,3');
      expect(result[0][1], '');
      expect(result[1][1], '');
    });

    test('trailing delimiter produces empty field', () {
      final result = codec.decodeStrings('a,b,\nc,d,');
      expect(result[0], ['a', 'b', '']);
      expect(result[1], ['c', 'd', '']);
    });

    test('multi-char delimiter with c<=13 guard', () {
      final multiCodec = CsvCodec(CsvConfig(fieldDelimiter: '||'));
      final result = multiCodec.decodeStrings('a||b||c\n1||2||3');
      expect(result.length, 2);
      expect(result[0], ['a', 'b', 'c']);
    });
  });

  group('encoder _needsQuoting optimization', () {
    test('non-String cells skip quoting in necessary mode', () {
      final result = codec.encode([
        [1, 2.5, true, null, 'hello', 'has,comma'],
      ]);
      expect(result, '1,2.5,true,,hello,"has,comma"');
    });

    test('empty string is quoted to distinguish from null', () {
      final result = codec.encode([
        ['', 'a'],
      ]);
      expect(result, '"",a');
    });

    test('string with newline is quoted', () {
      final result = codec.encode([
        ['line1\nline2'],
      ]);
      expect(result, '"line1\nline2"');
    });

    test('string with CR is quoted', () {
      final result = codec.encode([
        ['line1\rline2'],
      ]);
      expect(result, '"line1\rline2"');
    });

    test('string with leading/trailing space is quoted', () {
      final result = codec.encode([
        [' hello ', 'world'],
      ]);
      expect(result, '" hello ",world');
    });

    test('string with quote escapes correctly', () {
      final result = codec.encode([
        ['say "hi"'],
      ]);
      expect(result, '"say ""hi"""');
    });

    test('QuoteMode.always still quotes ints', () {
      final alwaysCodec = CsvCodec(CsvConfig(quoteMode: QuoteMode.always));
      final result = alwaysCodec.encode([
        [1, 'hi'],
      ]);
      expect(result, '"1","hi"');
    });

    test('QuoteMode.strings quotes strings but not ints', () {
      final strCodec = CsvCodec(CsvConfig(quoteMode: QuoteMode.strings));
      final result = strCodec.encode([
        [1, 'hi'],
      ]);
      expect(result, '1,"hi"');
    });
  });

  group('boolean byte-check safety', () {
    test('truthy is string not bool', () {
      final result = typed.decode('truthy,falsehood');
      expect(result[0][0], 'truthy');
      expect(result[0][1], 'falsehood');
    });

    test('true and false are booleans', () {
      final result = typed.decode('true,false');
      expect(result[0][0], true);
      expect(result[0][1], false);
    });

    test('TRUE (uppercase) is string', () {
      final result = typed.decode('TRUE,FALSE');
      expect(result[0][0], 'TRUE');
      expect(result[0][1], 'FALSE');
    });

    test('true at EOF', () {
      final result = typed.decode('true');
      expect(result[0][0], true);
    });

    test('false at EOF', () {
      final result = typed.decode('false');
      expect(result[0][0], false);
    });
  });

  group('CRLF handling', () {
    test('CRLF in middle and end', () {
      final result = codec.decodeStrings('a,b\r\nc,d\r\n');
      expect(result.length, 2);
      expect(result[0], ['a', 'b']);
      expect(result[1], ['c', 'd']);
    });

    test('mixed LF and CRLF', () {
      final result = codec.decodeStrings('a,b\nc,d\r\ne,f\n');
      expect(result.length, 3);
    });

    test('CR only line endings', () {
      final result = codec.decodeStrings('a,b\rc,d\r');
      expect(result.length, 2);
    });
  });

  group('empty row tracking', () {
    test('skipEmptyLines=true skips empty rows', () {
      final result = codec.decodeStrings('a,b\n\nc,d');
      expect(result.length, 2);
    });

    test('skipEmptyLines=false preserves empty rows', () {
      final noSkip = CsvCodec(CsvConfig(skipEmptyLines: false));
      final result = noSkip.decodeStrings('a,b\n\nc,d');
      expect(result.length, 3);
      // An empty line reads as one empty field, per RFC 4180 (csv 8 and
      // fast_csv agree).
      expect(result[1], ['']);
    });
  });

  group('general edge cases', () {
    test('BOM handling', () {
      final result = codec.decodeStrings('\uFEFFa,b\nc,d');
      expect(result[0][0], 'a');
    });

    test('escaped quotes in field', () {
      final result = codec.decodeStrings('"he said ""hi""",b\nc,d');
      expect(result[0][0], 'he said "hi"');
    });

    test('single field single row', () {
      final result = codec.decodeStrings('hello');
      expect(result.length, 1);
      expect(result[0][0], 'hello');
    });

    test('no trailing newline', () {
      final result = codec.decodeStrings('a,b\nc,d');
      expect(result.length, 2);
    });

    test('empty input', () {
      expect(codec.decodeStrings(''), isEmpty);
      expect(typed.decode(''), isEmpty);
    });

    test('round-trip preserves types', () {
      final data = [
        ['name', 'age', 'active', 'score'],
        ['Alice', 30, true, 95.5],
        ['Bob', 25, false, null],
      ];
      final csv = codec.encode(data);
      final decoded = typed.decode(csv);
      expect(decoded[0], ['name', 'age', 'active', 'score']);
      expect(decoded[1], ['Alice', 30, true, 95.5]);
      expect(decoded[2][0], 'Bob');
      expect(decoded[2][1], 25);
      expect(decoded[2][2], false);
      expect(decoded[2][3], null);
    });
  });
}
