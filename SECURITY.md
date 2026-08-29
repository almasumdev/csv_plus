# Security Policy

## Supported versions

Fixes land on the latest published version. Please reproduce on the newest
release before reporting.

| Version | Supported |
| ------- | --------- |
| Latest release | Yes |
| Anything older | No, please upgrade first |

## Reporting a vulnerability

Do not open a public issue for a security problem.

Use GitHub's private reporting on the
[Security tab](https://github.com/almasumdev/csv_plus/security/advisories/new),
or email dev.almasum@gmail.com. Include the package version, a description of
the issue, and the input that reproduces it if you have it.

You can expect an acknowledgement within a few days. If the report is confirmed,
a fix will be published and the advisory credited to you unless you would rather
stay anonymous.

## Scope

This package parses text that usually comes from somewhere you do not control,
so that is what to look at:

- Input that makes the decoder consume unbounded memory or fail to terminate.
  The streaming decoder is designed to hold one row at a time regardless of file
  size; input that defeats that is a bug worth reporting.
- Input that causes an out-of-range read or an unhandled crash rather than a
  `CsvParseException`.
- Anything that makes the three decode paths disagree, since callers rely on the
  batch and streaming results being identical.

Out of scope:

- **Formula injection in the consuming application.** A field beginning with
  `=`, `+`, `-` or `@` is a formula to Excel and Google Sheets. This package
  stores and returns exactly what you give it and does not evaluate anything.
  If you write untrusted text into a file a spreadsheet will open, sanitise it
  in your application.
- Malformed input that degrades gracefully by design. Lenient decoding is the
  documented default: unterminated quotes consume to end of input and text after
  a closing quote is appended, matching what spreadsheets do. Use
  `CsvConfig(strict: true)` when you want that to throw instead.
- Vulnerabilities in whatever opens the file afterwards. Report those to the
  relevant vendor.
