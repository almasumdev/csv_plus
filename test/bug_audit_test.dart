import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Tests that expose bugs found during codebase audit.
/// Each test documents the bug and expected correct behavior.
void main() {
  final codec = CsvCodec();
  final typed = CsvCodec(CsvConfig(dynamicTyping: true));
  const decoder = FastDecoder();
  const config = CsvConfig();
  const typedConfig = CsvConfig(dynamicTyping: true);

  group('BUG 1: Unmatched quote drops last character', () {
    // The substring optimization uses `input.substring(start, cursor - 1)`
    // which assumes cursor is one past the closing quote.
    // When there's no closing quote, cursor == len, and we lose the last char.

    test('decode: unclosed quote preserves all content', () {
      final result = decoder.decode('"hello', typedConfig);
      // Should be "hello", not "hell"
      expect(result[0][0], 'hello');
    });

    test('decodeStrings: unclosed quote preserves all content', () {
      final result = decoder.decodeStrings('"hello', config);
      expect(result[0][0], 'hello');
    });

    test('decode: unclosed quote with escape preserves content', () {
      final result = decoder.decode('"he said ""hi', typedConfig);
      // Should preserve everything after stripping the escaped quote
      expect(result[0][0], 'he said "hi');
    });

    test('decode: unclosed quote mid-row', () {
      final result = typed.decode('"hello\n1,2');
      // First row: unclosed quote spans to LF (which is inside the quote)
      // This is complex; at minimum it shouldn't crash
      expect(result, isNotEmpty);
    });

    test('decodeStrings: single quote char only', () {
      // Single " is an unclosed empty quoted field, reads as empty string
      // With skipEmptyLines=true (default), all-empty row is skipped
      final result = decoder.decodeStrings('"', config);
      expect(result, isEmpty);

      // With skipEmptyLines=false, the empty row is preserved
      final noSkip = const CsvConfig(skipEmptyLines: false);
      final result2 = decoder.decodeStrings('"', noSkip);
      expect(result2.length, 1);
      expect(result2[0][0], '');
    });
  });

  group('BUG 2: Number parser splits alphanumeric fields', () {
    // The inline number parser stops at non-digit chars but doesn't verify
    // the field ends at a delimiter. Leftover chars become a spurious cell.

    test('decode: 123hello should be single string cell', () {
      final result = typed.decode('123hello,world');
      expect(result[0].length, 2); // NOT 3
      expect(result[0][0], '123hello');
      expect(result[0][1], 'world');
    });

    test('decode: -3.14rad should be single string cell', () {
      final result = typed.decode('-3.14rad,ok');
      expect(result[0].length, 2);
      expect(result[0][0], '-3.14rad');
    });

    test('decode: 42abc at end of line', () {
      final result = typed.decode('42abc');
      expect(result[0].length, 1);
      expect(result[0][0], '42abc');
    });

    test('decode: pure numbers still work', () {
      final result = typed.decode('42,3.14,-7');
      expect(result[0], [42, 3.14, -7]);
    });

    test('decode: number at field boundary still parsed', () {
      final result = typed.decode('123,456');
      expect(result[0], [123, 456]);
    });

    test('decode: 1e2x should be string', () {
      final result = typed.decode('1e2x');
      expect(result[0].length, 1);
      expect(result[0][0], '1e2x');
    });
  });

  group('BUG 3: Encoder skips quoting for non-String objects', () {
    // FastEncoder in QuoteMode.necessary checks `cell is! String` to skip
    // _needsQuoting. But custom objects with commas in toString() break CSV.

    test('list cell toString with comma gets quoted', () {
      final result = codec.encode([
        [
          [1, 2, 3]
        ]
      ]);
      // [1, 2, 3].toString() = "[1, 2, 3]" contains a comma, must be quoted
      expect(result, contains('"'));
    });

    test('map cell toString with comma gets quoted', () {
      final result = codec.encode([
        [
          {'a': 1}
        ]
      ]);
      // {a: 1}.toString() = "{a: 1}" has no comma, no need to quote
      // But just verify it doesn't break
      expect(result, isNotEmpty);
    });

    test('int and double cells still unquoted', () {
      final result = codec.encode([
        [42, 3.14, true, false]
      ]);
      expect(result, '42,3.14,true,false');
    });
  });

  group('BUG 4: CsvFile.append adds newline to empty file', () {
    // This is dart:io only, tested separately.
    // CsvFile.append checks File.exists() but not file.length > 0.
    // An empty existing file gets a leading newline.
    // Marking as known issue; requires dart:io test.
  });
}
