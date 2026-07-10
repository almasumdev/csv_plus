import '../core/csv_exception.dart';
import '../table/csv_row.dart';
import '../table/csv_table.dart';

/// Filtering and querying operations on [CsvTable].
extension CsvTableFiltering on CsvTable {
  /// Filter rows matching predicate. Returns new [CsvTable].
  CsvTable where(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    final filtered = rawData.where((r) => test(CsvRow(r, headerMap))).toList();
    return CsvTable.internal(
      List<String>.from(headers),
      filtered.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  /// Find first row matching predicate (or null).
  CsvRow? firstWhere(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    for (final r in rawData) {
      final row = CsvRow(r, headerMap);
      if (test(row)) return row;
    }
    return null;
  }

  /// Check if any row matches predicate.
  bool any(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    return rawData.any((r) => test(CsvRow(r, headerMap)));
  }

  /// Check if all rows match predicate.
  bool every(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    return rawData.every((r) => test(CsvRow(r, headerMap)));
  }

  /// Get rows in index range. Returns new [CsvTable].
  CsvTable range(int start, [int? end]) {
    final slice = rawData.sublist(start, end);
    return CsvTable.internal(
      List<String>.from(headers),
      slice.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  /// Get first N rows.
  CsvTable take(int count) => range(0, count.clamp(0, rawData.length));

  /// Skip first N rows.
  CsvTable skip(int count) => range(count.clamp(0, rawData.length));

  /// Get distinct rows based on all fields or specific columns.
  ///
  /// Keys are type-aware: the int `1` and the string `"1"` are distinct
  /// values, and string content cannot forge a key collision.
  CsvTable distinct({List<String>? columns}) {
    final seen = <String>{};
    final result = <List<dynamic>>[];

    List<int>? colIndices;
    if (columns != null) {
      colIndices = columns.map((c) {
        final idx = headers.indexOf(c);
        if (idx < 0) throw CsvException('Column "$c" not found');
        return idx;
      }).toList();
    }

    for (final row in rawData) {
      final values = colIndices != null
          ? colIndices.map((i) => i < row.length ? row[i] : null)
          : row;
      if (seen.add(_distinctKey(values))) {
        result.add(List<dynamic>.from(row));
      }
    }

    return CsvTable.internal(List<String>.from(headers), result);
  }

  /// Build a collision-proof key: each cell is tagged with its type and
  /// length-prefixed, so `1`, `1.0`, `"1"`, and embedded separators all
  /// produce different keys.
  static String _distinctKey(Iterable<dynamic> values) {
    final buf = StringBuffer();
    for (final v in values) {
      if (v == null) {
        buf.write('n;');
      } else if (v is bool) {
        buf.write(v ? 'b1;' : 'b0;');
      } else if (v is int) {
        buf
          ..write('i')
          ..write(v)
          ..write(';');
      } else if (v is double) {
        buf
          ..write('d')
          ..write(v)
          ..write(';');
      } else {
        final s = v.toString();
        buf
          ..write(v is String ? 's' : 'o')
          ..write(s.length)
          ..write(':')
          ..write(s);
      }
    }
    return buf.toString();
  }
}
