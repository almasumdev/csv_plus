import 'package:csv_plus/csv_plus.dart';

/// Benchmark for CSV decoding performance.
void main() {
  const rows = 10000;
  const cols = 20;

  // Generate test data
  final buf = StringBuffer();
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (c > 0) buf.write(',');
      switch (c % 4) {
        case 0:
          buf.write('"field_${r}_$c"');
        case 1:
          buf.write(r * cols + c);
        case 2:
          buf.write((r * cols + c) * 0.1);
        case 3:
          buf.write(r % 2 == 0 ? 'true' : 'false');
      }
    }
    buf.write('\r\n');
  }
  final csv = buf.toString();
  final codec = CsvCodec();

  print('CSV size: ${(csv.length / 1024).toStringAsFixed(1)} KB');
  print('Rows: $rows, Cols: $cols');
  print('');

  // Warm up
  codec.decode(csv);
  codec.decodeStrings(csv);

  // Benchmark decode (with type inference)
  final sw1 = Stopwatch()..start();
  const iterations = 50;
  for (var i = 0; i < iterations; i++) {
    codec.decode(csv);
  }
  sw1.stop();
  print('decode (typed):   ${sw1.elapsedMilliseconds}ms '
      '(${(sw1.elapsedMilliseconds / iterations).toStringAsFixed(1)}ms/iter)');

  // Benchmark decodeStrings (no type inference)
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    codec.decodeStrings(csv);
  }
  sw2.stop();
  print('decodeStrings:    ${sw2.elapsedMilliseconds}ms '
      '(${(sw2.elapsedMilliseconds / iterations).toStringAsFixed(1)}ms/iter)');

  // Benchmark decodeFlexible (lenient mode)
  final sw3 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    codec.decodeFlexible(csv);
  }
  sw3.stop();
  print('decodeFlexible:   ${sw3.elapsedMilliseconds}ms '
      '(${(sw3.elapsedMilliseconds / iterations).toStringAsFixed(1)}ms/iter)');

  print('');
  print('Throughput:');
  final mbSize = csv.length / (1024 * 1024);
  print(
      '  decode:        ${(mbSize * iterations / (sw1.elapsedMilliseconds / 1000)).toStringAsFixed(1)} MB/s');
  print(
      '  decodeStrings: ${(mbSize * iterations / (sw2.elapsedMilliseconds / 1000)).toStringAsFixed(1)} MB/s');
  print(
      '  decodeFlexible:${(mbSize * iterations / (sw3.elapsedMilliseconds / 1000)).toStringAsFixed(1)} MB/s');
}
