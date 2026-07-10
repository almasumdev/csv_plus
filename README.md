<p align="center">
  <img src="https://raw.githubusercontent.com/almasumdev/csv_plus/main/images/logo.png"
       alt="csv_plus: a fast, complete CSV parser and encoder for Dart and Flutter" width="180"/>
</p>

<p align="center">
  <a href="https://pub.dev/packages/csv_plus"><img src="https://img.shields.io/pub/v/csv_plus.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/csv_plus/score"><img src="https://img.shields.io/pub/points/csv_plus" alt="pub points"></a>
  <a href="https://pub.dev/packages/csv_plus"><img src="https://img.shields.io/pub/likes/csv_plus" alt="pub likes"></a>
  <a href="https://github.com/almasumdev/csv_plus/stargazers"><img src="https://badgen.net/github/stars/almasumdev/csv_plus?icon=github" alt="GitHub stars"></a>
  <a href="https://github.com/almasumdev/csv_plus/network/members"><img src="https://badgen.net/github/forks/almasumdev/csv_plus?icon=github" alt="GitHub forks"></a>
  <a href="https://github.com/almasumdev/csv_plus/issues"><img src="https://badgen.net/github/open-issues/almasumdev/csv_plus?icon=github" alt="GitHub issues"></a>
  <a href="https://github.com/almasumdev/csv_plus/actions/workflows/ci.yml"><img src="https://github.com/almasumdev/csv_plus/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
  <a href="https://github.com/almasumdev/csv_plus/commits/main"><img src="https://badgen.net/github/last-commit/almasumdev/csv_plus?icon=github" alt="Last commit"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.8+-0175C2?logo=dart" alt="Dart"></a>
</p>

# CSV Library for Dart & Flutter

**csv_plus** is a fast, complete, zero-dependency Dart library for **parsing,
encoding, streaming, querying, and validating CSV data**. It works in plain Dart
and in Flutter apps, on the VM, Web (JS & WASM), and mobile. csv_plus reads and
writes RFC 4180 CSV with automatic type inference, a DataFrame-style table layer,
schema validation, and constant-memory streaming, and it is the **fastest
general-purpose CSV package for Dart** on every workload we measure.

> ⭐ **Find this useful?** [Star it on GitHub](https://github.com/almasumdev/csv_plus)
> and 👍 [like it on pub.dev](https://pub.dev/packages/csv_plus). Stars and likes
> help other Dart & Flutter developers find a maintained, full-featured CSV library.

## Overview

csv_plus parses and generates comma-separated-values (CSV) text, along with
tab-separated (TSV), pipe-delimited, and custom-delimiter formats. It decodes CSV
into typed Dart values, encodes rows back to RFC 4180 output with correct quoting,
streams large files with constant memory, and offers a table layer for filtering,
sorting, grouping, aggregating, and validating tabular data.

**What you can do with it:**

- Decode CSV strings and files into typed rows (`int`, `double`, `bool`, `String`, `null`), or into a queryable table.
- Encode rows, maps, and tables back to CSV, TSV, pipe-delimited, or Excel-flavored output with automatic quoting.
- Stream very large CSV files row by row with a chunked, backpressure-aware transformer that never buffers the whole input.
- Query, sort, group, aggregate, transform, and schema-validate tabular data with a DataFrame-style API.

## Performance

csv_plus is built for throughput: a byte-level (`codeUnits`) batch parser with no
regex and no string allocation in the hot loop, first-byte type detection, and a
per-call `StringBuffer` encoder. Type inference is guarded so speed never costs
correctness.

It is the fastest general-purpose CSV package for Dart on every workload, on both
JIT and AOT. The numbers below are a median of 5 runs against
[`csv`](https://pub.dev/packages/csv) 8.0.0 and
[`fast_csv`](https://pub.dev/packages/fast_csv) 0.2.11, on 200k rows x 10 cols
plain (14.3 MB) and 100k x 10 quote-heavy (18.4 MB), on the same machine:

| Workload (JIT) | csv 8.0.0 | fast_csv | csv_plus |
|---|---|---|---|
| Decode, strings | 178.5 ms | 120.4 ms | **105.6 ms** |
| Decode, typed | 235.4 ms | n/a | **96.2 ms** |
| Decode, quote-heavy | 143.7 ms | 129.4 ms | **87.0 ms** |
| Encode, typed rows | 162.1 ms | n/a | **131.7 ms** |
| decodeWithHeaders | 187.9 ms | n/a | **96.9 ms** |

The full tables (AOT included, plus serial_csv), the seeded data generators, and
an edge-case comparison battery live in
[`benchmark/compare/`](https://github.com/almasumdev/csv_plus/tree/main/benchmark/compare).
Timings vary by hardware, so reproduce them on your own machine:

```sh
cd benchmark/compare && dart pub get && dart run bench.dart
```

## Table of contents

- [Key features](#key-features)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [Error handling](#error-handling)
- [Example](#example)
- [Other useful links](#other-useful-links)
- [Installation](#installation)
- [Getting started](#getting-started)
  - [Encode and decode](#encode-and-decode)
  - [Header-aware rows](#header-aware-rows)
  - [Type inference and typed decoders](#type-inference-and-typed-decoders)
  - [Query and transform with CsvTable](#query-and-transform-with-csvtable)
  - [Aggregate and group](#aggregate-and-group)
  - [Stream large files](#stream-large-files)
  - [Read and write files](#read-and-write-files)
  - [Configuration and presets](#configuration-and-presets)
  - [Strict mode](#strict-mode)
  - [Schema validation](#schema-validation)
  - [Maps and two-column CSV](#maps-and-two-column-csv)
  - [dart:convert integration](#dartconvert-integration)
- [csv_plus vs csv](#csv_plus-vs-csv)
- [FAQ](#faq)
- [Support and feedback](#support-and-feedback)
- [About](#about)

## Key features

Everything you need to read, write, stream, and analyze CSV, on every Dart &
Flutter platform.

<details>
<summary><b>📥 Decoding</b></summary>

- Typed decode with automatic `int` / `double` / `bool` / `null` / `String` inference
- Data-loss guards: `007`, `+1`, whitespace, and 16+ digit ids stay text; quoted fields are never inferred
- String-only, integer, double, and boolean decoders that throw on bad input instead of inventing values
- Lenient (`decodeFlexible`) mode: trims whitespace and recovers unmatched quotes
- Header-aware rows (`CsvRow`) with `row['name']` and `row[0]` access
- Delimiter auto-detection, BOM handling, and the Excel `sep=` hint

</details>

<details>
<summary><b>📤 Encoding</b></summary>

- RFC 4180 output with automatic, correct quoting
- Three quote modes: only-when-necessary, always, and strings-only
- Encode rows, maps, uniform-typed grids, and tables
- Custom delimiter, quote, escape, and line-ending configuration
- Optional UTF-8 BOM for Excel compatibility

</details>

<details>
<summary><b>🌊 Streaming</b></summary>

- Chunked `StreamTransformer` for constant-memory decode and encode
- Real backpressure: a slow consumer never buffers the whole file
- Correct across chunk boundaries that split mid-field, mid-escape, mid-CRLF, or mid-delimiter
- `bindBytes` decodes and encodes UTF-8 byte streams directly

</details>

<details>
<summary><b>📊 Table, query & transform</b></summary>

- `CsvTable`: a 2D structure with headers, 50+ methods
- Filter, sort (stable), take, skip, distinct, and range
- Aggregate: sum, avg, min, max, count, and groupBy
- Add, remove, rename, reorder, and transform columns
- Schema validation: column types, nullability, patterns, and custom validators

</details>

<details>
<summary><b>🛡️ Reliability & platform</b></summary>

- One documented parsing semantics across batch and streaming, enforced by a conformance suite
- Optional `strict` mode: throws `CsvParseException` with row and column on malformed input
- Typed exceptions: `CsvException` and subtypes
- Zero dependencies, pure Dart: VM, Web (`dart2js` + `wasm`), and Flutter mobile
- `dart:io` isolated behind a separate import so the core works everywhere

</details>

## Limitations

- ❌ Comment-line skipping (`#`-prefixed rows)
- ❌ Row windowing (`skipRows` / `maxRows`)
- ❌ Per-column type coercion on decode (schemas validate, they do not coerce)

## Roadmap

What ships next is driven by user requests on the
[issue tracker](https://github.com/almasumdev/csv_plus/issues):

- ⬜ Comment-line skipping (`#`-prefixed rows)
- ⬜ Row windowing (`skipRows` / `maxRows`)
- ⬜ Per-column type coercion driven by `CsvSchema`

Shipped milestones are in the
[changelog](https://github.com/almasumdev/csv_plus/blob/main/CHANGELOG.md).

## Error handling

Malformed-but-openable CSV degrades gracefully by default: text after a closing
quote is appended to the field (Excel behavior), and an unterminated quote
consumes the rest of the input. Pass `strict: true` to turn those into a typed,
catchable [`CsvParseException`](https://pub.dev/documentation/csv_plus/latest/)
that carries the `row`, `column`, and `offset`:

```dart
try {
  final rows = CsvCodec(CsvConfig(strict: true)).decode('"a"x,b');
} on CsvParseException catch (e) {
  print('Parse error at row ${e.row}, column ${e.column}: ${e.message}');
}
```

The typed decoders (`decodeIntegers`, `decodeDoubles`, `decodeBooleans`) throw
`CsvParseException` on a cell they cannot convert rather than inventing a `0` or
`false`. Schema violations throw `CsvValidationException`.

## Example

A complete, runnable set of samples lives in the
[`example/`](https://github.com/almasumdev/csv_plus/tree/main/example) directory
(basic, table, streaming, file IO, and advanced). Clone the repository and run
them, or copy any snippet from [Getting started](#getting-started) below.

## Other useful links

- [API reference](https://pub.dev/documentation/csv_plus/latest/)
- [Source code on GitHub](https://github.com/almasumdev/csv_plus)
- [Changelog](https://github.com/almasumdev/csv_plus/blob/main/CHANGELOG.md)
- [Issue tracker](https://github.com/almasumdev/csv_plus/issues)

## Installation

```bash
dart pub add csv_plus
# or, in a Flutter app:
flutter pub add csv_plus
```

Then import it:

```dart
import 'package:csv_plus/csv_plus.dart';
```

## Getting started

### Encode and decode

```dart
final codec = CsvCodec();

// Encode.
final csv = codec.encode([
  ['name', 'age', 'score'],
  ['Alice', 30, 95.5],
  ['Bob', 25, 88.0],
]);

// Decode: types are inferred automatically.
final rows = codec.decode(csv);
// rows[1] == ['Alice', 30, 95.5]  (String, int, double)
```

### Header-aware rows

```dart
final people = codec.decodeWithHeaders(csv);
print(people.first['name']); // Alice
print(people.first['age']);  // 30  (int, not String)
```

### Type inference and typed decoders

```dart
// Inference is guarded so identifier-like data is not corrupted.
codec.decode('id,qty\n007,3');
// ['id', 'qty'], ['007', 3]  (007 stays a String; 3 becomes an int)

// Or force a whole grid to one type. These throw on a bad cell instead of
// inventing a value; pass emptyAs to fill blanks.
codec.decodeStrings(csv);            // List<List<String>>
codec.decodeIntegers('1,2\n3,4');    // List<List<int>>
codec.decodeDoubles('1.5,2.5');      // List<List<double>>
codec.decodeBooleans('true,0');      // List<List<bool>>  (true/false/1/0)
codec.decodeFlexible('  a , b ');    // lenient: trims, recovers bad quotes
```

### Query and transform with CsvTable

```dart
final table = CsvTable.parse('name,age,city\nAlice,30,NYC\nBob,25,LA\nEve,35,NYC');

// Filter (returns a new table).
final adults = table.where((row) => (row['age'] as int) >= 30);

// Sort in place (stable).
table.sortBy('age');

// ...or get a sorted copy without touching the source.
final byAge = table.sortedBy('age');

// Export.
print(table.toCsv());
print(table.toFormattedString()); // pretty-printed aligned table
```

### Aggregate and group

```dart
print(table.avg('age'));   // 30.0
print(table.sum('age'));   // 90
print(table.max('age'));   // 35

// Group rows by a column value into sub-tables.
final byCity = table.groupBy('city'); // {NYC: CsvTable, LA: CsvTable}
```

### Stream large files

```dart
import 'package:csv_plus/io.dart';

// Constant memory, any file size.
await for (final row in CsvFile.stream('huge.csv')) {
  process(row);
}
```

Any string or byte stream works, with backpressure handled for you:

```dart
final rows = codec.decoder.bindBytes(byteStream); // Stream<List<int>>
```

### Read and write files

```dart
import 'package:csv_plus/io.dart';

final table = await CsvFile.read('data.csv');
await CsvFile.write('out.csv', table);
await CsvFile.append('out.csv', [['Zoe', 41]]);
```

### Configuration and presets

```dart
final excel = CsvCodec.excel(); // ';' delimiter + UTF-8 BOM
final tsv = CsvCodec.tsv();      // tab-separated
final pipe = CsvCodec.pipe();    // pipe-separated

// Or configure fully.
final custom = CsvCodec(CsvConfig(
  fieldDelimiter: '::',
  quoteMode: QuoteMode.always,
  skipEmptyLines: true,
));
```

### Strict mode

```dart
// Throw on structurally malformed input instead of recovering.
final strict = CsvCodec(CsvConfig(strict: true));
strict.decode('"unterminated'); // throws CsvParseException
```

### Schema validation

```dart
final schema = CsvSchema(columns: [
  CsvColumnDef(name: 'email', type: String, required: true, pattern: r'@'),
  CsvColumnDef(name: 'age', type: int, nullable: false),
]);

final errors = table.validate(schema);   // List<CsvValidationException>
final ok = table.conformsTo(schema);      // bool
```

### Maps and two-column CSV

```dart
codec.encodeMap({'host': 'localhost', 'port': 8080});
codec.decodeMap('host,localhost\nport,8080'); // {host: localhost, port: 8080}
```

### dart:convert integration

```dart
final adapter = codec.asCodec(); // Codec<List<List<dynamic>>, String>
final rows = adapter.decode('a,b\n1,2');
final piped = adapter.fuse(utf8); // fuse with other codecs
```

## csv_plus vs csv

csv_plus and the [`csv`](https://pub.dev/packages/csv) package cover similar
ground; csv_plus adds speed, a table layer, and stricter correctness.

| | csv_plus | csv |
|---|---|---|
| Decode speed (typed, JIT) | **96 ms** | 235 ms |
| Parsing semantics | **One truth across batch & streaming**, conformance-tested | Batch and streaming |
| Type inference | **Guarded** (`007`, `+1`, big ids stay text) | Coerces (may corrupt ids) |
| Table / query / schema layer | **Yes** | No |
| Streaming backpressure | **Yes** | Basic |
| Dependencies | **Zero** | Zero |

Numbers are from the reproducible [benchmark](#performance) above.

## FAQ

**Is csv_plus a drop-in for the `csv` package?**
No, the APIs differ, but the concepts map directly (codec, typed decode, headers,
streaming). Most migrations are a small, mechanical change.

**Which platforms are supported?**
Dart VM, Web (both JavaScript and WebAssembly), and mobile (Android & iOS) via
Flutter, plus desktop. It is pure Dart with no `dart:io` in the core path.

**Does it handle large files without running out of memory?**
Yes. The streaming decoder and encoder process input in chunks with real
backpressure, so memory stays constant regardless of file size.

**Will type inference corrupt my ids or codes?**
No. Values with leading zeros, a leading plus, surrounding whitespace, or more
than 15 digits stay strings, and quoted fields are never inferred, on every
platform including the web.

**Does it support TSV, pipe-delimited, and Excel CSV?**
Yes, via `CsvCodec.tsv()`, `CsvCodec.pipe()`, `CsvCodec.excel()`, or a custom
`CsvConfig` with any single or multi-character delimiter.

## Support and feedback

- Found a bug or want a feature? Open an issue on the
  [issue tracker](https://github.com/almasumdev/csv_plus/issues).
- Questions and ideas are welcome via
  [GitHub Discussions](https://github.com/almasumdev/csv_plus/discussions).
- Pull requests are welcome; see the repository for contribution guidelines.

## About

csv_plus is an open-source, MIT-licensed, zero-dependency CSV library for Dart and
Flutter, built around a byte-level parser and a chunked streaming transformer for
speed and low memory on large files.

csv_plus is created and owned by **Nurullah Al Masum**.

### Contributors

csv_plus grows with its community; every contributor is listed here:

<a href="https://github.com/almasumdev/csv_plus/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=almasumdev/csv_plus" alt="csv_plus contributors"/>
</a>

Want to help? Pull requests are welcome; see [Support and feedback](#support-and-feedback).
