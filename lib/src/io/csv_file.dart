import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../codec/csv_codec.dart';
import '../core/csv_config.dart';
import '../decoder/csv_decoder.dart';
import '../encoder/csv_encoder.dart';
import '../table/csv_table.dart';

/// Convenience class for CSV file operations.
///
/// Uses `dart:io` for file access. Isolated here to keep core library
/// platform-independent.
class CsvFile {
  // --- Read ---

  /// Read entire file into [CsvTable] (async).
  static Future<CsvTable> read(
    String path, {
    CsvConfig config = const CsvConfig(),
  }) async {
    final content = await File(path).readAsString();
    return CsvTable.parse(content, config: config);
  }

  /// Read entire file into [CsvTable] (sync).
  static CsvTable readSync(
    String path, {
    CsvConfig config = const CsvConfig(),
  }) {
    final content = File(path).readAsStringSync();
    return CsvTable.parse(content, config: config);
  }

  /// Stream rows from file. Memory-efficient for large files.
  static Stream<List<dynamic>> stream(
    String path, {
    CsvConfig config = const CsvConfig(),
  }) {
    return File(
      path,
    ).openRead().transform(utf8.decoder).transform(CsvDecoder(config));
  }

  // --- Write ---

  /// Write [CsvTable] to file (async).
  static Future<void> write(
    String path,
    CsvTable table, {
    CsvConfig config = const CsvConfig(),
  }) async {
    final csv = table.toCsv(config: config);
    await File(path).writeAsString(csv);
  }

  /// Write [CsvTable] to file (sync).
  static void writeSync(
    String path,
    CsvTable table, {
    CsvConfig config = const CsvConfig(),
  }) {
    final csv = table.toCsv(config: config);
    File(path).writeAsStringSync(csv);
  }

  /// Write raw rows to file (async).
  static Future<void> writeRows(
    String path,
    List<List<dynamic>> rows, {
    CsvConfig config = const CsvConfig(),
  }) async {
    final csv = CsvCodec(config).encode(rows);
    await File(path).writeAsString(csv);
  }

  /// Stream rows to file. Memory-efficient for large outputs.
  static Future<void> writeStream(
    String path,
    Stream<List<dynamic>> rows, {
    CsvConfig config = const CsvConfig(),
  }) async {
    final file = File(path).openWrite();
    final encoder = CsvEncoder(config);
    try {
      await for (final chunk in encoder.bind(rows)) {
        file.write(chunk);
      }
    } finally {
      await file.close();
    }
  }

  /// Append rows to existing file (async).
  static Future<void> append(
    String path,
    List<List<dynamic>> rows, {
    CsvConfig config = const CsvConfig(),
  }) async {
    final csv = CsvCodec(config).encode(rows);
    final file = File(path);
    final prefix = await file.exists() && await file.length() > 0
        ? config.lineDelimiter
        : '';
    await file.writeAsString('$prefix$csv', mode: FileMode.append);
  }
}
