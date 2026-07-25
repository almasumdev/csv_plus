import '../core/csv_exception.dart';

/// Defines constraints for CSV table validation.
class CsvSchema {
  /// Column definitions.
  final List<CsvColumnDef> columns;

  /// Whether extra columns (not in schema) are allowed.
  final bool allowExtraColumns;

  /// Whether fewer columns than defined are allowed.
  final bool allowMissingColumns;

  const CsvSchema({
    required this.columns,
    this.allowExtraColumns = true,
    this.allowMissingColumns = false,
  });

  /// Infer a schema from observed headers and data.
  ///
  /// Detects column types, nullability, and required status from actual values.
  factory CsvSchema.infer(List<String> headers, List<List<dynamic>> rows) {
    final columns = <CsvColumnDef>[];
    for (var c = 0; c < headers.length; c++) {
      Type? common;
      var hasNull = false;
      var allNull = true;

      for (final row in rows) {
        final v = c < row.length ? row[c] : null;
        if (v == null) {
          hasNull = true;
          continue;
        }
        allNull = false;
        final t = v.runtimeType;
        if (common == null) {
          common = t;
        } else if (common != t) {
          common = null;
          break;
        }
      }

      columns.add(
        CsvColumnDef(
          name: headers[c],
          type: allNull ? null : common,
          required: true,
          nullable: hasNull,
        ),
      );
    }
    return CsvSchema(columns: columns);
  }

  /// Validate rows against this schema. Returns list of violations.
  List<CsvValidationException> validate(
    List<String> headers,
    List<List<dynamic>> rows,
  ) {
    final errors = <CsvValidationException>[];
    final headerSet = headers.toSet();
    final schemaMap = {for (final c in columns) c.name: c};

    // Check required columns exist (skip when allowMissingColumns is true)
    if (!allowMissingColumns) {
      for (final col in columns) {
        if (col.required && !headerSet.contains(col.name)) {
          errors.add(
            CsvValidationException(
              'Missing required column: ${col.name}',
              columnName: col.name,
              rowIndex: -1,
              value: null,
              constraint: 'required',
            ),
          );
        }
      }
    }

    // Check extra columns
    if (!allowExtraColumns) {
      for (final h in headers) {
        if (!schemaMap.containsKey(h)) {
          errors.add(
            CsvValidationException(
              'Extra column not allowed: $h',
              columnName: h,
              rowIndex: -1,
              value: null,
              constraint: 'no_extra_columns',
            ),
          );
        }
      }
    }

    // Validate each row
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < headers.length && c < row.length; c++) {
        final col = schemaMap[headers[c]];
        if (col == null) continue;

        final value = row[c];

        // Nullable check
        if (!col.nullable && value == null) {
          errors.add(
            CsvValidationException(
              'Null value in non-nullable column: ${col.name}',
              columnName: col.name,
              rowIndex: r,
              value: value,
              constraint: 'non_nullable',
            ),
          );
          continue;
        }

        if (value == null) continue;

        // Type check
        if (col.type != null && value.runtimeType != col.type) {
          errors.add(
            CsvValidationException(
              'Expected ${col.type} but got ${value.runtimeType} '
              'in column ${col.name} at row $r',
              columnName: col.name,
              rowIndex: r,
              value: value,
              constraint: 'type:${col.type}',
            ),
          );
        }

        // Pattern check
        if (col.pattern != null) {
          final regex = RegExp(col.pattern!);
          if (!regex.hasMatch(value.toString())) {
            errors.add(
              CsvValidationException(
                'Value "$value" does not match pattern "${col.pattern}" '
                'in column ${col.name} at row $r',
                columnName: col.name,
                rowIndex: r,
                value: value,
                constraint: 'pattern:${col.pattern}',
              ),
            );
          }
        }

        // Custom validator
        if (col.validator != null && !col.validator!(value)) {
          errors.add(
            CsvValidationException(
              'Custom validation failed for value "$value" '
              'in column ${col.name} at row $r',
              columnName: col.name,
              rowIndex: r,
              value: value,
              constraint: 'custom',
            ),
          );
        }
      }
    }

    return errors;
  }

  /// Coerce each column's values to its declared [CsvColumnDef.type], returning
  /// freshly built rows (the input is left untouched).
  ///
  /// A column is matched to a header by name. Columns with no schema entry, and
  /// schema columns whose header is absent, are left unchanged, as are columns
  /// whose [CsvColumnDef.type] is `null`. Supported target types are `int`,
  /// `double`, `num`, `bool`, `String`, and `DateTime`; any other type is left
  /// as-is.
  ///
  /// Throws [CsvParseException] (carrying the 0-based `row` and `column`) when a
  /// value cannot be converted, or when a null appears in a column declared
  /// `nullable: false`. A null in a nullable column stays null.
  List<List<dynamic>> coerce(List<String> headers, List<List<dynamic>> rows) {
    final schemaMap = {for (final c in columns) c.name: c};
    final out = <List<dynamic>>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final newRow = List<dynamic>.from(row);
      for (var c = 0; c < headers.length && c < newRow.length; c++) {
        final col = schemaMap[headers[c]];
        if (col == null) continue;
        newRow[c] = _coerceCell(newRow[c], col, r, c);
      }
      out.add(newRow);
    }
    return out;
  }

  /// Converts a single [value] to [col]'s declared type, honoring nullability.
  static dynamic _coerceCell(
    dynamic value,
    CsvColumnDef col,
    int row,
    int column,
  ) {
    if (value == null) {
      if (col.nullable) return null;
      throw CsvParseException(
        'Null value in non-nullable column "${col.name}"',
        row: row,
        column: column,
      );
    }
    final type = col.type;
    if (type == null) return value;

    Never fail() => throw CsvParseException(
      'Cannot convert "$value" to $type in column "${col.name}"',
      row: row,
      column: column,
    );

    if (type == String) return value.toString();
    if (type == int) {
      if (value is int) return value;
      if (value is double) {
        if (value.isFinite && value == value.roundToDouble()) {
          return value.toInt();
        }
        fail();
      }
      if (value is String) return int.tryParse(value.trim()) ?? fail();
      fail();
    }
    if (type == double) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? fail();
      fail();
    }
    if (type == num) {
      if (value is num) return value;
      if (value is String) return num.tryParse(value.trim()) ?? fail();
      fail();
    }
    if (type == bool) {
      if (value is bool) return value;
      if (value is num) {
        if (value == 1) return true;
        if (value == 0) return false;
        fail();
      }
      if (value is String) {
        switch (value.trim().toLowerCase()) {
          case 'true' || '1':
            return true;
          case 'false' || '0':
            return false;
        }
        fail();
      }
      fail();
    }
    if (type == DateTime) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value.trim()) ?? fail();
      fail();
    }
    // Unknown target type: leave the value unchanged.
    return value;
  }
}

/// Defines a single column's constraints.
class CsvColumnDef {
  /// Column name (header).
  final String name;

  /// Expected type. Null means any type allowed.
  final Type? type;

  /// Whether this column must exist.
  final bool required;

  /// Whether null values are allowed.
  final bool nullable;

  /// Custom validation function.
  final bool Function(dynamic value)? validator;

  /// Regex pattern the string value must match.
  final String? pattern;

  const CsvColumnDef({
    required this.name,
    this.type,
    this.required = true,
    this.nullable = true,
    this.validator,
    this.pattern,
  });
}

/// Former name of [CsvColumnDef], kept for source compatibility.
@Deprecated('Use CsvColumnDef instead')
typedef ColumnDef = CsvColumnDef;
