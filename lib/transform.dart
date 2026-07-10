/// Column manipulation and aggregation extensions for [CsvTable].
///
/// **Manipulation** ([CsvTableManipulation]):
/// - [CsvTableManipulation.addColumn] / [CsvTableManipulation.insertColumn]:
///   add columns with default values.
/// - [CsvTableManipulation.removeColumn] /
///   [CsvTableManipulation.removeColumnAt]: remove and return column values.
/// - [CsvTableManipulation.renameColumn]: rename a column.
/// - [CsvTableManipulation.reorderColumns]: reorder to new column order.
/// - [CsvTableManipulation.transformColumn]: apply a function to every cell
///   in a column.
/// - [CsvTableManipulation.map] / [CsvTableManipulation.fold]: functional
///   row operations.
///
/// **Aggregation** ([CsvTableAggregation]):
/// - [CsvTableAggregation.count], [CsvTableAggregation.sum],
///   [CsvTableAggregation.avg]: numeric statistics.
/// - [CsvTableAggregation.min] / [CsvTableAggregation.max]: type-aware
///   extremes.
/// - [CsvTableAggregation.groupBy]: group rows by column value into
///   sub-tables.
///
/// ```dart
/// table.addColumn('score', defaultValue: 0);
/// print(table.avg('age'));
/// final groups = table.groupBy('department');
/// ```
library;

export 'src/transform/manipulation.dart';
export 'src/transform/aggregation.dart';
