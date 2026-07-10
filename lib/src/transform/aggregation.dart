import '../core/csv_exception.dart';
import '../table/csv_table.dart';

/// Aggregation operations on [CsvTable].
extension CsvTableAggregation on CsvTable {
  /// Count of non-null values in a column.
  int count(String column) {
    return this.column(column).where((v) => v != null).length;
  }

  /// Sum of numeric values in a column.
  num sum(String column) {
    num total = 0;
    for (final v in this.column(column)) {
      if (v is num) total += v;
    }
    return total;
  }

  /// Average of numeric values in a column.
  double avg(String column) {
    num total = 0;
    var cnt = 0;
    for (final v in this.column(column)) {
      if (v is num) {
        total += v;
        cnt++;
      }
    }
    return cnt > 0 ? total / cnt : 0;
  }

  /// Minimum value in a column.
  dynamic min(String column) {
    dynamic result;
    for (final v in this.column(column)) {
      if (v == null) continue;
      if (result == null || CsvTable.compareValues(v, result, true) < 0) {
        result = v;
      }
    }
    return result;
  }

  /// Maximum value in a column.
  dynamic max(String column) {
    dynamic result;
    for (final v in this.column(column)) {
      if (v == null) continue;
      if (result == null || CsvTable.compareValues(v, result, true) > 0) {
        result = v;
      }
    }
    return result;
  }

  /// Group rows by a column's value. Returns `Map<value, CsvTable>`.
  Map<dynamic, CsvTable> groupBy(String column) {
    final idx = headers.indexOf(column);
    if (idx < 0) throw CsvException('Column "$column" not found');

    final groups = <dynamic, List<List<dynamic>>>{};
    for (final row in rawData) {
      final key = idx < row.length ? row[idx] : null;
      (groups[key] ??= []).add(List<dynamic>.from(row));
    }

    return groups.map(
      (key, rows) =>
          MapEntry(key, CsvTable.internal(List<String>.from(headers), rows)),
    );
  }
}
