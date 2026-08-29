## What this changes

<!-- One or two sentences. Link the issue it relates to, if there is one. -->

## Why

<!-- What was wrong with the old behaviour. The diff already shows the how. -->

## Checks

- [ ] `dart format .`
- [ ] `dart analyze --fatal-infos` reports no issues
- [ ] `dart test` passes, conformance suite included
- [ ] `CHANGELOG.md` updated
- [ ] Change is additive; nothing existing breaks

## If you touched parsing

- [ ] Batch, string and streaming paths still return identical rows
- [ ] New cases added to `test/conformance_test.dart`
- [ ] No regex or `tryParse` added to a hot loop
- [ ] Core is still free of `dart:io`
