import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Decodes [input] through every typed path and asserts they agree.
///
/// Trimming happens in two different decoders, so every case is checked
/// against both, with the stream split at every possible offset.
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
  const trim = CsvConfig(autoDetect: false, trimFields: true);
  const plain = CsvConfig(autoDetect: false);

  group('Trim Fields', () {
    test('off by default, the padding is kept', () {
      expect(decodeAllPaths('a , b ', plain), [
        ['a ', ' b '],
      ]);
    });

    test('padding comes off both ends', () {
      expect(decodeAllPaths('a , b ', trim), [
        ['a', 'b'],
      ]);
    });

    test('a padded number still reads as a number', () {
      expect(decodeAllPaths(' 42 , 1.5 ', trim), [
        [42, 1.5],
      ]);
    });

    test('a padded boolean still reads as a boolean', () {
      expect(decodeAllPaths(' true , false ', trim), [
        [true, false],
      ]);
    });

    test('a quoted field is left exactly as written', () {
      // The quotes already say where the value begins and ends.
      expect(decodeAllPaths('" a ",b', trim), [
        [' a ', 'b'],
      ]);
    });

    test('a field of only spaces reads like an empty one', () {
      // Trimmed to nothing, so it lands where a genuinely empty field does.
      expect(decodeAllPaths('a,   ,b', trim), decodeAllPaths('a,,b', plain));
      expect(decodeAllPaths('a,   ,b', trim), [
        ['a', null, 'b'],
      ]);
    });

    test('tabs and other whitespace go too', () {
      expect(decodeAllPaths('a,\tb\t,c', trim), [
        ['a', 'b', 'c'],
      ]);
    });

    test('headers are trimmed as well', () {
      const cfg = CsvConfig(
        autoDetect: false,
        trimFields: true,
        hasHeader: true,
      );
      final out = const FastDecoder().decodeWithHeaders(
        ' name , age \nAlice, 30 ',
        cfg,
      );
      expect(out.headers, ['name', 'age']);
      expect(out.rows, [
        ['Alice', 30],
      ]);
    });

    test('it combines with nullValues on the trimmed text', () {
      const cfg = CsvConfig(
        autoDetect: false,
        trimFields: true,
        nullValues: {'NULL'},
      );
      expect(decodeAllPaths('a, NULL ,b', cfg), [
        ['a', null, 'b'],
      ]);
    });

    test('it combines with date parsing on the trimmed text', () {
      const cfg = CsvConfig(
        autoDetect: false,
        trimFields: true,
        parseDates: true,
      );
      expect(decodeAllPaths('when\n 2024-01-31 ', cfg), [
        ['when'],
        [DateTime(2024, 1, 31)],
      ]);
    });

    test('a row of padded values decodes whole', () {
      expect(decodeAllPaths(' a , 1 , true , 2.5 ', trim), [
        ['a', 1, true, 2.5],
      ]);
    });

    test('it leaves an already tidy document alone', () {
      const text = 'name,age\nAlice,30\nBob,25';
      expect(decodeAllPaths(text, trim), decodeAllPaths(text, plain));
    });

    test('copyWith carries it', () {
      expect(const CsvConfig().copyWith(trimFields: true).trimFields, isTrue);
      expect(const CsvConfig().trimFields, isFalse);
    });
  });
}
