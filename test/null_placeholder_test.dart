import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Encodes [rows] through both encoders and asserts they produce the same text.
String encodeBothPaths(List<List<dynamic>> rows, CsvConfig config) {
  final batch = CsvCodec(config).encode(rows);
  final streamed = CsvEncoder(config).convert(rows);
  expect(streamed, batch, reason: 'streaming encoder disagreed with batch');
  return batch;
}

void main() {
  group('Null Placeholder', () {
    const cfg = CsvConfig(nullPlaceholder: 'NULL', lineDelimiter: '\n');
    const plain = CsvConfig(lineDelimiter: '\n');

    test('a null is written as the placeholder', () {
      expect(
        encodeBothPaths([
          ['a', null, 'b'],
        ], cfg),
        'a,NULL,b',
      );
    });

    test('an empty string is not a null and keeps its own encoding', () {
      // '' encodes as a quoted empty field so it stays distinguishable from a
      // null on the way back. The placeholder must not change that.
      expect(
        encodeBothPaths([
          ['a', '', 'b'],
        ], plain),
        'a,"",b',
      );
      expect(
        encodeBothPaths([
          ['a', '', 'b'],
        ], cfg),
        'a,"",b',
      );
    });

    test('off by default, a null is still an empty field', () {
      expect(
        encodeBothPaths([
          ['a', null, 'b'],
        ], plain),
        'a,,b',
      );
    });

    test('a placeholder needing quotes gets them', () {
      const commaCfg = CsvConfig(
        nullPlaceholder: 'no, value',
        lineDelimiter: '\n',
      );
      expect(
        encodeBothPaths([
          ['a', null],
        ], commaCfg),
        'a,"no, value"',
      );
    });

    test('a Postgres style sentinel works', () {
      const pg = CsvConfig(nullPlaceholder: r'\N', lineDelimiter: '\n');
      expect(
        encodeBothPaths([
          ['a', null],
        ], pg),
        'a,${r'\N'}',
      );
    });

    test('round-trips with nullValues back to a real null', () {
      const both = CsvConfig(
        nullPlaceholder: 'NULL',
        nullValues: {'NULL'},
        autoDetect: false,
        lineDelimiter: '\n',
      );
      final rows = [
        ['a', null, 'b'],
        [null, 'c', null],
      ];
      final text = encodeBothPaths(rows, both);
      expect(CsvCodec(both).decode(text), rows);
    });

    test('a genuine string equal to the placeholder is quoted apart', () {
      // Encoding must not make a real "NULL" indistinguishable from a null.
      const both = CsvConfig(
        nullPlaceholder: 'NULL',
        nullValues: {'NULL'},
        autoDetect: false,
        quoteMode: QuoteMode.strings,
        lineDelimiter: '\n',
      );
      final text = CsvCodec(both).encode([
        ['NULL', null],
      ]);
      final back = CsvCodec(both).decode(text);
      expect(back, [
        ['NULL', null],
      ], reason: 'the quoted text survives, the null stays null');
    });

    test('the chunked sink agrees too', () {
      final out = StringBuffer();
      final sink = CsvEncoder(
        cfg,
      ).startChunkedConversion(StringConversionSink.withCallback(out.write));
      sink.add(['a', null, 'b']);
      sink.close();
      expect(out.toString(), 'a,NULL,b');
    });

    test('encodeField honours it as well', () {
      expect(
        CsvEncoder.encodeField(
          null,
          fieldDelimiter: ',',
          quoteCharacter: '"',
          escapeCharacter: '"',
          quoteMode: QuoteMode.necessary,
          nullPlaceholder: 'NULL',
        ),
        'NULL',
      );
    });

    test('copyWith carries it', () {
      expect(
        const CsvConfig().copyWith(nullPlaceholder: 'NA').nullPlaceholder,
        'NA',
      );
      expect(
        const CsvConfig(nullPlaceholder: 'NA').copyWith().nullPlaceholder,
        'NA',
      );
    });
  });
}
