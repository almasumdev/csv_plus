/// How to read a numeric date whose field order is ambiguous, such as
/// `03/04/2024`.
///
/// A CSV carries no locale, so `03/04/2024` is the third of April in most of
/// the world and the fourth of March in the United States, and nothing in the
/// file says which. Guessing gets it silently wrong, so csv_plus asks you to
/// say. Set [CsvConfig.dateOrder] alongside [CsvConfig.parseDates].
///
/// ISO-8601 (`2024-01-31`) is never ambiguous and is always recognised,
/// whichever order is selected. Choosing [dayFirst] or [monthFirst] also turns
/// on dates that name their month in English (`3 April 2024`, `Apr 3, 2024`,
/// `03-Apr-2024`); the name fixes the order, so those read the same either way.
///
/// {@category Configuration}
enum CsvDateOrder {
  /// Only ISO-8601 dates are parsed. The default.
  ///
  /// `03/04/2024` stays text, because reading it either way would be a guess.
  iso,

  /// Day before month, so `03/04/2024` is 3 April 2024.
  ///
  /// The common order outside the United States.
  dayFirst,

  /// Month before day, so `03/04/2024` is 4 March 2024.
  ///
  /// The common order in the United States.
  monthFirst,
}
