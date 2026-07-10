import 'package:csv_plus/csv_plus.dart';
import 'package:test/test.dart';

void main() {
  group('CsvCodecAdapter', () {
    test('decode via adapter', () {
      final adapter = CsvCodecAdapter();
      final rows = adapter.decode('a,b\n1,2');
      expect(rows, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('encode via adapter', () {
      final adapter = CsvCodecAdapter();
      final csv = adapter.encode([
        ['a', 'b'],
        [1, 2],
      ]);
      expect(csv, 'a,b\r\n1,2');
    });

    test('round-trip', () {
      final adapter = CsvCodecAdapter(const CsvConfig(dynamicTyping: false));
      final original = [
        ['name', 'age'],
        ['Alice', '30'],
      ];
      final csv = adapter.encode(original);
      final decoded = adapter.decode(csv);
      expect(decoded, original);
    });

    test('with custom config', () {
      final adapter = CsvCodecAdapter(const CsvConfig(
        fieldDelimiter: ';',
        dynamicTyping: false,
      ));
      final csv = adapter.encode([
        ['a', 'b'],
      ]);
      expect(csv, 'a;b');
    });
  });

  group('CsvCodec extended', () {
    test('decodeToTable', () {
      const codec = CsvCodec();
      final table = codec.decodeToTable('name,age\nAlice,30');
      expect(table.headers, ['name', 'age']);
      expect(table.rowCount, 1);
    });

    test('decoder getter returns CsvDecoder', () {
      const codec = CsvCodec();
      expect(codec.decoder, isA<CsvDecoder>());
    });

    test('encoder getter returns CsvEncoder', () {
      const codec = CsvCodec();
      expect(codec.encoder, isA<CsvEncoder>());
    });

    test('asCodec returns CsvCodecAdapter', () {
      const codec = CsvCodec();
      final adapter = codec.asCodec();
      expect(adapter, isA<CsvCodecAdapter>());
    });

    test('streaming decode via codec.decoder', () async {
      const codec = CsvCodec();
      final stream = Stream.fromIterable(['a,b\n', '1,2']);
      final rows = await codec.decoder.bind(stream).toList();
      expect(rows, [
        ['a', 'b'],
        [1, 2],
      ]);
    });

    test('streaming encode via codec.encoder', () async {
      const codec = CsvCodec();
      final stream = Stream.fromIterable([
        ['a', 'b'],
        [1, 2],
      ]);
      final chunks = await codec.encoder.bind(stream).toList();
      expect(chunks.join(), 'a,b\r\n1,2');
    });
  });
}
