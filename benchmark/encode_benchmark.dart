import 'package:csv_plus/csv_plus.dart';

/// Benchmark for CSV encoding performance.
void main() {
  const rows = 10000;
  const cols = 20;

  // Generate test data
  final data = List.generate(rows, (r) {
    return List.generate(cols, (c) {
      return switch (c % 4) {
        0 => 'field_${r}_$c',
        1 => r * cols + c,
        2 => (r * cols + c) * 0.1,
        3 => r % 2 == 0,
        _ => null,
      };
    });
  });

  final codec = CsvCodec();

  print('Rows: $rows, Cols: $cols');
  print('');

  // Warm up
  codec.encode(data);

  const iterations = 50;

  // Benchmark encode (with quoting)
  final sw1 = Stopwatch()..start();
  late String lastCsv;
  for (var i = 0; i < iterations; i++) {
    lastCsv = codec.encode(data);
  }
  sw1.stop();
  print('encode:           ${sw1.elapsedMilliseconds}ms '
      '(${(sw1.elapsedMilliseconds / iterations).toStringAsFixed(1)}ms/iter)');

  // Benchmark encodeStrings (all strings, no type check)
  final stringData =
      data.map((r) => r.map((c) => c.toString()).toList()).toList();
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    codec.encodeStrings(stringData);
  }
  sw2.stop();
  print('encodeStrings:    ${sw2.elapsedMilliseconds}ms '
      '(${(sw2.elapsedMilliseconds / iterations).toStringAsFixed(1)}ms/iter)');

  print('');
  final mbSize = lastCsv.length / (1024 * 1024);
  print('Output size: ${(lastCsv.length / 1024).toStringAsFixed(1)} KB');
  print('Throughput:');
  print(
      '  encode:        ${(mbSize * iterations / (sw1.elapsedMilliseconds / 1000)).toStringAsFixed(1)} MB/s');
  print(
      '  encodeStrings: ${(mbSize * iterations / (sw2.elapsedMilliseconds / 1000)).toStringAsFixed(1)} MB/s');
}
