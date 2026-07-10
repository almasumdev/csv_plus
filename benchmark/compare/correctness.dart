// Edge-case battery: what does each package produce for tricky inputs?
// csv_plus is run through BOTH its batch decoder and its streaming decoder
// to expose divergence between the two paths.
import 'package:csv/csv.dart' as csv8;
import 'package:csv_plus/csv_plus.dart' as plus;

const cases = <String, String>{
  'basic CRLF': 'a,b\r\nc,d',
  'quoted delimiter': '"a,b",c',
  'escaped quotes': '"say ""hi""",x',
  'embedded newline': '"line1\nline2",y',
  'lone CR rows': 'a,b\rc,d',
  'BOM prefix': '﻿a,b',
  'empty fields': 'a,,c',
  'trailing comma': 'a,b,',
  'all-empty row': ',,\r\nx,y,z',
  'empty middle line': 'a,b\n\nc,d',
  'trailing newline': 'a,b\n',
  'junk after quote': '"a"x,b',
  'unterminated quote': '"abc',
  'unicode': '\u{1F642},世界',
  'leading zeros (typed)': '007,08',
  'big int 19 digits (typed)': '9007199254740993123,1',
  'whitespace int (typed)': ' 42,7',
  'uppercase TRUE (typed)': 'TRUE,FALSE',
  'sep= hint line': 'sep=;\na;b',
  'semicolons in text (single col)': 'note\nhello; world\nsee; you',
};

String show(List<List<dynamic>> rows) => rows
    .map(
      (r) => '[${r.map((f) => f is String ? '"$f"' : '<$f>').join('|')}]',
    )
    .join(' ');

void main() {
  final c8s = csv8.Csv(autoDetect: false, skipEmptyLines: false);
  final c8t = csv8.Csv(
    autoDetect: false,
    skipEmptyLines: false,
    dynamicTyping: true,
  );
  final c8auto = csv8.Csv(skipEmptyLines: false, dynamicTyping: true);
  final pStr = plus.CsvCodec(
    plus.CsvConfig(autoDetect: false, skipEmptyLines: false),
  );
  final pTypedCfg = plus.CsvConfig(autoDetect: false, skipEmptyLines: false);
  final pAuto = plus.CsvCodec(plus.CsvConfig(skipEmptyLines: false));

  for (final entry in cases.entries) {
    final input = entry.value;
    print(
        '=== ${entry.key}: ${input.replaceAll('\n', r'\n').replaceAll('\r', r'\r').replaceAll('﻿', '<BOM>')}');
    String attempt(String label, List<List<dynamic>> Function() f) {
      try {
        return '$label: ${show(f())}';
      } catch (e) {
        return '$label: THROWS ${e.runtimeType}';
      }
    }

    print(attempt('  csv8 str      ', () => c8s.decode(input)));
    print(attempt('  csv8 typed    ', () => c8t.decode(input)));
    print(attempt('  csv8 auto+t   ', () => c8auto.decode(input)));
    print(attempt('  plus strings  ', () => pStr.decodeStrings(input)));
    print(attempt('  plus typed    ', () => pStr.decode(input)));
    print(attempt('  plus auto+t   ', () => pAuto.decode(input)));
    print(attempt('  plus streaming', () {
      return plus.CsvDecoder(pTypedCfg).convert(input);
    }));
    print('');
  }

  // Encode comparison: how is an awkward row written?
  final row = [
    ['plain', 'with,comma', 'with "quote"', '', null, 5, 2.5, true, ' pad '],
  ];
  print('=== ENCODE awkward row');
  print('  csv8:     ${c8s.encode(row).replaceAll('\r\n', r'\r\n')}');
  print(
    '  csv_plus: ${pStr.encode(row).replaceAll('\r\n', r'\r\n')}',
  );
}
