import 'dart:collection';

/// A single CSV row with header-aware, dual-mode access.
///
/// Extends [ListBase] so it behaves like a regular [List] everywhere,
/// but also supports named access via header strings:
///
/// ```dart
/// final row = CsvRow(['Alice', 30], {'name': 0, 'age': 1});
/// print(row[0]);       // 'Alice'  (positional)
/// print(row['age']);    // 30       (by header)
/// row.set('age', 31);  // named write
/// ```
///
/// The header map is optional. When absent, named access returns `null`
/// and header-dependent methods return empty results.
class CsvRow extends ListBase<dynamic> {
  final List<dynamic> _fields;
  final Map<String, int>? _headerMap;

  /// Create a row from [fields] with an optional [headerMap] for named access.
  CsvRow(List<dynamic> fields, [this._headerMap]) : _fields = fields;

  @override
  int get length => _fields.length;

  @override
  set length(int newLength) => _fields.length = newLength;

  /// Dual-mode access: integer index for positional, string for header-based.
  ///
  /// Returns `null` if a string key has no matching header or is out of bounds.
  @override
  dynamic operator [](Object? key) {
    if (key is int) return _fields[key];
    if (key is String) {
      final idx = _headerMap?[key];
      if (idx != null && idx < _fields.length) return _fields[idx];
    }
    return null;
  }

  @override
  void operator []=(int index, dynamic value) => _fields[index] = value;

  /// Set a field by header name. No-op if header is unknown.
  void set(String header, dynamic value) {
    final idx = _headerMap?[header];
    if (idx != null && idx < _fields.length) _fields[idx] = value;
  }

  /// The header-to-index mapping, or `null` if this row has no headers.
  Map<String, int>? get headerMap => _headerMap;

  /// Whether this row carries header information.
  bool get hasHeaders => _headerMap != null && _headerMap.isNotEmpty;

  /// All header names in column order, or empty list if no headers.
  List<String> get headers {
    if (_headerMap == null || _headerMap.isEmpty) return const [];
    final sorted = _headerMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return sorted.map((e) => e.key).toList();
  }

  /// Whether this row has a column with the given [header].
  bool containsHeader(String header) =>
      _headerMap?.containsKey(header) ?? false;

  /// Convert to `{header: value}` map. Empty map if no headers.
  Map<String, dynamic> toMap() {
    if (_headerMap == null) return const {};
    final map = <String, dynamic>{};
    for (final entry in _headerMap.entries) {
      if (entry.value < _fields.length) {
        map[entry.key] = _fields[entry.value];
      }
    }
    return map;
  }

  /// Get the header name for a positional [index], or `null`.
  String? getHeaderName(int index) {
    if (_headerMap == null) return null;
    for (final entry in _headerMap.entries) {
      if (entry.value == index) return entry.key;
    }
    return null;
  }

  @override
  String toString() {
    if (_headerMap == null || _headerMap.isEmpty) return _fields.toString();
    return toMap().toString();
  }
}
