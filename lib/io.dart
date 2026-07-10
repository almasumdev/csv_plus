/// File I/O for CSV data (`dart:io`).
///
/// [CsvFile] provides static convenience methods for reading, writing,
/// streaming, and appending CSV files:
///
/// ```dart
/// import 'package:csv_plus/io.dart';
///
/// final table = await CsvFile.read('data.csv');
/// await CsvFile.write('output.csv', table);
/// await CsvFile.append('output.csv', [['Charlie', 35]]);
/// ```
///
/// All methods accept an optional [CsvConfig] parameter.
/// Sync variants ([CsvFile.readSync], [CsvFile.writeSync]) are available.
///
/// **Platform note**: This library imports `dart:io` and is only available
/// on VM and AOT targets. It is NOT exported from the main `csv_plus.dart`
/// barrel; import it separately.
library;

export 'src/io/csv_file.dart';
