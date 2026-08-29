import 'dart:convert';
import 'dart:typed_data';

import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('Byte Decoding', () {
    const codec = CsvCodec();

    test('decodes the bytes a file picker hands you', () {
      final bytes = utf8.encode('name,qty\nbolt,4\n');
      expect(codec.decodeBytes(bytes), [
        ['name', 'qty'],
        ['bolt', 4],
      ]);
    });

    test('strips a byte order mark instead of gluing it to the first key', () {
      final bytes = utf8.encode('\u{FEFF}name,qty\nbolt,4\n');
      expect(codec.decodeBytes(bytes).first.first, 'name');
    });

    test('applies the sep= hint and delimiter detection to bytes as well', () {
      expect(codec.decodeBytes(utf8.encode('sep=;\na;b\n1;2\n')), [
        ['a', 'b'],
        [1, 2],
      ]);
      expect(codec.decodeBytes(utf8.encode('a;b\n1;2\n')), [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('reads headers, a table and maps straight from bytes', () {
      final bytes = utf8.encode('name,qty\nbolt,4\n');
      expect(codec.decodeBytesWithHeaders(bytes).single['name'], 'bolt');
      expect(codec.decodeBytesToTable(bytes).headers, ['name', 'qty']);
      expect(codec.decodeBytesToMaps(bytes), [
        {'name': 'bolt', 'qty': 4},
      ]);
    });

    test('an empty byte list decodes to no rows', () {
      expect(codec.decodeBytes(Uint8List(0)), isEmpty);
    });

    test('a malformed byte does not throw away the rest of the file', () {
      final bytes = <int>[
        ...utf8.encode('a,b\n'),
        0xFF,
        ...utf8.encode(',c\n'),
      ];
      expect(codec.decodeBytes(bytes).length, 2);
    });
  });

  group('Byte Encoding', () {
    test('encodeToBytes round-trips through decodeBytes', () {
      const codec = CsvCodec();
      final rows = [
        ['name', 'note'],
        ['bolt', 'a, b'],
        ['nut', 'says "hi"'],
      ];
      expect(codec.decodeBytes(codec.encodeToBytes(rows)), rows);
    });

    test('addBom puts the byte order mark Excel needs at the front', () {
      const codec = CsvCodec(CsvConfig(addBom: true));
      final bytes = codec.encodeToBytes([
        ['a', 'b'],
      ]);
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    });

    test('without addBom the output starts at the data', () {
      const codec = CsvCodec();
      final bytes = codec.encodeToBytes([
        ['a', 'b'],
      ]);
      expect(bytes.first, 'a'.codeUnitAt(0));
    });
  });

  group('Character Sets', () {
    const codec = CsvCodec();

    test('Windows-1252 reads the characters Latin-1 leaves as controls', () {
      final text = CsvCharset.windows1252.decodeBytes(<int>[
        0x80,
        0x93,
        0x94,
        0x96,
      ]);
      expect(text, '\u{20AC}\u{201C}\u{201D}\u{2013}');
    });

    test('a Latin-1 accented name survives a decode UTF-8 would mangle', () {
      final bytes = <int>[...'name\n'.codeUnits, 0x4A, 0x6F, 0x73, 0xE9];
      expect(codec.decodeBytes(bytes, charset: CsvCharset.latin1), [
        ['name'],
        ['Jos\u{E9}'],
      ]);
      // The same bytes read as UTF-8 replace the bad byte rather than throwing.
      expect(() => codec.decodeBytes(bytes), returnsNormally);
    });

    test('every Windows-1252 byte maps to exactly one character', () {
      final all = List<int>.generate(256, (i) => i);
      expect(CsvCharset.windows1252.decodeBytes(all).length, 256);
    });

    test('Windows-1252 matches Latin-1 outside the 0x80 to 0x9F window', () {
      final low = List<int>.generate(0x80, (i) => i);
      expect(
        CsvCharset.windows1252.decodeBytes(low),
        CsvCharset.latin1.decodeBytes(low),
      );
      final high = List<int>.generate(0x60, (i) => 0xA0 + i);
      expect(
        CsvCharset.windows1252.decodeBytes(high),
        CsvCharset.latin1.decodeBytes(high),
      );
    });

    test('a byte order mark on a single byte file stays out of column one', () {
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...'name\nJose\n'.codeUnits];
      expect(
        codec.decodeBytes(bytes, charset: CsvCharset.windows1252).first.first,
        'name',
      );
    });

    test('a semicolon Excel export in Windows-1252 decodes end to end', () {
      final bytes = <int>[
        ...'name;price\n'.codeUnits,
        0x4A, 0x6F, 0x73, 0xE9, // Jose with an acute e
        0x3B, // ;
        0x80, // euro sign
        0x35, // 5
        0x0A,
      ];
      expect(codec.decodeBytes(bytes, charset: CsvCharset.windows1252), [
        ['name', 'price'],
        ['Jos\u{E9}', '\u{20AC}5'],
      ]);
    });
  });
}
