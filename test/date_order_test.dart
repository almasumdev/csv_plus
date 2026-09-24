import 'dart:convert';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// Decodes [input] through every typed path and asserts they agree.
///
/// Date resolution has to mean the same thing in the batch decoder and the
/// streaming one, so every case is checked against both, with the stream split
/// at every possible offset.
List<List<dynamic>> decodeAllPaths(String input, CsvConfig config) {
  final batch = CsvCodec(config).decode(input);
  expect(
    CsvDecoder(config).convert(input),
    batch,
    reason: 'streaming disagreed with batch',
  );
  for (var at = 1; at < input.length; at++) {
    final rows = <List<dynamic>>[];
    final sink = CsvDecoder(config).startChunkedConversion(
      ChunkedConversionSink<List<dynamic>>.withCallback(rows.addAll),
    );
    sink.add(input.substring(0, at));
    sink.add(input.substring(at));
    sink.close();
    expect(rows, batch, reason: 'chunk split at $at disagreed');
  }
  return batch;
}

/// The single decoded value of a one-cell document.
dynamic only(String cell, CsvConfig config) =>
    decodeAllPaths(cell, config)[0][0];

void main() {
  const iso = CsvConfig(autoDetect: false, parseDates: true);
  const dayFirst = CsvConfig(
    autoDetect: false,
    parseDates: true,
    dateOrder: CsvDateOrder.dayFirst,
  );
  const monthFirst = CsvConfig(
    autoDetect: false,
    parseDates: true,
    dateOrder: CsvDateOrder.monthFirst,
  );

  group('Ambiguous Date Order', () {
    test('the default leaves an ambiguous date as text', () {
      // Reading it either way would be a guess, so it stays a string.
      expect(only('03/04/2024', iso), '03/04/2024');
    });

    test('day first reads the day before the month', () {
      expect(only('03/04/2024', dayFirst), DateTime(2024, 4, 3));
    });

    test('month first reads the month before the day', () {
      expect(only('03/04/2024', monthFirst), DateTime(2024, 3, 4));
    });

    test('the same text means different days under the two orders', () {
      // The whole point of the option: one document, two readings.
      expect(only('05/06/2024', dayFirst), DateTime(2024, 6, 5));
      expect(only('05/06/2024', monthFirst), DateTime(2024, 5, 6));
    });

    test('a day past twelve is unambiguous but still needs the order', () {
      expect(only('25/12/2024', dayFirst), DateTime(2024, 12, 25));
      // Month 25 does not exist, so month-first leaves it as text rather than
      // quietly rolling it over into another year.
      expect(only('25/12/2024', monthFirst), '25/12/2024');
    });
  });

  group('Accepted Forms', () {
    test('a single digit day or month is accepted', () {
      expect(only('3/4/2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('3/12/2024', dayFirst), DateTime(2024, 12, 3));
    });

    test('slash, dash and dot all separate', () {
      expect(only('03/04/2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('03-04-2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('03.04.2024', dayFirst), DateTime(2024, 4, 3));
    });

    test('a two-digit year follows the spreadsheet convention', () {
      // Up to 68 is this century, from 69 is the last one.
      expect(only('03/04/24', dayFirst), DateTime(2024, 4, 3));
      expect(only('03/04/68', dayFirst), DateTime(2068, 4, 3));
      expect(only('03/04/69', dayFirst), DateTime(1969, 4, 3));
      expect(only('03/04/99', dayFirst), DateTime(1999, 4, 3));
    });

    test('a trailing time is kept', () {
      expect(only('03/04/2024 14:30', dayFirst), DateTime(2024, 4, 3, 14, 30));
      expect(
        only('03/04/2024 14:30:45', dayFirst),
        DateTime(2024, 4, 3, 14, 30, 45),
      );
    });

    test('ISO still parses whichever order is set', () {
      expect(only('2024-01-31', dayFirst), DateTime(2024, 1, 31));
      expect(only('2024-01-31', monthFirst), DateTime(2024, 1, 31));
      expect(
        only('2024-01-31T09:30:00', dayFirst),
        DateTime(2024, 1, 31, 9, 30),
      );
    });

    test('a leap day is accepted only in a leap year', () {
      expect(only('29/02/2024', dayFirst), DateTime(2024, 2, 29));
      expect(only('29/02/2023', dayFirst), '29/02/2023');
    });
  });

  group('Rejected Forms', () {
    test('an impossible date stays text instead of rolling over', () {
      // DateTime would happily turn month 13 into the next January.
      expect(only('45/13/2024', dayFirst), '45/13/2024');
      expect(only('32/01/2024', dayFirst), '32/01/2024');
      expect(only('00/01/2024', dayFirst), '00/01/2024');
      expect(only('01/00/2024', dayFirst), '01/00/2024');
    });

    test('an impossible time stays text', () {
      expect(only('03/04/2024 25:00', dayFirst), '03/04/2024 25:00');
      expect(only('03/04/2024 12:61', dayFirst), '03/04/2024 12:61');
    });

    test('mixed separators are not a date', () {
      expect(only('03/04-2024', dayFirst), '03/04-2024');
    });

    test('a three-digit year is not a date', () {
      expect(only('03/04/204', dayFirst), '03/04/204');
    });

    test('an unpunctuated run stays text', () {
      // Far more likely an identifier than a date, so it is left alone.
      expect(only('03042024', dayFirst), '03042024');
    });

    test('something that is not a date at all is untouched', () {
      expect(only('hello', dayFirst), 'hello');
      expect(only('1/2', dayFirst), '1/2');
      expect(only('a/b/c', dayFirst), 'a/b/c');
    });

    test('a quoted field is never inferred', () {
      expect(only('"03/04/2024"', dayFirst), '03/04/2024');
    });

    test('it does nothing unless parseDates is on', () {
      const off = CsvConfig(
        autoDetect: false,
        dateOrder: CsvDateOrder.dayFirst,
      );
      expect(only('03/04/2024', off), '03/04/2024');
    });
  });

  group('Named Months', () {
    test('day before the month name', () {
      expect(only('3 April 2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('03 Apr 2024', dayFirst), DateTime(2024, 4, 3));
    });

    test('month name before the day, with or without a comma', () {
      expect(only('April 3 2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('"April 3, 2024"', dayFirst), 'April 3, 2024');
      // Unquoted, the comma would split the field, so the comma form is
      // checked on a tab-delimited document instead.
      const tabs = CsvConfig(
        autoDetect: false,
        fieldDelimiter: '\t',
        parseDates: true,
        dateOrder: CsvDateOrder.dayFirst,
      );
      expect(only('April 3, 2024', tabs), DateTime(2024, 4, 3));
    });

    test('the name fixes the order whichever dateOrder is set', () {
      // The month is named, so month-first and day-first agree.
      expect(only('3 April 2024', monthFirst), DateTime(2024, 4, 3));
      expect(only('April 3 2024', monthFirst), DateTime(2024, 4, 3));
    });

    test('the dashed spreadsheet form is read', () {
      expect(only('03-Apr-2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('3-Apr-24', dayFirst), DateTime(2024, 4, 3));
    });

    test('an ordinal day is read', () {
      expect(only('1st Jan 2024', dayFirst), DateTime(2024, 1, 1));
      expect(only('22nd Feb 2024', dayFirst), DateTime(2024, 2, 22));
      expect(only('Mar 3rd 2024', dayFirst), DateTime(2024, 3, 3));
    });

    test('names match in any case, and Sept is September', () {
      expect(only('3 APRIL 2024', dayFirst), DateTime(2024, 4, 3));
      expect(only('3 sept 2024', dayFirst), DateTime(2024, 9, 3));
    });

    test('a trailing time is kept', () {
      expect(
        only('3 April 2024 14:30', dayFirst),
        DateTime(2024, 4, 3, 14, 30),
      );
    });

    test('an impossible day stays text', () {
      expect(only('31 April 2024', dayFirst), '31 April 2024');
      expect(only('29 Feb 2023', dayFirst), '29 Feb 2023');
    });

    test('something that only looks like a date stays text', () {
      expect(only('3 Apples 2024', dayFirst), '3 Apples 2024');
      expect(only('May the fourth', dayFirst), 'May the fourth');
    });

    test('the ISO default leaves named months alone', () {
      // Opting into dates beyond ISO is what dateOrder is for.
      expect(only('3 April 2024', iso), '3 April 2024');
    });
  });

  group('Month Names In Another Language', () {
    const french = CsvConfig(
      autoDetect: false,
      parseDates: true,
      dateOrder: CsvDateOrder.dayFirst,
      monthNames: {
        'janvier': 1,
        'fevrier': 2,
        'mars': 3,
        'avril': 4,
        'mai': 5,
        'juin': 6,
        'juillet': 7,
        'aout': 8,
        'septembre': 9,
        'octobre': 10,
        'novembre': 11,
        'decembre': 12,
      },
    );

    test('a supplied name is read', () {
      expect(only('3 avril 2024', french), DateTime(2024, 4, 3));
      expect(only('25 decembre 2024', french), DateTime(2024, 12, 25));
    });

    test('the English names still work alongside them', () {
      expect(only('3 April 2024', french), DateTime(2024, 4, 3));
    });

    test('a supplied name wins over the English one it collides with', () {
      // French mars is March; English would have no claim on it, but this
      // shows the caller's table is consulted first.
      const shifted = CsvConfig(
        autoDetect: false,
        parseDates: true,
        dateOrder: CsvDateOrder.dayFirst,
        monthNames: {'may': 3},
      );
      expect(only('3 may 2024', shifted), DateTime(2024, 3, 3));
      expect(only('3 may 2024', dayFirst), DateTime(2024, 5, 3));
    });

    test('range checking still applies to a supplied name', () {
      expect(only('31 avril 2024', french), '31 avril 2024');
    });

    test('a name that was not supplied stays text', () {
      expect(only('3 aprile 2024', french), '3 aprile 2024');
    });

    test('it does nothing under the ISO default', () {
      const isoFrench = CsvConfig(
        autoDetect: false,
        parseDates: true,
        monthNames: {'avril': 4},
      );
      expect(only('3 avril 2024', isoFrench), '3 avril 2024');
    });

    test('copyWith carries the table', () {
      expect(const CsvConfig().copyWith(monthNames: {'avril': 4}).monthNames, {
        'avril': 4,
      });
      expect(const CsvConfig().monthNames, isEmpty);
    });
  });

  group('Whole Documents', () {
    test('a table of ambiguous dates decodes consistently', () {
      const text = 'when,what\n03/04/2024,ship\n25/12/2024,rest';
      expect(decodeAllPaths(text, dayFirst), [
        ['when', 'what'],
        [DateTime(2024, 4, 3), 'ship'],
        [DateTime(2024, 12, 25), 'rest'],
      ]);
    });

    test('dates and other types coexist in one row', () {
      const text = '03/04/2024,7,1.5,true,plain';
      expect(decodeAllPaths(text, dayFirst), [
        [DateTime(2024, 4, 3), 7, 1.5, true, 'plain'],
      ]);
    });

    test('copyWith carries the order', () {
      expect(
        const CsvConfig().copyWith(dateOrder: CsvDateOrder.dayFirst).dateOrder,
        CsvDateOrder.dayFirst,
      );
      // Omitting it keeps whatever was set.
      expect(
        const CsvConfig(
          dateOrder: CsvDateOrder.monthFirst,
        ).copyWith().dateOrder,
        CsvDateOrder.monthFirst,
      );
    });

    test('the default is ISO only', () {
      expect(const CsvConfig().dateOrder, CsvDateOrder.iso);
    });
  });
}
