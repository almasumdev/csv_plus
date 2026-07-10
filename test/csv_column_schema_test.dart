import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvColumn', () {
    test('basic properties', () {
      final col = CsvColumn(
        name: 'score',
        index: 0,
        values: [10, 20, null, 30],
      );
      expect(col.name, 'score');
      expect(col.index, 0);
      expect(col.nonNullCount, 3);
      expect(col.nullCount, 1);
      expect(col.uniqueCount, 4); // 10, 20, null, 30
    });

    test('inferredType with uniform type', () {
      final col = CsvColumn(name: 'a', index: 0, values: [1, 2, 3]);
      expect(col.inferredType, int);
    });

    test('inferredType with mixed types', () {
      final col = CsvColumn(name: 'a', index: 0, values: [1, 'two', 3]);
      expect(col.inferredType, dynamic);
    });

    test('inferredType with only nulls', () {
      final col = CsvColumn(name: 'a', index: 0, values: [null, null]);
      expect(col.inferredType, dynamic);
    });

    test('inferredType ignores nulls', () {
      final col = CsvColumn(name: 'a', index: 0, values: [null, 1, null, 2]);
      expect(col.inferredType, int);
    });
  });

  group('CsvSchema', () {
    test('validate returns empty list for valid data', () {
      final schema = CsvSchema(columns: [
        CsvColumnDef(name: 'name', type: String),
        CsvColumnDef(name: 'age', type: int),
      ]);
      final errors = schema.validate(
        ['name', 'age'],
        [
          ['Alice', 30],
        ],
      );
      expect(errors, isEmpty);
    });

    test('validate detects missing required column', () {
      final schema = CsvSchema(columns: [
        CsvColumnDef(name: 'required_col', required: true),
      ]);
      final errors = schema.validate(['other'], []);
      expect(errors, hasLength(1));
    });

    test('validate skips missing optional column', () {
      final schema = CsvSchema(columns: [
        CsvColumnDef(name: 'optional_col', required: false),
      ]);
      final errors = schema.validate(['other'], []);
      expect(errors, isEmpty);
    });

    test('allowMissingColumns respected', () {
      final schema = CsvSchema(
        columns: [
          CsvColumnDef(name: 'a', required: true),
        ],
        allowMissingColumns: true,
      );
      // allowMissingColumns suppresses missing-column errors
      final errors = schema.validate([], []);
      expect(errors, isEmpty);

      // Without the flag, missing required column is an error
      final strict = CsvSchema(
        columns: [
          CsvColumnDef(name: 'a', required: true),
        ],
        allowMissingColumns: false,
      );
      final strictErrors = strict.validate([], []);
      expect(strictErrors, hasLength(1));
    });

    test('custom validator integration', () {
      final schema = CsvSchema(columns: [
        CsvColumnDef(
          name: 'val',
          validator: (v) => v is int && v > 0,
        ),
      ]);
      final errors = schema.validate(
        ['val'],
        [
          [0],
          [5],
          [-1],
        ],
      );
      expect(errors, hasLength(2)); // 0 and -1 fail
    });
  });
}
