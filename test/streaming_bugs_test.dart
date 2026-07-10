import 'dart:async';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('BUG 5: Streaming escape at chunk boundary (escape != quote)', () {
    final config = CsvConfig(
      escapeCharacter: r'\',
      quoteCharacter: '"',
    );
    final decoder = CsvDecoder(config);

    test('escape split across two chunks', () async {
      // Input: "hello\"world",next reads field = hello"world
      // Chunk 1 ends with \, chunk 2 starts with "
      final stream = Stream.fromIterable(['"hello\\', '"world",next']);
      final rows = await decoder.bind(stream).toList();
      expect(rows, [
        ['hello"world', 'next'],
      ]);
    });

    test('escape at chunk boundary via convert split', () {
      // Test every split position of: "a\"b",c
      const input = '"a\\"b",c';
      final expected = [
        ['a"b', 'c']
      ];

      for (var i = 0; i <= input.length; i++) {
        final chunk1 = input.substring(0, i);
        final chunk2 = input.substring(i);

        final rows = <List<dynamic>>[];
        final machine = _TestStateMachine(config, rows);
        if (chunk1.isNotEmpty) machine.addChunk(chunk1);
        if (chunk2.isNotEmpty) machine.addChunk(chunk2);
        machine.finish();

        expect(rows, expected,
            reason: 'Failed at split $i: "$chunk1" + "$chunk2"');
      }
    });

    test('escape NOT at chunk boundary works normally', () {
      final rows = decoder.convert('"hello\\"world",next');
      expect(rows, [
        ['hello"world', 'next'],
      ]);
    });

    test('escape at chunk boundary not followed by quote', () async {
      // \ at end of chunk, next chunk starts with non-quote char
      // The \ should be treated as literal
      final stream = Stream.fromIterable(['"hello\\', 'nworld"']);
      final rows = await decoder.bind(stream).toList();
      expect(rows, [
        ['hello\\nworld'],
      ]);
    });

    test('default escape==quote still works at chunk boundary', () async {
      // RFC 4180: "" is escaped quote; split across chunks
      const defaultDecoder = CsvDecoder();
      final stream = Stream.fromIterable(['"a"', '"b",c']);
      final rows = await defaultDecoder.bind(stream).toList();
      expect(rows, [
        ['a"b', 'c'],
      ]);
    });
  });

  group('BUG 6: Streaming empty field with dynamicTyping:false', () {
    final config = CsvConfig(dynamicTyping: false);
    final decoder = CsvDecoder(config);

    test('empty field between delimiters returns empty string', () {
      final rows = decoder.convert('a,,b');
      expect(rows, [
        ['a', '', 'b'],
      ]);
    });

    test('trailing empty field returns empty string', () {
      final rows = decoder.convert('a,b,');
      expect(rows, [
        ['a', 'b', ''],
      ]);
    });

    test('leading empty field returns empty string', () {
      final rows = decoder.convert(',a,b');
      expect(rows, [
        ['', 'a', 'b'],
      ]);
    });

    test('all empty fields return empty strings', () {
      final rows = decoder.convert(',,');
      expect(rows, [
        ['', '', ''],
      ]);
    });

    test('empty field in stream returns empty string', () async {
      final stream = Stream.fromIterable(['a,,b\n', ',,']);
      final rows = await decoder.bind(stream).toList();
      expect(rows, [
        ['a', '', 'b'],
        ['', '', ''],
      ]);
    });

    test('consistent with FastDecoder batch output', () {
      const input = 'a,,b\nx,,y';
      final batchConfig = CsvConfig(dynamicTyping: false);

      // Batch (FastDecoder)
      final codec = CsvCodec(batchConfig);
      final batchRows = codec.decode(input);

      // Streaming (CsvDecoder)
      final streamRows = CsvDecoder(batchConfig).convert(input);

      expect(streamRows, batchRows,
          reason: 'Streaming and batch decoders must return same values');
    });
  });
}

/// Expose _StateMachine for chunk-boundary testing via CsvDecoder.convert
/// split into manual chunks.
class _TestStateMachine {
  final CsvConfig config;
  final List<List<dynamic>> _rows;
  late final CsvDecoder _decoder;

  _TestStateMachine(this.config, this._rows) : _decoder = CsvDecoder(config);

  void addChunk(String chunk) {
    // Use startChunkedConversion for proper state machine testing
    _sink ??= _decoder.startChunkedConversion(_CollectorSink(_rows));
    _sink!.add(chunk);
  }

  Sink<String>? _sink;

  void finish() {
    _sink?.close();
  }
}

class _CollectorSink implements Sink<List<dynamic>> {
  final List<List<dynamic>> _target;
  _CollectorSink(this._target);

  @override
  void add(List<dynamic> data) => _target.add(data);

  @override
  void close() {}
}
