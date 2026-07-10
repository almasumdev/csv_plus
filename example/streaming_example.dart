import 'package:csv_plus/csv_plus.dart';

/// Streaming CSV processing examples.
void main() async {
  // --- Stream encoding ---
  print('=== Stream Encoding ===');
  final encoder = CsvEncoder(const CsvConfig());
  final rowStream = Stream.fromIterable([
    ['name', 'value'],
    ['Alice', 100],
    ['Bob', 200],
  ]);
  await for (final chunk in encoder.bind(rowStream)) {
    print('Chunk: ${chunk.replaceAll('\r\n', '\\r\\n')}');
  }
  print('');

  // --- Stream decoding ---
  print('=== Stream Decoding ===');
  final decoder = CsvDecoder(const CsvConfig());
  final csvStream = Stream.fromIterable(['name,age\n', 'Alice,30\n', 'Bob,25']);
  await for (final row in decoder.bind(csvStream)) {
    print('Row: $row');
  }
  print('');

  // --- Chunked conversion sinks ---
  print('=== Chunked Conversion ===');
  final decoderSink = decoder.startChunkedConversion(
    _PrintSink((row) => print('  Decoded: $row')),
  );
  decoderSink.add('a,b\n1,2\n');
  decoderSink.add('3,4');
  decoderSink.close();
}

class _PrintSink implements Sink<List<dynamic>> {
  final void Function(List<dynamic>) _onAdd;
  _PrintSink(this._onAdd);

  @override
  void add(List<dynamic> data) => _onAdd(data);

  @override
  void close() {}
}
