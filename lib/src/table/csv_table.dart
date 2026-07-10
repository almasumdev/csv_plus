import '../codec/csv_codec.dart';
import '../core/csv_config.dart';
import '../core/csv_exception.dart';
import 'csv_column.dart';
import 'csv_row.dart';
import 'csv_schema.dart';

/// 2D CSV data structure with headers and data rows.
///
/// Query, sort, transform, and aggregate operations are available
/// via extensions from the `query/` and `transform/` layers.
///
/// ## Mutation rule
///
/// Methods that return a [CsvTable] (`where`, `range`, `take`, `skip`,
/// `distinct`, `map`, `sortedBy`, `copy`) return a new table and leave
/// this one untouched. Methods that return `void` (`sortBy`, `addRow`,
/// `addColumn`, `removeColumn`, and the other structural operations)
/// mutate this table in place.
class CsvTable {
  List<String> _headers;
  final List<List<dynamic>> _data;

  /// Create from raw 2D data (no headers).
  CsvTable(List<List<dynamic>> rows)
    : _headers = [],
      _data = rows.map((r) => List<dynamic>.from(r)).toList();

  /// Create from 2D data where first row is headers.
  CsvTable.withHeaders(List<List<dynamic>> rows)
    : _headers = rows.isNotEmpty
          ? rows.first.map((e) => e?.toString() ?? '').toList()
          : [],
      _data = rows.length > 1
          ? rows.skip(1).map((r) => List<dynamic>.from(r)).toList()
          : [];

  /// Create from explicit headers + data rows.
  CsvTable.fromData({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) : _headers = List<String>.from(headers),
       _data = rows.map((r) => List<dynamic>.from(r)).toList();

  /// Create from a list of Maps.
  factory CsvTable.fromMaps(List<Map<String, dynamic>> maps) {
    if (maps.isEmpty) return CsvTable.fromData(headers: [], rows: []);
    final headers = maps.first.keys.toList();
    final data = maps.map((m) => headers.map((h) => m[h]).toList()).toList();
    return CsvTable.fromData(headers: headers, rows: data);
  }

  /// Parse from CSV string.
  ///
  /// The first row becomes the headers and is read as raw strings (a
  /// header named `01` stays `01`); data rows follow
  /// [CsvConfig.dynamicTyping].
  factory CsvTable.parse(String csv, {CsvConfig config = const CsvConfig()}) {
    return CsvCodec(config).decodeToTable(csv);
  }

  /// Create empty table with column definitions.
  CsvTable.empty({List<String> headers = const []})
    : _headers = List<String>.from(headers),
      _data = [];

  /// Internal constructor for extensions. Creates without copying data:
  /// the caller must hand over freshly allocated lists it no longer uses.
  CsvTable.internal(this._headers, this._data);

  // --- Extension Accessors ---

  /// Direct access to the underlying data rows, without copying.
  ///
  /// This is an unchecked escape hatch for the query/transform extensions
  /// and performance-critical code. Mutations through it bypass every
  /// invariant (row width, header alignment); prefer the typed row and
  /// column APIs.
  List<List<dynamic>> get rawData => _data;

  /// Direct access to the mutable headers list, without copying.
  ///
  /// Same contract as [rawData]: unchecked, invariants are the caller's
  /// responsibility. Prefer [headers] for reading.
  List<String> get mutableHeaders => _headers;

  /// Replace headers list. The new list is not validated against the
  /// current column count.
  void setHeaders(List<String> h) => _headers = h;

  // --- Properties ---

  /// Column headers. Empty list if no headers defined.
  List<String> get headers => List.unmodifiable(_headers);

  /// Whether headers are defined.
  bool get hasHeaders => _headers.isNotEmpty;

  /// Number of data rows.
  int get rowCount => _data.length;

  /// Number of columns.
  int get columnCount => _headers.isNotEmpty
      ? _headers.length
      : (_data.isNotEmpty ? _data.first.length : 0);

  /// Whether the table has no data rows.
  bool get isEmpty => _data.isEmpty;

  bool get isNotEmpty => _data.isNotEmpty;

  /// Iterate over rows as [CsvRow].
  Iterator<CsvRow> get iterator {
    final headerMap = buildHeaderMap();
    return _data.map((r) => CsvRow(r, headerMap)).iterator;
  }

  /// Infer a [CsvSchema] from the table's headers and data.
  CsvSchema inferSchema() {
    if (!hasHeaders) {
      throw CsvException('Cannot infer schema without headers');
    }
    return CsvSchema.infer(_headers, _data);
  }

  // --- Row Access ---

  /// Get row by index as [CsvRow].
  CsvRow operator [](int index) {
    final headerMap = buildHeaderMap();
    return CsvRow(_data[index], headerMap);
  }

  /// Set/replace row at index.
  void operator []=(int index, List<dynamic> row) {
    _data[index] = List<dynamic>.from(row);
  }

  /// Get all rows as [CsvRow] list.
  List<CsvRow> get rows {
    final headerMap = buildHeaderMap();
    return _data.map((r) => CsvRow(r, headerMap)).toList();
  }

  /// Get first row.
  CsvRow get first => this[0];

  /// Get last row.
  CsvRow get last => this[_data.length - 1];

  // --- Column Access ---

  /// Get all values in a column by header name.
  List<dynamic> column(String name) {
    final idx = _headers.indexOf(name);
    if (idx < 0) {
      throw CsvException('Column "$name" not found');
    }
    return columnAt(idx);
  }

  /// Get all values in a column by index.
  List<dynamic> columnAt(int index) {
    return _data.map((r) => index < r.length ? r[index] : null).toList();
  }

  /// Get column descriptor by name.
  CsvColumn getColumn(String name) {
    final idx = _headers.indexOf(name);
    if (idx < 0) throw CsvException('Column "$name" not found');
    return getColumnAt(idx);
  }

  /// Get column descriptor by index.
  CsvColumn getColumnAt(int index) {
    return CsvColumn(
      name: index < _headers.length ? _headers[index] : 'col_$index',
      index: index,
      values: columnAt(index),
    );
  }

  // --- Cell Access ---

  /// Get cell value at (row, col).
  dynamic cell(int row, int col) => _data[row][col];

  /// Get cell value by row index and column name.
  dynamic cellByName(int row, String columnName) {
    final idx = _headers.indexOf(columnName);
    if (idx < 0) throw CsvException('Column "$columnName" not found');
    return _data[row][idx];
  }

  /// Set cell value.
  void setCell(int row, int col, dynamic value) => _data[row][col] = value;

  /// Set cell by row index and column name.
  void setCellByName(int row, String columnName, dynamic value) {
    final idx = _headers.indexOf(columnName);
    if (idx < 0) throw CsvException('Column "$columnName" not found');
    _data[row][idx] = value;
  }

  // --- Row Manipulation ---

  /// Add a row at the end.
  void addRow(List<dynamic> row) => _data.add(List<dynamic>.from(row));

  /// Add a row from a map (requires headers).
  void addRowFromMap(Map<String, dynamic> map) {
    final row = _headers.map((h) => map[h]).toList();
    _data.add(row);
  }

  /// Insert a row at index.
  void insertRow(int index, List<dynamic> row) {
    _data.insert(index, List<dynamic>.from(row));
  }

  /// Remove row at index. Returns removed row.
  CsvRow removeRow(int index) {
    final removed = _data.removeAt(index);
    return CsvRow(removed, buildHeaderMap());
  }

  /// Remove rows matching predicate. Returns count removed.
  int removeWhere(bool Function(CsvRow row) test) {
    final headerMap = buildHeaderMap();
    var removed = 0;
    _data.removeWhere((r) {
      if (test(CsvRow(r, headerMap))) {
        removed++;
        return true;
      }
      return false;
    });
    return removed;
  }

  /// Add multiple rows.
  void addRows(List<List<dynamic>> rows) {
    for (final row in rows) {
      _data.add(List<dynamic>.from(row));
    }
  }

  // --- Conversion ---

  /// Convert to list of rows, optionally including header row.
  List<List<dynamic>> toList({bool includeHeaders = false}) {
    final result = <List<dynamic>>[];
    if (includeHeaders && _headers.isNotEmpty) {
      result.add(List<dynamic>.from(_headers));
    }
    for (final r in _data) {
      result.add(List<dynamic>.from(r));
    }
    return result;
  }

  /// Convert to list of maps.
  List<Map<String, dynamic>> toMaps() {
    return _data.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < _headers.length; i++) {
        map[_headers[i]] = i < row.length ? row[i] : null;
      }
      return map;
    }).toList();
  }

  /// Encode to CSV string.
  String toCsv({CsvConfig config = const CsvConfig()}) {
    return CsvCodec(config).encode(toList(includeHeaders: hasHeaders));
  }

  // --- Schema Validation ---

  /// Validate all rows against a schema. Returns list of violations.
  List<CsvValidationException> validate(CsvSchema schema) {
    return schema.validate(_headers, _data);
  }

  /// Check if table conforms to schema.
  bool conformsTo(CsvSchema schema) => validate(schema).isEmpty;

  // --- Copying ---

  /// Deep copy of the table.
  CsvTable copy() {
    return CsvTable.internal(
      List<String>.from(_headers),
      _data.map((r) => List<dynamic>.from(r)).toList(),
    );
  }

  // --- Printing ---

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('CsvTable($rowCount rows, $columnCount cols)');
    if (hasHeaders) buf.writeln('Headers: $_headers');
    final preview = _data.length > 5 ? _data.sublist(0, 5) : _data;
    for (final row in preview) {
      buf.writeln(row);
    }
    if (_data.length > 5) buf.writeln('... (${_data.length - 5} more rows)');
    return buf.toString();
  }

  /// Pretty-print as aligned table.
  String toFormattedString({int maxRows = 20, int maxColumnWidth = 30}) {
    final allRows = <List<String>>[];
    if (hasHeaders) allRows.add(_headers);
    final previewData = _data.length > maxRows
        ? _data.sublist(0, maxRows)
        : _data;
    for (final row in previewData) {
      allRows.add(
        row.map((c) {
          final s = c?.toString() ?? 'null';
          return s.length > maxColumnWidth
              ? '${s.substring(0, maxColumnWidth - 3)}...'
              : s;
        }).toList(),
      );
    }

    if (allRows.isEmpty) return '(empty table)';

    final colCount = allRows
        .map((r) => r.length)
        .reduce((a, b) => a > b ? a : b);
    final widths = List.filled(colCount, 0);
    for (final row in allRows) {
      for (var i = 0; i < row.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }

    final buf = StringBuffer();
    for (var r = 0; r < allRows.length; r++) {
      final row = allRows[r];
      for (var c = 0; c < colCount; c++) {
        final val = c < row.length ? row[c] : '';
        buf.write(val.padRight(widths[c]));
        if (c < colCount - 1) buf.write(' | ');
      }
      buf.writeln();
      if (r == 0 && hasHeaders) {
        for (var c = 0; c < colCount; c++) {
          buf.write('-' * widths[c]);
          if (c < colCount - 1) buf.write('-+-');
        }
        buf.writeln();
      }
    }

    if (_data.length > maxRows) {
      buf.writeln('... (${_data.length - maxRows} more rows)');
    }
    return buf.toString();
  }

  // --- Helpers ---

  /// Build header name-to-index map, or null if no headers.
  Map<String, int>? buildHeaderMap() {
    if (_headers.isEmpty) return null;
    return {for (var i = 0; i < _headers.length; i++) _headers[i]: i};
  }

  /// Compare two dynamic values with a documented total order.
  ///
  /// Nulls sort last regardless of direction. Values of the same type
  /// compare naturally. Mixed types compare by type rank: numbers, then
  /// strings, then booleans, then everything else (by `toString`), so a
  /// mixed column sorts numbers before their string look-alikes instead
  /// of comparing `"10" < "9"` lexicographically.
  static int compareValues(dynamic a, dynamic b, bool ascending) {
    final multiplier = ascending ? 1 : -1;
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final rankA = _typeRank(a);
    final rankB = _typeRank(b);
    if (rankA != rankB) return (rankA - rankB) * multiplier;
    if (a is num && b is num) return a.compareTo(b) * multiplier;
    if (a is String && b is String) return a.compareTo(b) * multiplier;
    if (a is bool && b is bool) {
      return (a == b ? 0 : (a ? 1 : -1)) * multiplier;
    }
    return a.toString().compareTo(b.toString()) * multiplier;
  }

  static int _typeRank(dynamic v) {
    if (v is num) return 0;
    if (v is String) return 1;
    if (v is bool) return 2;
    return 3;
  }
}
