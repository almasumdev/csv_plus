/// Turns a header row into keys that are safe to put in a map.
///
/// A header row may repeat a name (`amount,amount,total`), and putting such a
/// row straight into a map keeps only the last of the repeats, so every value
/// in the earlier column is silently lost from the keyed views while still
/// being there by position. Repeats are kept apart instead: the first keeps
/// its name and each later one gets a numbered suffix, `amount_2`, `amount_3`,
/// skipping any suffix a real column already uses. A row without repeats
/// comes back unchanged.
List<String> uniqueHeaderKeys(List<String> headers) {
  final seen = <String>{};
  final taken = headers.toSet();
  final keys = <String>[];
  for (final header in headers) {
    if (seen.add(header)) {
      keys.add(header);
      continue;
    }
    var n = 2;
    var key = '${header}_$n';
    while (taken.contains(key) || seen.contains(key)) {
      n++;
      key = '${header}_$n';
    }
    seen.add(key);
    keys.add(key);
  }
  return keys;
}

/// A name-to-index map over [headers], with repeated names kept apart as
/// [uniqueHeaderKeys] describes.
Map<String, int> headerIndexMap(List<String> headers) {
  final keys = uniqueHeaderKeys(headers);
  return {for (var i = 0; i < keys.length; i++) keys[i]: i};
}
