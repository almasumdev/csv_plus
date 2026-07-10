/// Filtering and sorting extensions for [CsvTable].
///
/// These extensions add query functionality to any [CsvTable] instance:
///
/// **Filtering** ([CsvTableFiltering]):
/// - [CsvTableFiltering.where]: filter rows by predicate.
/// - [CsvTableFiltering.firstWhere]: find first matching row.
/// - [CsvTableFiltering.any] / [CsvTableFiltering.every]: row predicates.
/// - [CsvTableFiltering.range], [CsvTableFiltering.take],
///   [CsvTableFiltering.skip]: slicing.
/// - [CsvTableFiltering.distinct]: deduplicate by all or selected columns.
///
/// **Sorting** ([CsvTableSorting]):
/// - [CsvTableSorting.sortBy]: sort by column name.
/// - [CsvTableSorting.sortByIndex]: sort by column index.
/// - [CsvTableSorting.sortByMultiple]: multi-column compound sort.
/// - [CsvTableSorting.sort]: custom comparator.
///
/// ```dart
/// final young = table.where((row) => row['age'] < 30);
/// table.sortBy('name');
/// ```
library;

export 'src/query/filtering.dart';
export 'src/query/sorting.dart';
