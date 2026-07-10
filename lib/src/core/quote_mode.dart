/// When to quote fields during CSV encoding.
///
/// Null handling: [necessary] and [strings] write `null` as an empty
/// unquoted field, which typed decoding reads back as `null`; [always]
/// writes `null` as `""`. Under [necessary], an empty string is quoted
/// (`""`) so that `''` and `null` survive a round-trip as different
/// values.
enum QuoteMode {
  /// Quote only when field contains delimiter, newline, quote char,
  /// or has leading/trailing spaces. Empty strings are quoted to stay
  /// distinguishable from null.
  necessary,

  /// Quote every field unconditionally (null becomes `""`).
  always,

  /// Quote only fields of type [String]. Numbers, bools, null remain
  /// unquoted.
  strings,
}
