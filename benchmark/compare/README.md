# Head-to-head benchmark

Reproducible comparison of csv_plus against the other Dart CSV packages.
Every performance claim in the main README points here.

Pinned versions (see [pubspec.yaml](pubspec.yaml)): csv 8.0.0,
serial_csv 0.5.2, csv_plus from this repository (v1.0.0).

## Method

Median of 5 timed runs after 2 warmups, with checksums to defeat
dead-code elimination. Seeded generators produce two datasets:
200,000 rows x 10 cols of plain mixed types (14.3 MB) and
100,000 rows x 10 cols of quote-heavy text with embedded commas, quotes,
and newlines (18.4 MB). See [bench.dart](bench.dart).

## Results, 2026-07-11 (Windows 11 x64, Dart stable)

### JIT (`dart run bench.dart`)

| Workload | csv 8.0.0 | serial_csv | csv_plus |
|---|---|---|---|
| Decode plain, strings | 181.2 | 325.8 (own fmt) | **94.0** |
| Decode plain, typed | 224.9 | 111.7 (own fmt) | **96.8** |
| Decode plain, autodetect on | 245.1 | n/a | **90.5** |
| Decode quote-heavy, strings | 133.7 | n/a | **77.6** |
| Encode plain (typed rows) | 153.2 | 141.8 | **125.2** |
| Encode quote-heavy | 154.7 | n/a | **99.4** |
| decodeWithHeaders | 178.5 | n/a | **95.4** |

### AOT (`dart compile exe bench.dart`)

| Workload | csv 8.0.0 | serial_csv | csv_plus |
|---|---|---|---|
| Decode plain, strings | 194.0 | 363.1 (own fmt) | **94.0** |
| Decode plain, typed | 242.2 | 119.0 (own fmt) | **97.3** |
| Decode plain, autodetect on | 251.5 | n/a | **109.0** |
| Decode quote-heavy, strings | 136.3 | n/a | **86.8** |
| Encode plain (typed rows) | 163.1 | 177.3 | **129.7** |
| Encode quote-heavy | 170.9 | n/a | **106.4** |
| decodeWithHeaders | 191.5 | n/a | **106.0** |

All times in milliseconds; bold marks the fastest. csv_plus is the
fastest on every workload, on both compilers. serial_csv decodes only
its own strict format, so its rows are not apples-to-apples with the
general parsers.

Two notes for honest reading:

- At v0.0.2, `decodeWithHeaders` parsed the input twice and lost to
  csv 8 (186 vs 180 ms JIT). 1.0.0 parses once, which is why that row
  roughly halved.
- 1.0.0's typed decode carries the cost of its data-loss guards
  (leading zeros, 15-digit limit, finiteness checks), a few percent
  versus the unguarded v0.0.2 scanner. It remains about 2.3x faster
  than csv 8's typed decode.

## Edge-case comparison

[correctness.dart](correctness.dart) runs a 20-case battery of tricky
inputs (malformed quotes, BOM, typed edge values, `sep=` hints) through
every package and through both csv_plus decoders, printing the produced
rows side by side.

## Reproduce

```
cd benchmark/compare
dart pub get
dart run bench.dart                 # JIT
dart compile exe bench.dart -o bench.exe && ./bench.exe   # AOT
dart run correctness.dart
```

Web integer caveat: on dart2js, `int` is an IEEE double, so integers past
2^53 lose precision. csv_plus keeps digit runs longer than 15 as strings
on every platform (a deliberate data-loss guard), which also makes VM and
web results identical.
