import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvEncoder (streaming)', () {
    const encoder = CsvEncoder();

    group('convert (batch)', () {
      test('simple rows', () {
        final csv = encoder.convert([
          ['a', 'b'],
          [1, 2],
        ]);
        expect(csv, 'a,b\r\n1,2');
      });

      test('empty rows', () {
        expect(encoder.convert([]), '');
      });

      test('with BOM', () {
        final e = CsvEncoder(const CsvConfig(addBom: true));
        final csv = e.convert([
          ['a'],
        ]);
        expect(csv.codeUnitAt(0), 0xFEFF);
        expect(csv.substring(1), 'a');
      });

      test('quoting necessary', () {
        final csv = encoder.convert([
          ['hello, world', 'normal'],
        ]);
        expect(csv, '"hello, world",normal');
      });

      test('null values', () {
        final csv = encoder.convert([
          [null, 'b'],
        ]);
        expect(csv, ',b');
      });

      test('quote mode always', () {
        final e = CsvEncoder(const CsvConfig(quoteMode: QuoteMode.always));
        final csv = e.convert([
          ['a', 1],
        ]);
        expect(csv, '"a","1"');
      });
    });

    group('bind (stream)', () {
      test('streams rows', () async {
        final stream = Stream.fromIterable([
          ['a', 'b'],
          [1, 2],
          [3, 4],
        ]);
        final chunks = await encoder.bind(stream).toList();
        expect(chunks.length, 3);
        expect(chunks[0], 'a,b');
        expect(chunks[1], '\r\n1,2');
        expect(chunks[2], '\r\n3,4');
      });

      test('empty stream', () async {
        final chunks = await encoder
            .bind(const Stream<List<dynamic>>.empty())
            .toList();
        expect(chunks, isEmpty);
      });

      test('bindBytes encodes to a UTF-8 byte stream', () async {
        final byteChunks = await encoder
            .bindBytes(
              Stream.fromIterable([
                ['a', 1],
                ['b', 2],
              ]),
            )
            .toList();
        final text = utf8.decode(byteChunks.expand((c) => c).toList());
        expect(text, 'a,1\r\nb,2');
      });
    });

    group('null handling per quote mode', () {
      test('necessary and strings write null as an empty unquoted field', () {
        expect(
          CsvEncoder(const CsvConfig(quoteMode: QuoteMode.necessary)).convert([
            ['a', null, 'b'],
          ]),
          'a,,b',
        );
        expect(
          CsvEncoder(const CsvConfig(quoteMode: QuoteMode.strings)).convert([
            ['a', null, 'b'],
          ]),
          '"a",,"b"',
        );
      });

      test('always quotes null as an empty quoted field', () {
        const config = CsvConfig(quoteMode: QuoteMode.always);
        expect(
          CsvEncoder(config).convert([
            ['a', null],
          ]),
          '"a",""',
        );
      });

      test('necessary keeps null and empty string distinguishable', () {
        const config = CsvConfig(skipEmptyLines: false);
        final encoded = CsvEncoder(config).convert([
          [null, ''],
        ]);
        expect(encoded, ',""');
        final decoded = CsvDecoder(config).convert(encoded);
        expect(decoded, [
          [null, ''],
        ]);
      });
    });

    group('encodeGeneric', () {
      test('numeric grids encode without quoting', () {
        const config = CsvConfig();
        expect(
          const FastEncoder().encodeGeneric<int>([
            [1, 2],
            [3, 4],
          ], config),
          '1,2\r\n3,4',
        );
      });

      test('strings with delimiters are quoted, not corrupted', () {
        const config = CsvConfig();
        final encoded = const FastEncoder().encodeGeneric<String>([
          ['plain', 'with,comma'],
        ], config);
        expect(encoded, 'plain,"with,comma"');
        expect(const FastDecoder().decodeStrings(encoded, config), [
          ['plain', 'with,comma'],
        ]);
      });
    });
  });
}
