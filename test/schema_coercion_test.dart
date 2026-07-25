import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// A codec that reads every field as a string (so coercion does the typing).
const _strings = CsvCodec(CsvConfig(autoDetect: false, dynamicTyping: false));

/// A codec with type inference on (empty cells become null).
const _typed = CsvCodec(CsvConfig(autoDetect: false));

void main() {
  group('Schema Coercion', () {
    test('decodeWithSchema converts each column to its declared type', () {
      const schema = CsvSchema(
        columns: [
          CsvColumnDef(name: 'id', type: int),
          CsvColumnDef(name: 'price', type: double),
          CsvColumnDef(name: 'active', type: bool),
          CsvColumnDef(name: 'name', type: String),
        ],
      );
      final table = _strings.decodeWithSchema(
        'id,price,active,name\n1,9.5,true,Ada\n2,3,0,Bo',
        schema,
      );

      expect(table.rawData[0][0], isA<int>());
      expect(table.rawData[0][0], 1);
      expect(table.rawData[0][1], isA<double>());
      expect(table.rawData[0][1], 9.5);
      expect(table.rawData[0][2], true);
      expect(table.rawData[0][3], 'Ada');

      // Row 2: "3" -> double 3.0, "0" -> false.
      expect(table.rawData[1][1], isA<double>());
      expect(table.rawData[1][1], 3.0);
      expect(table.rawData[1][2], false);
    });

    test('columns without a schema entry are left unchanged', () {
      const schema = CsvSchema(
        columns: [CsvColumnDef(name: 'n', type: int)],
      );
      final table = _strings.decodeWithSchema('n,note\n1,keep', schema);
      expect(table.rawData[0][0], 1);
      expect(table.rawData[0][1], 'keep'); // untouched string
    });

    test('a value that cannot convert throws CsvParseException with a '
        'location', () {
      const schema = CsvSchema(
        columns: [CsvColumnDef(name: 'n', type: int)],
      );
      expect(
        () => _strings.decodeWithSchema('n\n1\nx', schema),
        throwsA(
          isA<CsvParseException>()
              .having((e) => e.row, 'row', 1)
              .having((e) => e.column, 'column', 0),
        ),
      );
    });

    test('a null in a nullable column is kept', () {
      const schema = CsvSchema(
        columns: [
          CsvColumnDef(name: 'a', type: int),
          CsvColumnDef(name: 'b', type: int, nullable: true),
        ],
      );
      final table = _typed.decodeWithSchema('a,b\n1,\n2,7', schema);
      expect(table.rawData[0][0], 1);
      expect(table.rawData[0][1], isNull);
      expect(table.rawData[1][1], 7);
    });

    test('a null in a non-nullable column throws CsvParseException', () {
      const schema = CsvSchema(
        columns: [CsvColumnDef(name: 'a', type: int, nullable: false)],
      );
      expect(
        () => _typed.decodeWithSchema('a,b\n,5', schema),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('DateTime columns parse ISO-8601 strings', () {
      const schema = CsvSchema(
        columns: [CsvColumnDef(name: 'd', type: DateTime)],
      );
      final table = _strings.decodeWithSchema('d\n2026-07-25', schema);
      expect(table.rawData[0][0], isA<DateTime>());
      expect((table.rawData[0][0] as DateTime).year, 2026);
    });

    test('a column with a null type is left unchanged', () {
      const schema = CsvSchema(columns: [CsvColumnDef(name: 'x')]);
      final table = _strings.decodeWithSchema('x\n007', schema);
      expect(table.rawData[0][0], '007'); // no type => not coerced
    });

    test(
      'CsvTable.coerce returns a copy and leaves the original untouched',
      () {
        final original = CsvTable.parse('n\n1\n2'); // n inferred as int
        const schema = CsvSchema(
          columns: [CsvColumnDef(name: 'n', type: double)],
        );
        final coerced = original.coerce(schema);

        expect(coerced.rawData[0][0], isA<double>());
        expect(coerced.rawData[0][0], 1.0);
        // The source table still holds the original int.
        expect(original.rawData[0][0], isA<int>());
        expect(original.rawData[0][0], 1);
      },
    );

    test('already-correct values pass through unchanged', () {
      const schema = CsvSchema(
        columns: [CsvColumnDef(name: 'n', type: int)],
      );
      // dynamicTyping already produced ints; coercion is a no-op.
      final table = _typed.decodeWithSchema('n\n5\n6', schema);
      expect(table.rawData[0][0], 5);
      expect(table.rawData[1][0], 6);
    });
  });
}
