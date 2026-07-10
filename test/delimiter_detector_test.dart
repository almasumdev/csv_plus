import 'package:csv_plus/decoder.dart';
import 'package:test/test.dart';

void main() {
  group('DelimiterDetector', () {
    const detector = DelimiterDetector();

    test('detects comma delimiter', () {
      expect(detector.detectDelimiter('a,b,c\n1,2,3'), ',');
    });

    test('detects semicolon delimiter', () {
      expect(detector.detectDelimiter('a;b;c\n1;2;3'), ';');
    });

    test('detects tab delimiter', () {
      expect(detector.detectDelimiter('a\tb\tc\n1\t2\t3'), '\t');
    });

    test('detects pipe delimiter', () {
      expect(detector.detectDelimiter('a|b|c\n1|2|3'), '|');
    });

    test('defaults to comma on empty input', () {
      expect(detector.detectDelimiter(''), ',');
    });

    test('defaults to comma on single value', () {
      expect(detector.detectDelimiter('hello'), ',');
    });

    test('consistency bonus picks correct delimiter', () {
      // 2 semicolons per line consistently should beat 1 comma appearing once
      const csv = 'a;b;c\n1;2;3\n4;5;6';
      expect(detector.detectDelimiter(csv), ';');
    });

    test('ignores delimiters inside quotes', () {
      const csv = '"a,b";c;d\n"1,2";3;4';
      expect(detector.detectDelimiter(csv), ';');
    });

    group('stripBom', () {
      test('strips BOM when present', () {
        final (result, hadBom) = detector.stripBom('\uFEFFhello');
        expect(result, 'hello');
        expect(hadBom, true);
      });

      test('no-op without BOM', () {
        final (result, hadBom) = detector.stripBom('hello');
        expect(result, 'hello');
        expect(hadBom, false);
      });

      test('empty string', () {
        final (result, hadBom) = detector.stripBom('');
        expect(result, '');
        expect(hadBom, false);
      });
    });

    group('checkSepHint', () {
      test('detects sep= hint', () {
        final (remaining, sep) = detector.checkSepHint('sep=;\na;b\n1;2');
        expect(sep, ';');
        expect(remaining, 'a;b\n1;2');
      });

      test('handles CRLF after sep hint', () {
        final (remaining, sep) = detector.checkSepHint('sep=;\r\na;b\r\n1;2');
        expect(sep, ';');
        expect(remaining, 'a;b\r\n1;2');
      });

      test('returns null when no hint', () {
        final (remaining, sep) = detector.checkSepHint('a,b\n1,2');
        expect(sep, null);
        expect(remaining, 'a,b\n1,2');
      });

      test('short input returns null', () {
        final (_, sep) = detector.checkSepHint('ab');
        expect(sep, null);
      });
    });

    group('single-column guard', () {
      test('semicolons inside prose do not win over the comma default', () {
        // A real delimiter appears on every row; this one is missing from
        // the first line, so the file is a single column.
        final delim = detector.detectDelimiter('note\nhello; world\nsee; you');
        expect(delim, ',');
      });

      test('a consistent semicolon on every line is detected', () {
        expect(detector.detectDelimiter('a;b\nc;d\ne;f'), ';');
      });

      test('a single header-only line is detected', () {
        expect(detector.detectDelimiter('a;b;c'), ';');
      });

      test('empty lines in the sample are ignored', () {
        expect(detector.detectDelimiter('a;b\n\nc;d'), ';');
      });

      test('ambiguous mixed delimiters prefer the comma', () {
        expect(detector.detectDelimiter('a,b;c\nd,e;f'), ',');
      });
    });
  });
}
