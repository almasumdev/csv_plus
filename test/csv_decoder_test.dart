import 'dart:async';
import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvDecoder (streaming)', () {
    const decoder = CsvDecoder();

    group('convert (batch)', () {
      test('simple CSV', () {
        final rows = decoder.convert('a,b\n1,2');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('empty input', () {
        expect(decoder.convert(''), isEmpty);
      });

      test('single field', () {
        final rows = decoder.convert('hello');
        expect(rows, [
          ['hello'],
        ]);
      });

      test('quoted fields', () {
        final rows = decoder.convert('"a,b",c\n"d""e",f');
        expect(rows, [
          ['a,b', 'c'],
          ['d"e', 'f'],
        ]);
      });

      test('CRLF line endings', () {
        final rows = decoder.convert('a,b\r\n1,2\r\n3,4');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
          [3, 4],
        ]);
      });

      test('dynamic typing', () {
        final rows = decoder.convert('1,2.5,true,false,hello,');
        expect(rows, [
          [1, 2.5, true, false, 'hello', null],
        ]);
      });

      test('with hasHeader config', () {
        final d = CsvDecoder(const CsvConfig(hasHeader: true));
        final rows = d.convert('name,age\nAlice,30');
        expect(rows, [
          ['Alice', 30],
        ]);
      });

      test('BOM stripped', () {
        final rows = decoder.convert('\uFEFFa,b\n1,2');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('skipEmptyLines', () {
        final rows = decoder.convert('a,b\n\n1,2');
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });
    });

    group('bind (stream)', () {
      test('simple stream', () async {
        final stream = Stream.fromIterable(['a,b\n', '1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-field', () async {
        final stream = Stream.fromIterable(['a,hel', 'lo\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'hello'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-CRLF', () async {
        final stream = Stream.fromIterable(['a,b\r', '\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-quoted field', () async {
        final stream = Stream.fromIterable(['"hel', 'lo",b\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['hello', 'b'],
          [1, 2],
        ]);
      });

      test('chunk splitting mid-escape', () async {
        final stream = Stream.fromIterable(['"a"', '"b",c\n1,2']);
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a"b', 'c'],
          [1, 2],
        ]);
      });

      test('single character chunks', () async {
        final input = 'a,b\n1,2';
        final stream = Stream.fromIterable(input.split(''));
        final rows = await decoder.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('empty stream', () async {
        final rows = await decoder.bind(const Stream<String>.empty()).toList();
        expect(rows, isEmpty);
      });

      test('multi-char delimiter in stream', () async {
        final d = CsvDecoder(const CsvConfig(fieldDelimiter: '::'));
        final stream = Stream.fromIterable(['a::b\n', '1::2']);
        final rows = await d.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test('multi-char delimiter split across chunk boundary', () async {
        final d = CsvDecoder(const CsvConfig(fieldDelimiter: '::'));
        final stream = Stream.fromIterable(['a:', ':b\n1:', ':2']);
        final rows = await d.bind(stream).toList();
        expect(rows, [
          ['a', 'b'],
          [1, 2],
        ]);
      });

      test(
        'partial delimiter across boundary that mismatches is content',
        () async {
          final d = CsvDecoder(const CsvConfig(fieldDelimiter: '::'));
          final stream = Stream.fromIterable(['a:', 'b::c']);
          final rows = await d.bind(stream).toList();
          expect(rows, [
            ['a:b', 'c'],
          ]);
        },
      );
    });

    group('stream contract', () {
      test('pausing the listener pauses the upstream source', () async {
        var upstreamPaused = false;
        var upstreamResumed = false;
        final source = StreamController<String>(
          onPause: () => upstreamPaused = true,
          onResume: () => upstreamResumed = true,
        );
        final rows = <List<dynamic>>[];
        final sub = decoder.bind(source.stream).listen(rows.add);

        source.add('a,b\n');
        await pumpEventQueue();
        sub.pause();
        await pumpEventQueue();
        expect(
          upstreamPaused,
          isTrue,
          reason: 'backpressure must reach the source',
        );

        sub.resume();
        await pumpEventQueue();
        expect(upstreamResumed, isTrue);

        await source.close();
        await pumpEventQueue();
        expect(rows, [
          ['a', 'b'],
        ]);
        await sub.cancel();
      });

      test('cancelling the listener cancels the upstream source', () async {
        var upstreamCancelled = false;
        final source = StreamController<String>(
          onCancel: () => upstreamCancelled = true,
        );
        final sub = decoder.bind(source.stream).listen((_) {});
        source.add('a,b\n');
        await pumpEventQueue();
        await sub.cancel();
        await pumpEventQueue();
        expect(upstreamCancelled, isTrue);
      });

      test('an upstream error closes the output stream', () async {
        final source = StreamController<String>();
        final events = <String>[];
        final done = Completer<void>();
        decoder
            .bind(source.stream)
            .listen(
              (row) => events.add('row'),
              onError: (Object e) => events.add('error'),
              onDone: () {
                events.add('done');
                done.complete();
              },
            );
        source.add('a,b\n');
        source.addError(StateError('disk failed'));
        await done.future;
        expect(events, ['row', 'error', 'done']);
      });

      test('bindBytes decodes a UTF-8 byte stream', () async {
        final bytes = utf8.encode('name,age\nAlice,30');
        final rows = await decoder
            .bindBytes(
              Stream.fromIterable([bytes.sublist(0, 7), bytes.sublist(7)]),
            )
            .toList();
        expect(rows, [
          ['name', 'age'],
          ['Alice', 30],
        ]);
      });
    });

    group('Streaming Delimiter Detection', () {
      const codec = CsvCodec();

      Future<List<List<dynamic>>> streamed(
        Iterable<String> chunks, [
        CsvConfig config = const CsvConfig(),
      ]) => CsvDecoder(config).bind(Stream.fromIterable(chunks)).toList();

      // Streams [input] split at every offset, and one code unit at a time,
      // and expects the batch result each time.
      Future<void> expectMatchesBatch(String input) async {
        final expected = codec.decode(input);
        expect(decoder.convert(input), expected);
        for (var i = 0; i <= input.length; i++) {
          final rows = await streamed([
            input.substring(0, i),
            input.substring(i),
          ]);
          expect(rows, expected, reason: 'split at $i of ${jsonEncode(input)}');
        }
        final single = await streamed(input.split(''));
        expect(single, expected, reason: 'one code unit per chunk');
      }

      test('detects a semicolon delimiter at every chunk split', () async {
        const input = 'name;age\nAnn;30\nBob;25\n';
        expect(codec.decode(input), [
          ['name', 'age'],
          ['Ann', 30],
          ['Bob', 25],
        ]);
        await expectMatchesBatch(input);
      });

      test('drops a sep= hint line and applies its delimiter', () async {
        for (final input in [
          'sep=;\nname;age\nAnn;30\n',
          'sep=;\r\nname;age\r\nAnn;30\r\n',
          'sep=;\rname;age\rAnn;30\r',
          '﻿sep=|\nname|age\nAnn|30',
        ]) {
          expect(
            codec.decode(input).first.length,
            2,
            reason: jsonEncode(input),
          );
          await expectMatchesBatch(input);
        }
      });

      test('detects a tab delimiter after a byte order mark', () async {
        const input = '﻿name\tage\nAnn\t30\n';
        expect(codec.decode(input), [
          ['name', 'age'],
          ['Ann', 30],
        ]);
        await expectMatchesBatch(input);
      });

      test('samples the same lines as the batch decoder', () async {
        // The first ten lines favour ';'. Later lines are all ',' and must not
        // change the decision.
        final input = [
          for (var i = 0; i < 10; i++) 'a$i;b$i',
          for (var i = 0; i < 10; i++) 'c,$i,d,$i',
        ].join('\n');
        expect(codec.decode(input).first, ['a0', 'b0']);
        await expectMatchesBatch(input);

        // A quoted newline does not end a sampled line.
        final quoted = [
          '"a\nb";c',
          for (var i = 0; i < 12; i++) 'x$i;y$i',
        ].join('\n');
        await expectMatchesBatch(quoted);
      });

      test('leaves an explicit delimiter untouched', () async {
        const input = 'name;age\nAnn;30\n';
        const noDetect = CsvConfig(autoDetect: false);
        const pipe = CsvConfig(fieldDelimiter: '|');
        for (final config in [noDetect, pipe]) {
          final expected = CsvCodec(config).decode(input);
          expect(expected, [
            ['name;age'],
            ['Ann;30'],
          ]);
          expect(CsvDecoder(config).convert(input), expected);
          expect(await streamed(input.split(''), config), expected);
        }
      });

      test('an empty stream gives no rows', () async {
        expect(await streamed(const []), isEmpty);
        expect(await streamed(['']), isEmpty);
        expect(decoder.convert(''), isEmpty);
      });

      test('decides on what it has when the sample never completes', () async {
        // A stray opening quote keeps the first line open for good.
        final big = 'a;"b\n${'x;y\n' * 300000}';
        final expected = codec.decode(big);
        expect(await streamed([big]), expected);
        final chunks = [
          for (var i = 0; i < big.length; i += 50000)
            big.substring(i, i + 50000 > big.length ? big.length : i + 50000),
        ];
        expect(await streamed(chunks), expected);
      });
    });
  });
}
