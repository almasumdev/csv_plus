import 'dart:typed_data';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

/// [text] as UTF-16 bytes, with a byte order mark unless [mark] is false.
Uint8List _utf16(String text, {bool lowFirst = true, bool mark = true}) {
  final bytes = <int>[
    if (mark) ...(lowFirst ? [0xFF, 0xFE] : [0xFE, 0xFF]),
  ];
  for (final unit in text.codeUnits) {
    if (lowFirst) {
      bytes
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    } else {
      bytes
        ..add(unit >> 8)
        ..add(unit & 0xFF);
    }
  }
  return Uint8List.fromList(bytes);
}

void main() {
  const tabs = CsvCodec(CsvConfig(autoDetect: false, fieldDelimiter: '\t'));

  group('UTF-16 Files', () {
    test('a file with a byte order mark reads under the default charset', () {
      // Read as UTF-8 this was garbage, the mark included.
      expect(tabs.decodeBytes(_utf16('name\tage\nJosé\t30')), [
        ['name', 'age'],
        ['José', 30],
      ]);
    });

    test('the high-byte-first order reads too', () {
      expect(tabs.decodeBytes(_utf16('a\tb', lowFirst: false)), [
        ['a', 'b'],
      ]);
    });

    test('the mark beats the charset asked for', () {
      final bytes = _utf16('a\tb');
      for (final charset in CsvCharset.values) {
        expect(tabs.decodeBytes(bytes, charset: charset), [
          ['a', 'b'],
        ], reason: charset.name);
      }
    });

    test('a file with no mark reads when the charset is named', () {
      expect(
        tabs.decodeBytes(
          _utf16('a\tb', mark: false),
          charset: CsvCharset.utf16le,
        ),
        [
          ['a', 'b'],
        ],
      );
      expect(
        tabs.decodeBytes(
          _utf16('a\tb', lowFirst: false, mark: false),
          charset: CsvCharset.utf16be,
        ),
        [
          ['a', 'b'],
        ],
      );
    });

    test('characters outside the basic plane survive', () {
      expect(tabs.decodeBytes(_utf16('😀\tx')), [
        ['😀', 'x'],
      ]);
    });

    test('the delimiter is detected from the decoded text', () {
      // This is the shape of Excel's "Unicode Text" export.
      expect(const CsvCodec().decodeBytes(_utf16('a\tb\tc\n1\t2\t3')), [
        ['a', 'b', 'c'],
        [1, 2, 3],
      ]);
    });

    test('the header-aware paths read it as well', () {
      final bytes = _utf16('name\tage\nJosé\t30');
      const codec = CsvCodec(
        CsvConfig(autoDetect: false, fieldDelimiter: '\t', hasHeader: true),
      );
      expect(codec.decodeBytesToMaps(bytes), [
        {'name': 'José', 'age': 30},
      ]);
    });

    test('a stray final byte is dropped rather than thrown over', () {
      final bytes = Uint8List.fromList([..._utf16('a\tb'), 0x41]);
      expect(tabs.decodeBytes(bytes), [
        ['a', 'b'],
      ]);
    });

    test('an empty file with only a mark is empty', () {
      expect(tabs.decodeBytes(_utf16('')), isEmpty);
    });
  });

  group('Other Charsets', () {
    test('plain UTF-8 and Windows-1252 read as before', () {
      expect(tabs.decodeBytes([0xC3, 0xA9]), [
        ['é'],
      ]);
      expect(tabs.decodeBytes([0x80], charset: CsvCharset.windows1252), [
        ['€'],
      ]);
    });
  });
}
