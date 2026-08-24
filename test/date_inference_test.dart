import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

const _on = CsvConfig(parseDates: true);

/// Decodes a one-column, one-row CSV holding [field] and returns that value.
dynamic _decodeOne(String field, {CsvConfig config = _on}) =>
    CsvCodec(config).decode('h\n$field')[1][0];

void main() {
  group('Date Inference', () {
    test('is off by default so a date stays text', () {
      expect(_decodeOne('2024-01-31', config: const CsvConfig()), '2024-01-31');
    });

    test('reads a plain ISO date as a local DateTime', () {
      final value = _decodeOne('2024-01-31');

      expect(value, isA<DateTime>());
      expect(value, DateTime(2024, 1, 31));
      expect((value as DateTime).isUtc, isFalse);
    });

    test('reads an ISO date-time with a T separator', () {
      expect(_decodeOne('2024-01-31T09:30:00'), DateTime(2024, 1, 31, 9, 30));
    });

    test('accepts a space in place of the T separator', () {
      expect(_decodeOne('2024-01-31 09:30:00'), DateTime(2024, 1, 31, 9, 30));
    });

    test('accepts an hour-only and a minute-only time part', () {
      expect(_decodeOne('2024-01-31T09'), DateTime(2024, 1, 31, 9));
      expect(_decodeOne('2024-01-31T09:30'), DateTime(2024, 1, 31, 9, 30));
    });

    test('keeps fractional seconds', () {
      expect(
        _decodeOne('2024-01-31T09:30:00.123'),
        DateTime(2024, 1, 31, 9, 30, 0, 123),
      );
    });

    test('reads a trailing Z as UTC', () {
      final value = _decodeOne('2024-01-31T09:30:00Z') as DateTime;

      expect(value.isUtc, isTrue);
      expect(value, DateTime.utc(2024, 1, 31, 9, 30));
    });

    test('applies a numeric offset and normalises to UTC', () {
      final value = _decodeOne('2024-01-31T09:30:00+05:30') as DateTime;

      expect(value.isUtc, isTrue);
      expect(value, DateTime.utc(2024, 1, 31, 4, 0));
    });

    test('accepts 29 February in a leap year', () {
      expect(_decodeOne('2024-02-29'), DateTime(2024, 2, 29));
    });
  });

  group('Date Inference Guards', () {
    test('leaves an ambiguous locale format as text', () {
      expect(_decodeOne('03/04/2024'), '03/04/2024');
      expect(_decodeOne('31.01.2024'), '31.01.2024');
    });

    test('leaves an impossible month or day as text instead of rolling it '
        'over', () {
      expect(_decodeOne('2024-13-45'), '2024-13-45');
      expect(_decodeOne('2024-00-10'), '2024-00-10');
      expect(_decodeOne('2024-02-30'), '2024-02-30');
      expect(_decodeOne('2024-04-31'), '2024-04-31');
      expect(_decodeOne('2023-02-29'), '2023-02-29');
    });

    test('leaves an impossible time as text instead of rolling it over', () {
      expect(_decodeOne('2024-01-31T25:00:00'), '2024-01-31T25:00:00');
      expect(_decodeOne('2024-01-31T09:60:00'), '2024-01-31T09:60:00');
    });

    test('leaves an unpunctuated digit run as a number', () {
      expect(_decodeOne('20240131'), 20240131);
    });

    test('leaves a single-digit month or day as text', () {
      expect(_decodeOne('2024-1-31'), '2024-1-31');
    });

    test('leaves text on either side of a date as text', () {
      expect(_decodeOne('2024-01-31x'), '2024-01-31x');
      expect(_decodeOne('x2024-01-31'), 'x2024-01-31');
      expect(_decodeOne('-2024-01-31'), '-2024-01-31');
    });

    test('never infers a quoted field', () {
      expect(_decodeOne('"2024-01-31"'), '2024-01-31');
    });

    test('leaves numbers and identifiers untouched', () {
      expect(CsvCodec(_on).decode('a,b,c\n007,42,1.5')[1], ['007', 42, 1.5]);
    });

    test('does nothing when dynamicTyping is off', () {
      const config = CsvConfig(parseDates: true, dynamicTyping: false);

      expect(_decodeOne('2024-01-31', config: config), '2024-01-31');
    });

    test('leaves the header row as text', () {
      const config = CsvConfig(parseDates: true, hasHeader: true);
      final table = CsvCodec(config).decodeToTable('2024-01-31\n2024-02-01');

      expect(table.headers, ['2024-01-31']);
      expect(table.rawData[0][0], DateTime(2024, 2, 1));
    });
  });

  group('Date Inference Across Decoders', () {
    test('applies in the streaming decoder', () async {
      final rows = await Stream.value(
        'when\n2024-01-31\n',
      ).transform(const CsvDecoder(_on)).toList();

      expect(rows[1][0], DateTime(2024, 1, 31));
    });

    test('applies when a date is split across stream chunks', () async {
      final rows = await Stream.fromIterable([
        'when\n2024-',
        '01-31\n',
      ]).transform(const CsvDecoder(_on)).toList();

      expect(rows[1][0], DateTime(2024, 1, 31));
    });

    test('applies in the byte-stream decoder', () async {
      final rows = await const CsvDecoder(
        _on,
      ).bindBytes(Stream.value(utf8.encode('when\n2024-01-31\n'))).toList();

      expect(rows[1][0], DateTime(2024, 1, 31));
    });

    test('applies in decodeToTable and decodeToMaps', () {
      final codec = CsvCodec(_on);

      expect(
        codec.decodeToTable('when,who\n2024-01-31,Alice').rawData[0][0],
        DateTime(2024, 1, 31),
      );
      expect(
        codec.decodeToMaps('when\n2024-01-31').first['when'],
        DateTime(2024, 1, 31),
      );
    });

    test('does not apply in decodeStrings', () {
      expect(CsvCodec(_on).decodeStrings('h\n2024-01-31')[1][0], '2024-01-31');
    });

    test('is carried by copyWith', () {
      expect(const CsvConfig().copyWith(parseDates: true).parseDates, isTrue);
      expect(_on.copyWith(fieldDelimiter: ';').parseDates, isTrue);
    });

    test('is available on every preset', () {
      expect(const CsvConfig.excel(parseDates: true).parseDates, isTrue);
      expect(const CsvConfig.tsv(parseDates: true).parseDates, isTrue);
      expect(const CsvConfig.pipe(parseDates: true).parseDates, isTrue);
    });
  });

  group('ISO Date Parsing', () {
    test('exposes the shared parser used by every decode path', () {
      expect(
        FastDecoder.tryParseIsoDateTime('2024-01-31'),
        DateTime(2024, 1, 31),
      );
      expect(FastDecoder.tryParseIsoDateTime('2024-13-45'), isNull);
      expect(FastDecoder.tryParseIsoDateTime('nope'), isNull);
      expect(FastDecoder.tryParseIsoDateTime(''), isNull);
    });

    test('inferType parses dates only when asked', () {
      expect(FastDecoder.inferType('2024-01-31'), '2024-01-31');
      expect(
        FastDecoder.inferType('2024-01-31', parseDates: true),
        DateTime(2024, 1, 31),
      );
    });
  });
}
