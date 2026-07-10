// Head-to-head CSV benchmark: csv 8.0.0, serial_csv 0.5.2,
// csv_plus (local path). Median of 5 timed runs after 2 warmups.
import 'dart:math';

import 'package:csv/csv.dart' as csv8;
import 'package:csv_plus/csv_plus.dart' as plus;
import 'package:serial_csv/serial_csv.dart';

const rowsPlain = 200000;
const rowsQuoted = 100000;
const cols = 10;

List<List<dynamic>> genTyped(int rows) {
  final rng = Random(42);
  const words = ['alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta'];
  return List.generate(rows, (r) {
    return List<dynamic>.generate(cols, (c) {
      switch (c % 4) {
        case 0:
          return words[rng.nextInt(words.length)];
        case 1:
          return rng.nextInt(1000000);
        case 2:
          return (rng.nextDouble() * 10000 * 100).roundToDouble() / 100;
        default:
          return '${words[rng.nextInt(words.length)]}_${rng.nextInt(999)}';
      }
    });
  });
}

List<List<dynamic>> genQuoted(int rows) {
  final rng = Random(7);
  const messy = [
    'plain value',
    'has,comma',
    'has "quote" inside',
    'multi\nline text',
    'trailing space ',
    'semi;colon',
  ];
  return List.generate(rows, (r) {
    return List<dynamic>.generate(
      cols,
      (c) => '${messy[rng.nextInt(messy.length)]} ${rng.nextInt(999)}',
    );
  });
}

double median(List<double> xs) {
  final s = [...xs]..sort();
  return s[s.length ~/ 2];
}

double bench(String label, int Function() run) {
  for (var i = 0; i < 2; i++) {
    run();
  }
  final times = <double>[];
  var checksum = 0;
  for (var i = 0; i < 5; i++) {
    final sw = Stopwatch()..start();
    checksum = run();
    sw.stop();
    times.add(sw.elapsedMicroseconds / 1000.0);
  }
  final ms = median(times);
  print(
    '${label.padRight(46)} ${ms.toStringAsFixed(1).padLeft(9)} ms   (check=$checksum)',
  );
  return ms;
}

void main() {
  final typedData = genTyped(rowsPlain);
  final quotedData = genQuoted(rowsQuoted);

  // Reference encodings produced by csv_plus (RFC output), decoded by all.
  final plusCodec = plus.CsvCodec(
    plus.CsvConfig(autoDetect: false, skipEmptyLines: false),
  );
  final plainCsv = plusCodec.encode(typedData);
  final quotedCsv = plusCodec.encode(quotedData);
  final serialPlain = SerialCsv.encode(typedData);

  final csv8Str = csv8.Csv(autoDetect: false, skipEmptyLines: false);
  final csv8Typed = csv8.Csv(
    autoDetect: false,
    skipEmptyLines: false,
    dynamicTyping: true,
  );
  final csv8Auto = csv8.Csv(skipEmptyLines: false);
  final plusAuto = plus.CsvCodec(plus.CsvConfig(skipEmptyLines: false));

  print(
    'plain: $rowsPlain rows x $cols cols '
    '(${(plainCsv.length / 1024 / 1024).toStringAsFixed(1)} MB), '
    'quoted: $rowsQuoted rows x $cols cols '
    '(${(quotedCsv.length / 1024 / 1024).toStringAsFixed(1)} MB)\n',
  );

  print('--- DECODE plain, all-strings mode ---');
  bench('csv 8.0.0 (dynamicTyping:false)', () {
    return csv8Str.decode(plainCsv).length;
  });
  bench('csv_plus decodeStrings()', () {
    return plusCodec.decodeStrings(plainCsv).length;
  });
  bench('serial_csv decodeStrings (own format)', () {
    return SerialCsv.decodeStrings(SerialCsv.encodeStrings([
      for (final r in typedData) [for (final v in r) v.toString()],
    ])).length;
  });

  print('\n--- DECODE plain, typed mode ---');
  bench('csv 8.0.0 (dynamicTyping:true)', () {
    return csv8Typed.decode(plainCsv).length;
  });
  bench('csv_plus decode() typed', () {
    return plusCodec.decode(plainCsv).length;
  });
  bench('serial_csv decode (own format, typed)', () {
    return SerialCsv.decode(serialPlain).length;
  });

  print('\n--- DECODE plain, auto-detect on (default config) ---');
  bench('csv 8.0.0 autoDetect:true', () => csv8Auto.decode(plainCsv).length);
  bench('csv_plus autoDetect:true', () => plusAuto.decode(plainCsv).length);

  print('\n--- DECODE quote-heavy, all-strings mode ---');
  bench('csv 8.0.0', () => csv8Str.decode(quotedCsv).length);
  bench('csv_plus decodeStrings()', () {
    return plusCodec.decodeStrings(quotedCsv).length;
  });

  print('\n--- ENCODE plain (typed rows) ---');
  bench('csv 8.0.0 encode', () => csv8Str.encode(typedData).length);
  bench('csv_plus encode', () => plusCodec.encode(typedData).length);
  bench('serial_csv encode', () => SerialCsv.encode(typedData).length);

  print('\n--- ENCODE quote-heavy ---');
  bench('csv 8.0.0 encode', () => csv8Str.encode(quotedData).length);
  bench('csv_plus encode', () => plusCodec.encode(quotedData).length);

  print('\n--- decodeWithHeaders (plain) ---');
  bench('csv 8.0.0 decodeWithHeaders', () {
    return csv8Str.decodeWithHeaders(plainCsv).length;
  });
  bench('csv_plus decodeWithHeaders', () {
    return plusCodec.decodeWithHeaders(plainCsv).length;
  });
}
