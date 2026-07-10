/// Base exception for all CSV operations.
///
/// Subclasses: [CsvParseException] (malformed input),
/// [CsvValidationException] (schema violations).
class CsvException implements Exception {
  final String message;

  const CsvException(this.message);

  @override
  String toString() => 'CsvException: $message';
}

/// Thrown when CSV input cannot be parsed.
///
/// Includes optional [row], [column], and [offset] to locate the error.
class CsvParseException extends CsvException {
  final int? row;
  final int? column;
  final int? offset;

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
  final String columnName;
  final int rowIndex;
  final dynamic value;
  final String constraint;

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
