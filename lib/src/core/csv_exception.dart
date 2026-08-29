/// Base exception for all CSV operations.
///
/// Subclasses: [CsvParseException] (malformed input),
/// [CsvValidationException] (schema violations).
class CsvException implements Exception {
  /// Human readable description of what went wrong.
  final String message;

  /// Creates an exception carrying [message].
  const CsvException(this.message);

  @override
  String toString() => 'CsvException: $message';
}

/// Thrown when CSV input cannot be parsed.
///
/// Includes optional [row], [column], and [offset] to locate the error.
class CsvParseException extends CsvException {
  /// Zero-based index of the record the error was found in, if known.
  final int? row;

  /// Zero-based index of the field within [row], if known.
  final int? column;

  /// Byte offset into the input where the error was found, if known.
  final int? offset;

  /// Creates a parse error, optionally locating it by [row], [column] and
  /// [offset].
  const CsvParseException(super.message, {this.row, this.column, this.offset});

  @override
  String toString() {
    final location = <String>[];
    if (row != null) location.add('row: $row');
    if (column != null) location.add('column: $column');
    if (offset != null) location.add('offset: $offset');
    final loc = location.isEmpty ? '' : ' (${location.join(', ')})';
    return 'CsvParseException: $message$loc';
  }
}

/// Thrown when CSV data fails [CsvSchema] validation.
///
/// Contains the [columnName], [rowIndex], offending [value], and
/// the [constraint] that was violated.
class CsvValidationException extends CsvException {
  /// Name of the column whose value failed validation.
  final String columnName;

  /// Zero-based index of the offending data row.
  final int rowIndex;

  /// The value that failed, as it was decoded.
  final dynamic value;

  /// The rule that was violated, for example `type` or `required`.
  final String constraint;

  /// Creates a validation failure for one cell.
  const CsvValidationException(
    super.message, {
    required this.columnName,
    required this.rowIndex,
    required this.value,
    required this.constraint,
  });

  @override
  String toString() =>
      'CsvValidationException: $message (row: $rowIndex, column: "$columnName", '
      'value: $value, constraint: $constraint)';
}
