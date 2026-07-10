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

      test('partial delimiter across boundary that mismatches is content',
          () async {
        final d = CsvDecoder(const CsvConfig(fieldDelimiter: '::'));
        final stream = Stream.fromIterable(['a:', 'b::c']);
        final rows = await d.bind(stream).toList();
        expect(rows, [
          ['a:b', 'c'],
        ]);
      });
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
        expect(upstreamPaused, isTrue,
            reason: 'backpressure must reach the source');

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
        decoder.bind(source.stream).listen(
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
                Stream.fromIterable([bytes.sublist(0, 7), bytes.sublist(7)]))
            .toList();
        expect(rows, [
          ['name', 'age'],
          ['Alice', 30],
        ]);
      });
    });
  });
}
