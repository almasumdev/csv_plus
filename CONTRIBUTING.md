# Contributing

Thanks for taking the time to help. Bug reports, fixes and awkward real-world
CSV files are all welcome. A file that breaks the parser is often worth more
than a long description, because almost every exporter disagrees with RFC 4180
somewhere.

## Reporting a bug

Open an [issue](https://github.com/almasumdev/csv_plus/issues) and include:

- The package version you are on, and your Dart or Flutter version.
- Where the file came from: Excel, Google Sheets, a database export, a bank.
  The dialect usually explains the behaviour.
- A small snippet that reproduces it, and the error or the wrong output.
- The relevant few lines of the file. Strip anything sensitive; two rows are
  usually enough, and the exact bytes matter more than the whole file.

Quoting, line endings and encodings are where the surprises live. If a field
comes back split, joined or with a stray character, include the raw bytes of
that line rather than a copy that a text editor may have already normalised.

## Asking a question

If you are not sure whether something is a bug, start a
[discussion](https://github.com/almasumdev/csv_plus/discussions) instead.
Questions stay searchable there for the next person.

## Working on the code

```bash
git clone https://github.com/almasumdev/csv_plus.git
cd csv_plus
dart pub get
dart test
```

Before opening a pull request:

```bash
dart format .
dart analyze --fatal-infos   # must be clean
dart test                    # includes the conformance suite
```

## Things worth knowing before you change the decoder

- **One parsing semantics.** `FastDecoder.decode`, `decodeStrings` and the
  streaming `CsvDecoder` must return identical rows for identical input.
  `test/conformance_test.dart` runs every case through all three, and through
  the streaming machine split at every possible chunk offset. If a change is
  hard to make in all three, that is a signal, not an obstacle to route around.
- **One shared `inferType`.** Every typed path calls it, and it carries
  deliberate data-loss guards: leading zeros, a leading plus, surrounding
  whitespace, long digit runs and non-finite doubles all stay text, and quoted
  fields are never inferred. Adding an inference rule in one path only will
  break conformance.
- **Hot loops use `codeUnits`.** No regex, no `tryParse` inside the loop, no
  per-character string allocation.
- **The core stays `dart:io` free.** `lib/src/io/csv_file.dart` is the only file
  that may import it, reachable through `package:csv_plus/io.dart`.
- Changes should be **additive** and backward-compatible.

## Tests

Add cases to the conformance suite when you touch parsing, so all three paths
are covered at once. Name suites after the feature, group names as title-case
noun phrases, test names as lowercase sentences saying what must be true.

## Commits

Conventional commit messages (`fix:`, `feat:`, `docs:`, `refactor:`). Say what
changed and why the old behaviour was wrong.
