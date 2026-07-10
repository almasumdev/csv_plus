<p align="center">
  <img src="https://raw.githubusercontent.com/Masum-MSNR/csv_plus/main/images/logo.png" width="160" alt="csv_plus logo" />
</p>

<h1 align="center">csv_plus</h1>

<p align="center">
  <strong>The fastest, most complete CSV package for Dart.</strong><br/>
  Encode · Decode · Stream · Query · Transform · Validate
</p>

<p align="center">
  <a href="https://pub.dev/packages/csv_plus"><img src="https://img.shields.io/pub/v/csv_plus.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/points/csv_plus" alt="pub points"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/likes/csv_plus" alt="pub likes"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/popularity/csv_plus" alt="popularity"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
</p>

<p align="center">
  <em>Zero dependencies · Pure Dart · VM, Web & AOT</em>
</p>

---

## Why csv_plus?

Most CSV libraries only do basic parsing. **csv_plus** gives you a complete toolkit: from raw byte-level decoding to full table operations, in a single, zero-dependency package.

| | What you get |
|---|---|
| **Fastest in the ecosystem** | Byte-level (`codeUnits`) parser, fastest on every workload we measure against csv, fast_csv, and serial_csv ([receipts](https://github.com/Masum-MSNR/csv_plus/tree/main/benchmark/compare)) |
| **Type-smart, data-safe** | Auto-infers `int`, `double`, `bool`, `null`; guards keep `007`, `+1`, and 16+ digit IDs as text instead of corrupting them |
| **One parsing semantics** | Batch and streaming decoders produce identical output, enforced by a conformance suite that splits input at every chunk boundary |
| **Stream-ready** | Chunked `StreamTransformer` with real backpressure: constant memory even with a slow consumer |
| **50+ table methods** | Filter, sort, group, aggregate, transform, like a DataFrame for CSV |
| **Schema validation** | Define column types, nullability, patterns, custom validators |
| **dart:convert** | Drop-in `Codec` adapter with `.fuse()` pipeline support |
| **Auto-detection** | Delimiter sniffing, BOM handling, Excel `sep=` hint |
| **Presets built-in** | CSV, TSV, Excel (`;` + BOM), pipe-delimited, one line setup |
| **File I/O** | Read, write, stream, append CSV files with `CsvFile` |
| **Strict or lenient** | `strict: true` throws `CsvParseException` with row/column on malformed quotes; the default recovers like Excel |
| **Flexible parsing** | Lenient mode for messy real-world data: trims whitespace, recovers unmatched quotes |

---

## Installation

```yaml
dependencies:
  csv_plus: ^1.0.0
```

```dart
import 'package:csv_plus/csv_plus.dart';
```

---

## Quick Start

### Encode & Decode

```dart
final codec = CsvCodec();

// Encode
final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);

// Decode: types are automatically inferred
final rows = codec.decode(csv);
// rows[1] == ['Alice', 30, 95.5]  (int and double preserved)
```

### Header-Aware Rows

```dart
final people = codec.decodeWithHeaders(csv);
print(people.first['name']); // Alice
print(people.first['age']);  // 30 (int, not String)
```

### CsvTable: Query & Transform

```dart
final table = CsvTable.parse('name,age,city\nAlice,30,NYC\nBob,25,LA\nEve,35,NYC');

// Filter
final nyc = table.where((row) => row['city'] == 'NYC');

// Sort
table.sortBy('age');

// Aggregate
final avgAge = table.avg('age'); // 30.0

// Group
final byCity = table.groupBy('city'); // {NYC: CsvTable, LA: CsvTable}

// Export
print(table.toCsv());
print(table.toFormattedString()); // Pretty-printed aligned table
```

### Stream Large Files

```dart
import 'package:csv_plus/io.dart';

// Stream: constant memory, any file size
await for (final row in CsvFile.stream('huge.csv')) {
  process(row);
}
```

Any string or byte stream works, with backpressure handled for you:

```dart
final rows = codec.decoder.bindBytes(httpResponse); // Stream<List<int>>
```

---

## Benchmarks

Median of 5 runs, 200k rows x 10 cols (14.3 MB) plain and 100k x 10
quote-heavy (18.4 MB), against csv 8.0.0, fast_csv 0.2.11, and
serial_csv 0.5.2. csv_plus is the fastest on every workload, JIT and
AOT. Times in milliseconds (JIT):

| Workload | csv 8.0.0 | fast_csv | csv_plus |
|---|---|---|---|
| Decode, strings | 178.5 | 120.4 | **105.6** |
| Decode, typed | 235.4 | n/a | **96.2** |
| Decode, quote-heavy | 143.7 | 129.4 | **87.0** |
| Encode, typed rows | 162.1 | n/a | **131.7** |
| decodeWithHeaders | 187.9 | n/a | **96.9** |

The full tables (including AOT and serial_csv), the seeded data
generators, and an edge-case comparison battery live in
[benchmark/compare](https://github.com/Masum-MSNR/csv_plus/tree/main/benchmark/compare).
Run them yourself with `dart run bench.dart`.

---

## Features

### Dual-Path Architecture

csv_plus uses two optimized paths for every operation:

- **Batch path**: `FastEncoder` / `FastDecoder` use `codeUnits` byte arrays, labeled loops, and first-byte type detection for maximum throughput
- **Streaming path**: `CsvEncoder` / `CsvDecoder` implement `StreamTransformer` with a chunked state machine for constant-memory processing

### Automatic Type Inference

Raw CSV strings are parsed into native Dart types automatically:

```dart
final rows = codec.decode('name,age,active\nAlice,30,true');
// rows[0] == ['name', 'age', 'active']  (String)
// rows[1] == ['Alice', 30, true]         (String, int, bool)
```

Inference is guarded against silent data corruption, which most CSV
libraries (including csv 8) get wrong:

- `007`, `+1`, and values with surrounding whitespace stay strings
- digit runs longer than 15 stay strings (exact on VM but not on the
  web, so results are identical on every platform)
- quoted fields are never inferred: `"42"` stays a string
- `1e999` stays a string instead of becoming `Infinity`

Disable with `dynamicTyping: false` to get all strings, or use specialized decoders:

```dart
codec.decodeStrings(csv)   // List<List<String>>
codec.decodeIntegers(csv)  // List<List<int>>, throws CsvParseException on bad cells
codec.decodeDoubles(csv)   // List<List<double>>
codec.decodeBooleans(csv)  // List<List<bool>>: true/false/1/0, case-insensitive
codec.decodeFlexible(csv)  // Lenient: trims whitespace, recovers bad quotes
```

The typed decoders never invent data: a non-numeric or empty cell
throws a `CsvParseException` with the row and column, unless you pass
an explicit fill like `decodeIntegers(csv, emptyAs: 0)`.

### Configuration & Presets

```dart
final codec = CsvCodec();            // Standard CSV (auto-detect on)
final excel = CsvCodec.excel();       // Semicolons + BOM for Excel
final tsv = CsvCodec.tsv();           // Tab-separated
final pipe = CsvCodec.pipe();         // Pipe-separated

// Or customize fully
final custom = CsvCodec(CsvConfig(
  fieldDelimiter: '::',
  quoteMode: QuoteMode.always,
  skipEmptyLines: true,
  strict: true, // throw on malformed quotes instead of recovering
));
```

### Schema Validation

```dart
final schema = CsvSchema(columns: [
  CsvColumnDef(name: 'email', type: String, required: true, pattern: r'@'),
  CsvColumnDef(name: 'age', type: int, nullable: false),
]);

final errors = table.validate(schema);
final isValid = table.conformsTo(schema);
```

### dart:convert Integration

```dart
final adapter = codec.asCodec();    // Codec<List<List<dynamic>>, String>
final rows = adapter.decode(csv);

// Fuse with other codecs
final pipeline = adapter.fuse(utf8);
```

---

## API Overview

### CsvCodec: Main Facade

| Decode | Encode |
|--------|--------|
| `decode()`: typed rows | `encode()`: mixed types |
| `decodeWithHeaders()`: `CsvRow` list | `encodeStrings()`: string-only |
| `decodeStrings()`: all strings | `encodeGeneric<T>()`: uniform type |
| `decodeToTable()`: `CsvTable` | `encodeMap()`: map to 2-col CSV |
| `decodeMap()`: 2-col to map | |
| `decodeFlexible()`: lenient mode | |

### CsvTable: 50+ Methods

| Category | Methods |
|----------|---------|
| **Access** | `cell()`, `cellByName()`, `column()`, `rows`, `first`, `last` |
| **Rows** | `addRow()`, `addRowFromMap()`, `insertRow()`, `removeRow()`, `removeWhere()` |
| **Columns** | `addColumn()`, `insertColumn()`, `removeColumn()`, `renameColumn()`, `reorderColumns()` |
| **Query** | `where()`, `firstWhere()`, `any()`, `every()`, `distinct()`, `range()`, `take()`, `skip()` |
| **Sort** | `sortBy()`, `sortByIndex()`, `sortByMultiple()`, `sort()`, `sortedBy()` (all stable) |
| **Aggregate** | `sum()`, `avg()`, `min()`, `max()`, `count()`, `groupBy()` |
| **Transform** | `transformColumn()`, `map()`, `fold()` |
| **Export** | `toCsv()`, `toMaps()`, `toList()`, `toFormattedString()`, `copy()` |
| **Validate** | `validate()`, `conformsTo()`, `inferSchema()` |

### CsvFile: File I/O

| Method | Description |
|--------|-------------|
| `read()` / `readSync()` | file to `CsvTable` |
| `write()` / `writeSync()` | `CsvTable` to file |
| `stream()` | Row-by-row streaming (constant memory) |
| `writeStream()` | stream to file |
| `append()` | Append rows to existing file |

---

## Modular Imports

Import everything with one line, or pick only what you need:

```dart
import 'package:csv_plus/csv_plus.dart';     // Everything
import 'package:csv_plus/codec.dart';         // Just CsvCodec
import 'package:csv_plus/table.dart';         // Just CsvTable
import 'package:csv_plus/io.dart';            // File I/O (dart:io)
```

---

## Platform Support

| Platform | Status |
|----------|--------|
| Dart VM | ✅ Full support |
| Flutter | ✅ Full support |
| Web (dart2js / WASM) | ✅ Core (no `CsvFile`) |
| AOT compiled | ✅ Full support |

> `dart:io` is isolated in `io.dart`: core encode/decode/table works everywhere.

---

## Additional Information

- **Documentation**: [API Reference](https://pub.dev/documentation/csv_plus/latest/)
- **Issues**: [Report a bug](https://github.com/Masum-MSNR/csv_plus/issues)
- **Changelog**: See [CHANGELOG.md](CHANGELOG.md) for version history

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License; see [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/Masum-MSNR">Masum</a>
</p>
