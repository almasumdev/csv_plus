import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Decodes [input] through every typed path and asserts they agree.
///
/// A value reads as a boolean in two different decoders, so every case is
/// checked against both, with the stream split at every possible offset.
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
  const plain = CsvConfig(autoDetect: false);
  const excel = CsvConfig(
    autoDetect: false,
    boolValues: {'TRUE': true, 'FALSE': false},
  );
  const words = CsvConfig(
    autoDetect: false,
    boolValues: {'Yes': true, 'No': false, 'y': true, 'n': false},
  );

  group('Bool Values', () {
    test('without it, only lowercase true and false are booleans', () {
      expect(decodeAllPaths('true,false,TRUE,Yes', plain), [
        [true, false, 'TRUE', 'Yes'],
      ]);
    });

    test('the spellings Excel writes read as booleans', () {
      expect(decodeAllPaths('TRUE,FALSE', excel), [
        [true, false],
      ]);
    });

    test('lowercase true and false keep working alongside it', () {
      expect(decodeAllPaths('TRUE,true,FALSE,false', excel), [
        [true, true, false, false],
      ]);
    });

    test('any spelling listed is accepted', () {
      expect(decodeAllPaths('Yes,No,y,n', words), [
        [true, false, true, false],
      ]);
    });

    test('matching is exact, so an unlisted case stays text', () {
      expect(decodeAllPaths('Yes,YES,yes', words), [
        [true, 'YES', 'yes'],
      ]);
    });

    test('a quoted value is text, as quoting always means', () {
      expect(decodeAllPaths('"TRUE",TRUE', excel), [
        ['TRUE', true],
      ]);
    });

    test('a numeric entry has no effect, since it never reads as text', () {
      // 1 has already read as the number 1 by the time the map is consulted,
      // which is the same rule nullValues follows.
      const numeric = CsvConfig(
        autoDetect: false,
        boolValues: {'1': true, '0': false},
      );
      expect(decodeAllPaths('1,0', numeric), [
        [1, 0],
      ]);
    });

    test('nullValues wins over a value listed in both', () {
      const both = CsvConfig(
        autoDetect: false,
        nullValues: {'NA'},
        boolValues: {'NA': false},
      );
      expect(decodeAllPaths('NA,x', both), [
        [null, 'x'],
      ]);
    });

    test('it runs on a trimmed field too', () {
      const trimmed = CsvConfig(
        autoDetect: false,
        trimFields: true,
        boolValues: {'TRUE': true},
      );
      expect(decodeAllPaths(' TRUE , TRUE', trimmed), [
        [true, true],
      ]);
    });

    test('a header is left as text', () {
      final rows = const CsvCodec(
        CsvConfig(
          autoDetect: false,
          hasHeader: true,
          boolValues: {'TRUE': true, 'FALSE': false},
        ),
      ).decodeWithHeaders('flag,TRUE\nTRUE,FALSE');
      expect(rows.single['flag'], true);
      expect(rows.single['TRUE'], false, reason: 'the header stayed a key');
    });

    test('nothing types when dynamicTyping is off', () {
      const off = CsvConfig(
        autoDetect: false,
        dynamicTyping: false,
        boolValues: {'TRUE': true},
      );
      expect(decodeAllPaths('TRUE,true', off), [
        ['TRUE', 'true'],
      ]);
    });

    test('a row of them round-trips back to the same text', () {
      const config = CsvConfig(
        autoDetect: false,
        boolValues: {'TRUE': true, 'FALSE': false},
      );
      final decoded = decodeAllPaths('TRUE,FALSE', config);
      // Dart writes a bool lowercase, so the shape survives but not the case.
      expect(const CsvCodec(config).encode(decoded).trim(), 'true,false');
    });

    test('copyWith carries it', () {
      const base = CsvConfig(autoDetect: false);
      final with_ = base.copyWith(boolValues: {'TRUE': true});
      expect(with_.boolValues, {'TRUE': true});
      expect(base.boolValues, isEmpty, reason: 'the original changed');
      expect(const CsvCodec(CsvConfig(autoDetect: false)).decode('TRUE'), [
        ['TRUE'],
      ]);
      expect(CsvCodec(with_).decode('TRUE'), [
        [true],
      ]);
    });

    test('inferType takes the map directly', () {
      expect(
        FastDecoder.inferType('TRUE', boolValues: const {'TRUE': true}),
        true,
      );
      expect(FastDecoder.inferType('TRUE'), 'TRUE');
    });
  });
}
