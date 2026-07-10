/// 2D table data structure for CSV data.
///
/// [CsvTable] is the primary class: a mutable 2D data structure with
/// optional column headers. Construct from raw data, maps, or parse
/// directly from a CSV string:
///
/// ```dart
/// final table = CsvTable.parse('name,age\nAlice,30\nBob,25');
/// print(table.cell(0, 0));           // Alice
/// print(table.cellByName(0, 'age')); // 30
/// ```
///
/// Supporting types:
///
/// - [CsvRow]: header-aware row with dual-mode access (`row[0]` or
///   `row['name']`). Extends `ListBase<dynamic>`.
/// - [CsvColumn]: column descriptor with analytics (`inferredType`,
///   `nonNullCount`, `uniqueCount`).
/// - [CsvSchema] / [CsvColumnDef]: schema inference and validation.
library;

export 'src/table/csv_table.dart';
export 'src/table/csv_row.dart';
export 'src/table/csv_column.dart';
export 'src/table/csv_schema.dart';
