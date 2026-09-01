import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Runs [input] through every decode path under [config] and asserts they all
/// return the same rows, then returns that agreed result.
///
/// The one-parsing-semantics invariant is the whole reason this option was held
/// back once already, so every case here checks it rather than trusting it.
List<List<dynamic>> decodeAllPaths(String input, CsvConfig config) {
  final codec = CsvCodec(config);
  final batch = codec.decode(input);
  final streamed = CsvDecoder(config).convert(input);

  expect(streamed, batch, reason: 'streaming disagreed with batch');

  // And split at every offset, so a space run crossing a chunk boundary is
  // exercised rather than assumed.
  for (var at = 1; at < input.length; at++) {
    final decoder = CsvDecoder(config);
    final rows = <List<dynamic>>[];
    final sink = decoder.startChunkedConversion(
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
  group('Skip Initial Space', () {
    const on = CsvConfig(skipInitialSpace: true, autoDetect: false);
    const off = CsvConfig(autoDetect: false);

    test('is off by default, so a leading space stays content', () {
      expect(decodeAllPaths('a, b,c', off), [
        ['a', ' b', 'c'],
      ]);
    });

    test('drops the space between a delimiter and a plain field', () {
      expect(decodeAllPaths('a, b,c', on), [
        ['a', 'b', 'c'],
      ]);
    });

    test('lets a padded quoted field parse as one field', () {
      // The case the option exists for: without it this is three fields.
      expect(decodeAllPaths('a, "b, c"', off), [
        ['a', ' "b', ' c"'],
      ]);
      expect(decodeAllPaths('a, "b, c"', on), [
        ['a', 'b, c'],
      ]);
    });

    test('a space inside a quoted field is always content', () {
      expect(decodeAllPaths('a,"  b  ",c', on), [
        ['a', '  b  ', 'c'],
      ]);
    });

    test('a space after the first character is content', () {
      expect(decodeAllPaths('a,b c,d', on), [
        ['a', 'b c', 'd'],
      ]);
    });

    test('trailing spaces are untouched', () {
      expect(decodeAllPaths('a,b ,c', on), [
        ['a', 'b ', 'c'],
      ]);
    });

    test('a field of only spaces collapses to an empty field', () {
      // An emptied field then reads as null under type inference, which is
      // exactly what a genuinely empty `a,,c` field does.
      expect(decodeAllPaths('a,   ,c', on), [
        ['a', null, 'c'],
      ]);
      expect(decodeAllPaths('a,,c', on), [
        ['a', null, 'c'],
      ]);
      // With inference off it is an empty string, again matching `a,,c`.
      const strings = CsvConfig(
        skipInitialSpace: true,
        autoDetect: false,
        dynamicTyping: false,
      );
      expect(decodeAllPaths('a,   ,c', strings), [
        ['a', '', 'c'],
      ]);
    });

    test('the first field of a row is skipped too', () {
      expect(decodeAllPaths('  a,b', on), [
        ['a', 'b'],
      ]);
    });

    test('typing still applies after the space is dropped', () {
      expect(decodeAllPaths('a, 42, 3.5, true', on), [
        ['a', 42, 3.5, true],
      ]);
    });

    test('works across rows and CRLF', () {
      expect(decodeAllPaths('a, b\r\nc, d\r\n', on), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('a comment marker reached only after spaces is content', () {
      // The batch path checks for a comment before the cell loop that does the
      // skipping, so an indented marker is not a comment. Streaming must agree.
      const cfg = CsvConfig(
        skipInitialSpace: true,
        autoDetect: false,
        comment: '#',
      );
      expect(decodeAllPaths('a,b\n  #x,y\n', cfg), [
        ['a', 'b'],
        ['#x', 'y'],
      ]);
      // A marker genuinely at the start of the line still drops the line.
      expect(decodeAllPaths('a,b\n#x,y\n', cfg), [
        ['a', 'b'],
      ]);
    });

    test('a space run split across a chunk boundary still collapses', () {
      // decodeAllPaths splits at every offset, so this is the explicit case.
      expect(decodeAllPaths('a,     b,c', on), [
        ['a', 'b', 'c'],
      ]);
    });

    test('copyWith carries the flag', () {
      expect(
        const CsvConfig().copyWith(skipInitialSpace: true).skipInitialSpace,
        isTrue,
      );
      expect(
        const CsvConfig(skipInitialSpace: true).copyWith().skipInitialSpace,
        isTrue,
      );
    });
  });
}
