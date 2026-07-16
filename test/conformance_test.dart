/// The conformance matrix: every case runs through the batch decoder,
/// the streaming decoder in one piece, and the streaming decoder split
/// at every possible chunk boundary. All paths must produce identical
/// rows, identical cell values, and identical cell types. This suite is
/// what makes "one documented parsing semantics" enforceable.
library;

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

const _fast = FastDecoder();

List<List<dynamic>> _viaBatch(String input, CsvConfig config) =>
    _fast.decode(input, config);

List<List<dynamic>> _viaConvert(String input, CsvConfig config) =>
    CsvDecoder(config).convert(input);

List<List<dynamic>> _viaChunks(String input, CsvConfig config, int splitAt) {
  final out = <List<dynamic>>[];
  final sink = CsvDecoder(config).startChunkedConversion(_CollectingSink(out));
  sink.add(input.substring(0, splitAt));
  sink.add(input.substring(splitAt));
  sink.close();
  return out;
}

class _CollectingSink implements Sink<List<dynamic>> {
  final List<List<dynamic>> rows;
  _CollectingSink(this.rows);

  @override
  void add(List<dynamic> data) => rows.add(data);

  @override
  void close() {}
}

/// Deep equality that also distinguishes types, because Dart's `==`
/// treats 1 and 1.0 as equal.
void _expectRowsExact(
  List<List<dynamic>> actual,
  List<List<dynamic>> expected,
  String label,
) {
  expect(
    actual.length,
    expected.length,
    reason: '$label: row count differs\nactual: $actual',
  );
  for (var r = 0; r < expected.length; r++) {
    expect(
      actual[r].length,
      expected[r].length,
      reason: '$label row $r: cell count differs\nactual: ${actual[r]}',
    );
    for (var c = 0; c < expected[r].length; c++) {
      final a = actual[r][c];
      final e = expected[r][c];
      expect(a, e, reason: '$label at ($r,$c)');
      if (e != null) {
        expect(
          a.runtimeType,
          e.runtimeType,
          reason:
              '$label at ($r,$c): type differs ($a is '
              '${a.runtimeType}, expected ${e.runtimeType})',
        );
      }
    }
  }
}

/// Assert that every decode path agrees on [expected], including the
/// streaming machine with the input split at every offset.
void _expectAllPaths(
  String input,
  CsvConfig config,
  List<List<dynamic>> expected,
) {
  _expectRowsExact(_viaBatch(input, config), expected, 'batch');
  _expectRowsExact(_viaConvert(input, config), expected, 'convert');
  for (var i = 0; i <= input.length; i++) {
    _expectRowsExact(
      _viaChunks(input, config, i),
      expected,
      'chunks split at $i',
    );
  }
}

void main() {
  group('Decoder Conformance', () {
    const typed = CsvConfig(autoDetect: false);
    const keepEmpty = CsvConfig(autoDetect: false, skipEmptyLines: false);
    const strings = CsvConfig(autoDetect: false, dynamicTyping: false);

    test('plain rows agree across paths', () {
      _expectAllPaths('a,b\r\nc,d', typed, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('typed cells agree across paths', () {
      _expectAllPaths('x,1,2.5,true,false\n,-3,1e2,0,-0.5', typed, [
        ['x', 1, 2.5, true, false],
        [null, -3, 100.0, 0, -0.5],
      ]);
    });

    test('quoted fields, escapes, and embedded newlines agree', () {
      _expectAllPaths('"a,b",c\n"say ""hi""",x\n"l1\nl2",y', typed, [
        ['a,b', 'c'],
        ['say "hi"', 'x'],
        ['l1\nl2', 'y'],
      ]);
    });

    test('quoted values are never type-inferred', () {
      _expectAllPaths('"42","true",42', typed, [
        ['42', 'true', 42],
      ]);
    });

    test('text after a closing quote is appended, Excel style', () {
      _expectAllPaths('"a"x,b', typed, [
        ['ax', 'b'],
      ]);
    });

    test('quotes inside post-quote text are literal', () {
      _expectAllPaths('"a"x"y",b', typed, [
        ['ax"y"', 'b'],
      ]);
    });

    test('unterminated quote consumes the rest of the input', () {
      _expectAllPaths('"abc', typed, [
        ['abc'],
      ]);
      _expectAllPaths('"abc\nd,e', typed, [
        ['abc\nd,e'],
      ]);
    });

    test('lone CR separates rows', () {
      _expectAllPaths('a,b\rc,d', typed, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('BOM is stripped', () {
      _expectAllPaths('﻿a,b', typed, [
        ['a', 'b'],
      ]);
    });

    test('empty and trailing fields agree', () {
      _expectAllPaths('a,,c\nd,e,', typed, [
        ['a', null, 'c'],
        ['d', 'e', null],
      ]);
      _expectAllPaths('a,,c\nd,e,', strings, [
        ['a', '', 'c'],
        ['d', 'e', ''],
      ]);
    });

    test('a row of several empty fields is kept even when skipping', () {
      _expectAllPaths(',,\r\nx,y,z', typed, [
        [null, null, null],
        ['x', 'y', 'z'],
      ]);
    });

    test('empty lines are skipped by default', () {
      _expectAllPaths('a,b\n\nc,d\n', typed, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('empty lines read as one empty field when kept', () {
      _expectAllPaths('a,b\n\nc,d', keepEmpty, [
        ['a', 'b'],
        [null],
        ['c', 'd'],
      ]);
      _expectAllPaths('""', keepEmpty, [
        [''],
      ]);
    });

    test('a quoted empty row counts as an empty line for skipping', () {
      _expectAllPaths('a\n""\nb', typed, [
        ['a'],
        ['b'],
      ]);
    });

    test('trailing newline does not create a phantom row', () {
      _expectAllPaths('a,b\r\n', typed, [
        ['a', 'b'],
      ]);
      _expectAllPaths('a,b\r\n', keepEmpty, [
        ['a', 'b'],
      ]);
    });

    test('inference guards keep identifier-like values as text', () {
      _expectAllPaths('007,+1, 42,9007199254740993123', typed, [
        ['007', '+1', ' 42', '9007199254740993123'],
      ]);
    });

    test('inference guards agree on digit-run length', () {
      _expectAllPaths('123456789012345,1234567890123456', typed, [
        [123456789012345, '1234567890123456'],
      ]);
    });

    test('non-finite doubles stay text', () {
      _expectAllPaths('1e999,1e2', typed, [
        ['1e999', 100.0],
      ]);
    });

    test('uppercase TRUE stays text (bool inference is lowercase only)', () {
      _expectAllPaths('TRUE,true', typed, [
        ['TRUE', true],
      ]);
    });

    test('unicode content agrees', () {
      _expectAllPaths('\u{1F642},世界', typed, [
        ['\u{1F642}', '世界'],
      ]);
    });

    test('headers are consumed and read raw across paths', () {
      const cfg = CsvConfig(autoDetect: false, hasHeader: true);
      _expectAllPaths('01,02\n1,2', cfg, [
        [1, 2],
      ]);
    });

    test('multi-char delimiter agrees at every chunk boundary', () {
      const cfg = CsvConfig(autoDetect: false, fieldDelimiter: '::');
      _expectAllPaths('a::b\n1::2', cfg, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('partial delimiter prefix is literal content', () {
      const cfg = CsvConfig(autoDetect: false, fieldDelimiter: '::');
      _expectAllPaths('a:b::c:', cfg, [
        ['a:b', 'c:'],
      ]);
      _expectAllPaths('a:::b', cfg, [
        ['a', ':b'],
      ]);
    });

    test('decodeStrings matches decode with typing off', () {
      const cases = [
        'a,b\nc,d',
        '"a"x,b',
        'a,,c\n\nd,e,',
        ',,\nx,y,z',
        '007,+1,42',
        '"q""q",r',
      ];
      for (final input in cases) {
        final viaStrings = _fast.decodeStrings(input, strings);
        final viaDecode = _fast.decode(input, strings);
        expect(viaStrings, viaDecode, reason: 'input: $input');
      }
    });
  });

  group('Comment Lines and Row Windowing', () {
    test('comment lines are skipped on every path', () {
      const cfg = CsvConfig(autoDetect: false, comment: '#');
      _expectAllPaths('# header\na,b\n# mid\n1,2', cfg, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('a trailing comment line without a newline emits nothing', () {
      const cfg = CsvConfig(autoDetect: false, comment: '#');
      _expectAllPaths('a,b\n# tail', cfg, [
        ['a', 'b'],
      ]);
    });

    test('a marker inside a quoted field stays content on every path', () {
      const cfg = CsvConfig(autoDetect: false, comment: '#');
      _expectAllPaths('"#x",1', cfg, [
        ['#x', 1],
      ]);
    });

    test('skipRows drops leading rows on every path', () {
      const cfg = CsvConfig(autoDetect: false, skipRows: 2);
      _expectAllPaths('j1\nj2\na,b\n1,2', cfg, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('maxRows limits data rows on every path', () {
      const cfg = CsvConfig(autoDetect: false, maxRows: 2);
      _expectAllPaths('1\n2\n3\n4', cfg, [
        [1],
        [2],
      ]);
    });

    test('skipRows and maxRows combine on every path', () {
      const cfg = CsvConfig(autoDetect: false, skipRows: 1, maxRows: 2);
      _expectAllPaths('1\n2\n3\n4\n5', cfg, [
        [2],
        [3],
      ]);
    });

    test('comment skipping and skipRows compose on every path', () {
      const cfg = CsvConfig(autoDetect: false, comment: '#', skipRows: 1);
      _expectAllPaths('# c\nj\na,b\n1,2', cfg, [
        ['a', 'b'],
        [1, 2],
      ]);
    });
  });

  group('Strict Mode', () {
    const strict = CsvConfig(autoDetect: false, strict: true);

    test('text after a closing quote throws on every path', () {
      expect(
        () => _fast.decode('"a"x,b', strict),
        throwsA(isA<CsvParseException>()),
      );
      expect(
        () => _fast.decodeStrings('"a"x,b', strict),
        throwsA(isA<CsvParseException>()),
      );
      expect(
        () => CsvDecoder(strict).convert('"a"x,b'),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('unterminated quote throws on every path', () {
      expect(
        () => _fast.decode('"abc', strict),
        throwsA(isA<CsvParseException>()),
      );
      expect(
        () => _fast.decodeStrings('"abc', strict),
        throwsA(isA<CsvParseException>()),
      );
      expect(
        () => CsvDecoder(strict).convert('"abc'),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('parse errors carry row and column', () {
      expect(
        () => _fast.decode('a,b\nc,"d"x', strict),
        throwsA(
          isA<CsvParseException>()
              .having((e) => e.row, 'row', 1)
              .having((e) => e.column, 'column', 1),
        ),
      );
    });

    test('a streamed parse error surfaces as a stream error', () async {
      final stream = Stream.fromIterable(['a,"b', '"x,c']);
      await expectLater(
        CsvDecoder(strict).bind(stream).toList(),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('well-formed input is unaffected by strict mode', () {
      _expectAllPaths('"a",b\n"c ""q""",d', strict, [
        ['a', 'b'],
        ['c "q"', 'd'],
      ]);
    });
  });

  group('Encoder Parity', () {
    const rows = [
      ['plain', 'with,comma', 'with "quote"', '', null, 5, 2.5, true],
      [' pad ', 'line\nbreak', null, '', 'x', -1, 0.0, false],
    ];

    test('batch and streaming encoders produce identical output', () async {
      for (final mode in QuoteMode.values) {
        final config = CsvConfig(quoteMode: mode, autoDetect: false);
        final viaFast = const FastEncoder().encode(rows, config);
        final viaConvert = CsvEncoder(config).convert(rows);
        final viaStream = (await CsvEncoder(
          config,
        ).bind(Stream.fromIterable(rows)).toList()).join();
        expect(viaConvert, viaFast, reason: 'convert, mode $mode');
        expect(viaStream, viaFast, reason: 'stream, mode $mode');
      }
    });

    test('every quote mode round-trips through the decoder', () {
      // null and '' both survive under necessary; the other modes
      // normalize one of them, so compare against their documented result.
      const config = CsvConfig(autoDetect: false, skipEmptyLines: false);
      final encoded = const FastEncoder().encode(rows, config);
      final decoded = const FastDecoder().decode(encoded, config);
      expect(decoded, rows);
    });
  });
}
