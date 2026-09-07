import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Decodes [input] through every typed path and asserts they agree.
///
/// nullValues was held back twice over exactly this risk, so the agreement is
/// checked on every case rather than assumed, including with the streaming
/// input split at every possible offset.
List<List<dynamic>> decodeAllPaths(String input, CsvConfig config) {
  final batch = CsvCodec(config).decode(input);
  expect(
    CsvDecoder(config).convert(input),
    batch,
    reason: 'streaming disagreed with batch',
  );
  for (var at = 1; at < input.length; at++) {
    final rows = <List<dynamic>>[];
    final sink = CsvDecoder(config).startChunkedConversion(
      ChunkedConversionSink<List<dynamic>>.withCallback(rows.addAll),
    );
    sink.add(input.substring(0, at));
    sink.add(input.substring(at));
    sink.close();
    expect(rows, batch, reason: 'chunk split at $at disagreed');
  }
  return batch;
}

void main() {
  group('Null Values', () {
    const cfg = CsvConfig(autoDetect: false, nullValues: {'NULL', 'NA', 'N/A'});

    test('a listed spelling decodes to null', () {
      expect(decodeAllPaths('a,NULL,b', cfg), [
        ['a', null, 'b'],
      ]);
      expect(decodeAllPaths('NA,x,N/A', cfg), [
        [null, 'x', null],
      ]);
    });

    test('off by default, the text survives', () {
      expect(decodeAllPaths('a,NULL,b', const CsvConfig(autoDetect: false)), [
        ['a', 'NULL', 'b'],
      ]);
    });

    test('matching is case-sensitive, so null is not NULL', () {
      expect(decodeAllPaths('a,null,b', cfg), [
        ['a', 'null', 'b'],
      ]);
    });

    test('a quoted value is never matched', () {
      // The whole point of quoting is to say "this is literal text".
      expect(decodeAllPaths('a,"NULL",b', cfg), [
        ['a', 'NULL', 'b'],
      ]);
    });

    test('an unlisted spelling is untouched', () {
      expect(decodeAllPaths('a,NIL,b', cfg), [
        ['a', 'NIL', 'b'],
      ]);
    });

    test('numbers and bools are unaffected', () {
      expect(decodeAllPaths('1,2.5,true,false,NULL', cfg), [
        [1, 2.5, true, false, null],
      ]);
    });

    test('a numeric entry in nullValues has no effect, as documented', () {
      // 0 reads as a number before the check, so listing it does nothing.
      // Documented rather than silently inconsistent between the paths.
      const numeric = CsvConfig(autoDetect: false, nullValues: {'0'});
      expect(decodeAllPaths('0,1,NULL', numeric), [
        [0, 1, 'NULL'],
      ]);
    });

    test('an empty field still reads as null, as it always did', () {
      expect(decodeAllPaths('a,,b', cfg), [
        ['a', null, 'b'],
      ]);
    });

    test('works across rows and CRLF', () {
      expect(decodeAllPaths('a,NULL\r\nNA,b\r\n', cfg), [
        ['a', null],
        [null, 'b'],
      ]);
    });

    test('a value split across a chunk boundary still matches', () {
      // decodeAllPaths splits at every offset, so N|ULL is covered here.
      expect(decodeAllPaths('x,NULL,y', cfg), [
        ['x', null, 'y'],
      ]);
    });

    test('combines with skipInitialSpace', () {
      const padded = CsvConfig(
        autoDetect: false,
        skipInitialSpace: true,
        nullValues: {'NULL'},
      );
      expect(decodeAllPaths('a, NULL, b', padded), [
        ['a', null, 'b'],
      ]);
    });

    test('a header keyed decode gives a null value, not the text', () {
      final rows = CsvCodec(cfg).decodeToMaps('name,note\nbolt,NULL\n');
      expect(rows, [
        {'name': 'bolt', 'note': null},
      ]);
    });

    test('decodeStrings is unaffected, since it cannot hold null', () {
      // The return type is List<List<String>>, so nullValues does not apply
      // there by construction rather than by a rule someone has to remember.
      expect(CsvCodec(cfg).decodeStrings('a,NULL,b'), [
        ['a', 'NULL', 'b'],
      ]);
    });

    test('copyWith carries the set', () {
      expect(const CsvConfig().copyWith(nullValues: {'NA'}).nullValues, {'NA'});
      expect(const CsvConfig(nullValues: {'NA'}).copyWith().nullValues, {'NA'});
    });
  });
}
