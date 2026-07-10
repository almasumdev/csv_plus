import '../core/csv_exception.dart';
import '../table/csv_row.dart';
import '../table/csv_table.dart';

/// Column and row manipulation operations on [CsvTable].
extension CsvTableManipulation on CsvTable {
  /// Add a new column with optional default value.
  void addColumn(String name, {dynamic defaultValue}) {
    mutableHeaders.add(name);
    for (final row in rawData) {
      row.add(defaultValue);
    }
  }

  /// Insert column at index.
  void insertColumn(int index, String name, {dynamic defaultValue}) {
    mutableHeaders.insert(index, name);
    for (final row in rawData) {
      row.insert(index, defaultValue);
    }
  }

  /// Remove column by name. Returns removed values.
  List<dynamic> removeColumn(String name) {
    final idx = headers.indexOf(name);
    if (idx < 0) throw CsvException('Column "$name" not found');
    return removeColumnAt(idx);
  }

  /// Remove column by index. Returns removed values.
  List<dynamic> removeColumnAt(int index) {
    if (index < mutableHeaders.length) mutableHeaders.removeAt(index);
    final values = <dynamic>[];
    for (final row in rawData) {
      if (index < row.length) {
        values.add(row.removeAt(index));
      } else {
        values.add(null);
      }
    }
    return values;
  }

  /// Rename a column.
  void renameColumn(String oldName, String newName) {
    final idx = headers.indexOf(oldName);
    if (idx < 0) throw CsvException('Column "$oldName" not found');
    mutableHeaders[idx] = newName;
  }

  /// Reorder columns to match the given header order.
  void reorderColumns(List<String> newOrder) {
    final indices = newOrder.map((n) {
      final idx = headers.indexOf(n);
      if (idx < 0) throw CsvException('Column "$n" not found');
      return idx;
    }).toList();

    setHeaders(newOrder.toList());
    for (var r = 0; r < rawData.length; r++) {
      final oldRow = rawData[r];
      rawData[r] = indices
          .map((i) => i < oldRow.length ? oldRow[i] : null)
          .toList();
    }
  }

  /// Apply a transform to every cell in a column.
  void transformColumn(String name, dynamic Function(dynamic value) transform) {
    final idx = headers.indexOf(name);
    if (idx < 0) throw CsvException('Column "$name" not found');
    for (final row in rawData) {
      if (idx < row.length) row[idx] = transform(row[idx]);
    }
  }

  /// Apply a transform to every row. Returns a new [CsvTable]; this table
  /// is left untouched.
  ///
  /// The [transform] receives a copy of each row, so writing through it
  /// (for example `row[0] = x`) cannot corrupt the source table.
  CsvTable map(CsvRow Function(CsvRow row) transform) {
    final headerMap = buildHeaderMap();
    final mapped = rawData.map((r) {
      final result = transform(CsvRow(List<dynamic>.from(r), headerMap));
      return List<dynamic>.from(result);
    }).toList();
    return CsvTable.internal(List<String>.from(headers), mapped);
  }

  /// Reduce rows to a single value.
  T fold<T>(T initial, T Function(T accumulator, CsvRow row) combine) {
    final headerMap = buildHeaderMap();
    var result = initial;
    for (final r in rawData) {
      result = combine(result, CsvRow(r, headerMap));
    }
    return result;
  }
}
