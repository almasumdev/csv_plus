import 'dart:convert';
import 'dart:typed_data';

/// Character encoding used when decoding CSV bytes into text.
///
/// CSV files produced by spreadsheet software on Windows are frequently not
/// UTF-8. Passing the wrong encoding to a UTF-8 decoder either throws or
/// replaces bytes with U+FFFD, so the encoding has to be chosen explicitly
/// when the file is not UTF-8.
enum CsvCharset {
  /// UTF-8, with a leading byte order mark tolerated and stripped.
  ///
  /// Malformed sequences are replaced rather than thrown, so one bad byte
  /// does not lose the whole file.
  utf8,

  /// ISO-8859-1, also called Latin-1. Every byte maps to the code point of
  /// the same value.
  latin1,

  /// Windows-1252, the default single byte encoding of Western European
  /// Windows and the usual output of Excel's "CSV (Comma delimited)" export.
  ///
  /// It matches [latin1] except in the 32 slots from 0x80 to 0x9F, which hold
  /// printable characters such as the euro sign and curly quotes instead of
  /// control codes.
  windows1252;

  /// Decode [bytes] to a string using this encoding.
  ///
  /// A leading UTF-8 byte order mark is skipped for the single byte encodings
  /// too. Those three bytes are never meaningful leading CSV content, and
  /// reading them as Latin-1 would otherwise glue a visible prefix onto the
  /// first column name.
  String decodeBytes(List<int> bytes) {
    switch (this) {
      case CsvCharset.utf8:
        return const Utf8Decoder(allowMalformed: true).convert(bytes);
      case CsvCharset.latin1:
        return const Latin1Decoder(
          allowInvalid: true,
        ).convert(_skipUtf8Bom(bytes));
      case CsvCharset.windows1252:
        return _decodeWindows1252(_skipUtf8Bom(bytes));
    }
  }
}

/// Code points for the 32 Windows-1252 bytes from 0x80 to 0x9F that differ
/// from Latin-1. The five slots Windows-1252 leaves undefined (0x81, 0x8D,
/// 0x8F, 0x90, 0x9D) keep their own value, which is what the WHATWG encoding
/// standard specifies.
const List<int> _cp1252High = <int>[
  0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
  0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, //
  0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
  0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178, //
];

/// Drop a leading UTF-8 byte order mark (EF BB BF) if the input carries one.
List<int> _skipUtf8Bom(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return bytes.sublist(3);
  }
  return bytes;
}

String _decodeWindows1252(List<int> bytes) {
  final out = Uint16List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i] & 0xFF;
    out[i] = (b >= 0x80 && b <= 0x9F) ? _cp1252High[b - 0x80] : b;
  }
  return String.fromCharCodes(out);
}
