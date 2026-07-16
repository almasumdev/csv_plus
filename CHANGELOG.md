## 1.1.0

Comment-line skipping, row windowing, and a header-keyed map decode. All
additions are backward-compatible: existing calls behave exactly as before.

### New

- `CsvConfig(comment: '#')` drops comment lines while decoding. The marker is
  matched only at the very start of a line, so a `#` inside a quoted field or
  mid-field is ordinary content. The marker is a single character; comment
  lines never count toward `skipRows`.
- `CsvConfig(skipRows: n)` skips leading rows before the header row is read,
  for a preamble sitting above the real table.
- `CsvConfig(maxRows: n)` caps the number of data rows returned (the header is
  not counted); the batch decoders stop reading once the limit is reached and
  the streaming decoder stops emitting.
- `CsvCodec.decodeToMaps` decodes straight to a `List<Map<String, dynamic>>`
  keyed by header name, a shortcut for `decodeToTable(input).toMaps()`.

All three config options apply across every decode path (`decode`,
`decodeStrings`, `decodeFlexible`, the typed decoders, `decodeToTable`,
`decodeToMaps`, and the streaming `CsvDecoder`), and are held to identical
output by the conformance suite that splits input at every chunk boundary.

## 1.0.1

Documentation and metadata only; no library or API changes.

- Reworked the README (clearer structure, added the logo screenshot, and
  broader keyword coverage) and refined the pub.dev topics for discoverability.
- Switched the head-to-head benchmark to compare against serial_csv in place
  of fast_csv.

## 1.0.0

First stable release: one documented parsing semantics across every
decode path, streaming you can trust, data-loss guards on type
inference, and public benchmark receipts. The API is now frozen under
semantic versioning.

### One parsing semantics (breaking behavior alignments)

The batch decoder, string decoder, and streaming decoder previously
disagreed on edge cases. All paths now produce identical output,
enforced by a conformance suite that also splits input at every chunk
boundary (`test/conformance_test.dart`).

- An empty line reads as a row with one empty field (`['']`, or `[null]`
  with typing), per RFC 4180 and matching csv 8 and fast_csv. With
  `skipEmptyLines` (default), rows of a single empty field are dropped;
  rows of several empty fields (`,,`) are now always kept (previously
  `decodeStrings` dropped them).
- Text after a closing quote is appended to the field, so `"a"x` reads
  `ax` (Excel behavior). Previously the batch decoder produced an extra
  cell and the streaming decoder swallowed the following delimiter.
- With `hasHeader`, the header row is read as raw strings on every
  path: a header cell `01` stays `01` (previously typed then
  stringified to `1`), and `decoderTransform` is not applied to it.
- Quoted fields are never type-inferred on any path.

### Type inference guards (data safety)

`FastDecoder.inferType` is now the single shared inference used by all
typed paths, with guards against silent corruption:

- Leading zeros (`007`), leading plus (`+1`), and surrounding
  whitespace stay text (previously `' 42'` typed differently per path).
- Digit runs longer than 15 stay text on every platform, keeping VM
  and web results identical (web ints lose precision past 2^53).
- Values that would parse to a non-finite double (`1e999`) stay text.

### Typed decoders no longer invent data (breaking)

- `decodeIntegers` / `decodeDoubles` / `decodeBooleans` throw
  `CsvParseException` (with row and column) on invalid cells instead of
  coercing them; empty cells throw unless an explicit `emptyAs:` fill
  is passed (previously empty became `0` / `0.0` and any non-`true`
  value became `false`).
- `decodeBooleans` truth table is documented and case-insensitive:
  `true`/`1` and `false`/`0`.
- `decodeFlexible` uses `config.quoteCharacter` when restoring an
  unmatched quote (previously hardcoded `"`), and reads empty fields as
  `''` instead of `null` when typing is off.

### Streaming you can trust

- `CsvDecoder.bind` and `CsvEncoder.bind` honor downstream
  backpressure (pause/resume/cancel propagate to the source), so a
  slow consumer no longer buffers the whole input in memory, and the
  output stream closes after an upstream error instead of hanging.
- Multi-character delimiters split across chunk boundaries now parse
  correctly (previously they became field text).
- New `CsvDecoder.bindBytes` / `CsvEncoder.bindBytes` for UTF-8 byte
  streams without manual `utf8` wiring.
- `CsvFile.writeStream` closes the file even when the source stream
  errors.

### New: strict mode

`CsvConfig(strict: true)` throws `CsvParseException` with row and
column on structurally malformed input (text after a closing quote,
unterminated quote) instead of recovering. Lenient stays the default.

### Fixed

- `decodeWithHeaders` parsed the entire input twice; it is now single
  pass and roughly twice as fast (fastest in the ecosystem on this
  workload, previously the single lost benchmark).
- `CsvTable.map` handed live row lists to its transform, so writing
  through the row mutated the source table. The transform now receives
  a copy; the source is never modified.
- Delimiter autodetect no longer misreads single-column text containing
  semicolons as two columns: a candidate must appear on every sampled
  line to qualify (csv 8 still has this failure).
- `CsvTable.parse` headers are raw strings (`01` stays `01`).
- All table sorts are stable, and nulls sort last in both directions.
  Mixed-type columns sort numbers before string look-alikes instead of
  comparing `"10" < "9"` lexicographically.
- `distinct()` keys are type-aware (`1`, `1.0`, and `"1"` are distinct)
  and immune to separator collisions in string content.
- `encodeGeneric<String>` quotes strings containing delimiters instead
  of producing corrupt CSV; `QuoteMode.always` writes null as `""`.
- Batch and streaming encoders share one cell-writing implementation.

### Changed

- `ColumnDef` is renamed `CsvColumnDef` (a deprecated typedef keeps old
  code compiling).
- `DelimiterDetector` left the default `csv_plus.dart` namespace;
  import `package:csv_plus/decoder.dart` to use it directly.
- `CsvTable` documents its mutation rule: table-returning methods copy,
  void methods mutate in place. New stable `sortedBy()` returns a
  sorted copy.
- Releases are gated: the publish workflow now runs format, analyze,
  tests, and a publish dry-run before tagging or publishing, and CI
  runs a stable + minimum SDK matrix plus wasm and pana jobs.

### Benchmarks

Fastest on every measured workload (decode, typed decode, autodetect,
quote-heavy, encode, decodeWithHeaders) against csv 8.0.0,
fast_csv 0.2.11, and serial_csv 0.5.2, on JIT and AOT. The reproducible
harness and full tables live in `benchmark/compare/`.

---

## 0.0.2

### Documentation
- Redesigned README with hero layout, badges, feature table, and quick start examples
- Added 8 mini-library files for dartdoc sidebar navigation (core, codec, encoder, decoder, table, query, transform, io)
- Enhanced barrel export `lib/csv_plus.dart` with library modules reference

### Meta
- Added MIT LICENSE file
- SEO-optimized pubspec description and topics for pub.dev
- Added CI workflow (analyze, format, test on PRs)
- Added publish workflow (auto-tag + publish to pub.dev)

---

## 0.0.1

### Core
- `CsvConfig`: immutable configuration with presets: `CsvConfig()`, `.excel()`, `.tsv()`, `.pipe()`
- `CsvConfig.copyWith()`: create modified copies
- `QuoteMode` enum: `necessary`, `always`, `strings`
- `CsvException`, `CsvParseException`, `CsvValidationException`: typed error hierarchy

### Encoding
- `FastEncoder`: high-performance batch encoder with `encode()`, `encodeStrings()`, `encodeGeneric<T>()`, `encodeMap()`
- `CsvEncoder`: streaming encoder as `StreamTransformer` with `bind()`, `convert()`, `startChunkedConversion()`
- `CsvEncoder.encodeField()`: static helper for single-field quoting
- codeUnit-based `_needsQuoting()` for multi-char delimiter support

### Decoding
- `FastDecoder`: byte-level batch decoder with `codeUnits` parsing, labeled-loop control flow, first-byte type inference
- Decode variants: `decode()`, `decodeStrings()`, `decodeFlexible()`, `decodeIntegers()`, `decodeDoubles()`, `decodeBooleans()`
- `CsvDecoder`: chunked state-machine streaming decoder with `bind()`, `convert()`, `startChunkedConversion()`
- Handles chunk boundaries splitting mid-field, mid-escape, mid-CRLF
- `DelimiterDetector`: frequency/consistency scoring across candidates `[, ; \t |]`, BOM strip, `sep=` hint

### Facade
- `CsvCodec`: main API with all decode/encode methods, presets, auto-detection
- `CsvCodec.decodeToTable()`, `decodeMap()`, `encodeMap()`
- `CsvCodec.decoder` / `encoder`: streaming transformer getters
- `CsvCodecAdapter`: `Codec<List<List<dynamic>>, String>` for `dart:convert` pipelines and `.fuse()`
- `csvPlus`, `csvExcel`, `csvTsv`: global convenience instances

### CsvTable (50+ methods)
- **Constructors:** `CsvTable()`, `.withHeaders()`, `.fromData()`, `.fromMaps()`, `.parse()`, `.empty()`
- **Access:** `operator []`, `cell()`, `cellByName()`, `setCell()`, `setCellByName()`, `column()`, `columnAt()`, `getColumn()`, `getColumnAt()`
- **Row ops:** `addRow()`, `addRowFromMap()`, `addRows()`, `insertRow()`, `removeRow()`, `removeWhere()`
- **Column ops:** `addColumn()`, `insertColumn()`, `removeColumn()`, `removeColumnAt()`, `renameColumn()`, `reorderColumns()`
- **Query:** `where()`, `firstWhere()`, `any()`, `every()`, `range()`, `take()`, `skip()`, `distinct()`
- **Sort:** `sortBy()`, `sortByIndex()`, `sortByMultiple()`, `sort()`
- **Transform:** `transformColumn()`, `map()`, `fold<T>()`
- **Aggregate:** `count()`, `sum()`, `avg()`, `min()`, `max()`, `groupBy()`
- **Export:** `toList()`, `toMaps()`, `toCsv()`, `toString()`, `toFormattedString()`, `copy()`
- **Validation:** `validate()`, `conformsTo()`, `inferSchema()`

### CsvRow
- Dual-mode access: `row[0]` (int) and `row['name']` (String)
- `set()`, `headerMap`, `hasHeaders`, `headers`, `containsHeader()`, `toMap()`, `getHeaderName()`, `toString()`

### CsvColumn
- Column descriptor with `name`, `index`, `values`, `inferredType`, `nonNullCount`, `nullCount`, `uniqueCount`

### CsvSchema & ColumnDef
- Schema definition with `columns`, `allowExtraColumns`, `allowMissingColumns`
- `CsvSchema.infer()`: infer types and nullability from data
- `validate()`: check required columns, types, nullability, patterns, custom validators
- `ColumnDef` with `name`, `type`, `required`, `nullable`, `pattern`, `validator`

### CsvFile (dart:io)
- Static methods: `read()`, `readSync()`, `stream()`, `write()`, `writeSync()`, `writeRows()`, `writeStream()`, `append()`
- Uses `utf8.decoder` for stream operations
- Isolated in `io/csv_file.dart`: core library stays platform-independent
