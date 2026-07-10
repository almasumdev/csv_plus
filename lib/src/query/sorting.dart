import '../core/csv_exception.dart';
import '../table/csv_row.dart';
import '../table/csv_table.dart';

/// Stable in-place sort: equal rows keep their relative order, so
/// sequential sorts refine instead of scrambling each other.
void _stableSortRows(
  List<List<dynamic>> data,
  int Function(List<dynamic> a, List<dynamic> b) compare,
) {
  final decorated = List.generate(data.length, (i) => (i, data[i]));
  decorated.sort((x, y) {
    final c = compare(x.$2, y.$2);
    return c != 0 ? c : x.$1 - y.$1;
  });
  for (var i = 0; i < data.length; i++) {
    data[i] = decorated[i].$2;
  }
}

/// Sorting operations on [CsvTable].
///
/// All sorts are stable and mutate the table in place; [sortedBy] returns
/// a sorted copy instead. Nulls sort last regardless of direction (see
/// [CsvTable.compareValues]).
extension CsvTableSorting on CsvTable {
  /// Sort by column name (stable, in place).
  void sortBy(String column, {bool ascending = true}) {
    final idx = headers.indexOf(column);
    if (idx < 0) throw CsvException('Column "$column" not found');
    sortByIndex(idx, ascending: ascending);
  }

  /// Sort by column index (stable, in place).
  void sortByIndex(int column, {bool ascending = true}) {
    _stableSortRows(rawData, (a, b) {
      final va = column < a.length ? a[column] : null;
      final vb = column < b.length ? b[column] : null;
      return CsvTable.compareValues(va, vb, ascending);
    });
  }

  /// Sort by multiple columns (stable, in place).
  void sortByMultiple(List<(String column, bool ascending)> criteria) {
    final indices = criteria.map((c) {
      final idx = headers.indexOf(c.$1);
      if (idx < 0) throw CsvException('Column "${c.$1}" not found');
      return (idx, c.$2);
    }).toList();

    _stableSortRows(rawData, (a, b) {
      for (final (col, asc) in indices) {
        final va = col < a.length ? a[col] : null;
        final vb = col < b.length ? b[col] : null;
        final cmp = CsvTable.compareValues(va, vb, asc);
        if (cmp != 0) return cmp;
      }
      return 0;
    });
  }

  /// Sort with custom comparator (stable, in place).
  void sort(int Function(CsvRow a, CsvRow b) compare) {
    final headerMap = buildHeaderMap();
    _stableSortRows(
      rawData,
      (a, b) => compare(CsvRow(a, headerMap), CsvRow(b, headerMap)),
    );
  }

  /// Return a copy of this table sorted by column name; this table is
  /// left untouched.
  CsvTable sortedBy(String column, {bool ascending = true}) {
    final result = copy();
    result.sortBy(column, ascending: ascending);
    return result;
  }
}
