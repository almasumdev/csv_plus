import '../core/csv_config.dart';
import 'delimiter_detector.dart';

const _detector = DelimiterDetector();

/// Whether [config] asks for delimiter detection.
///
/// Detection is skipped when the user has explicitly set a non-default field
/// delimiter (anything other than `,`), since that signals intent.
bool needsAutoDetect(CsvConfig config) =>
    config.autoDetect && config.fieldDelimiter == ',';

/// Resolve [config] against [input] when [CsvConfig.autoDetect] is enabled and
/// the input carries a recognisable delimiter or an Excel `sep=` hint.
///
/// Returns the input to parse (without the `sep=` line when one was found) and
/// the config to parse it with. The batch codec and the streaming decoder both
/// call this, so they apply one rule.
(String, CsvConfig) resolveAutoDetect(String input, CsvConfig config) {
  if (!needsAutoDetect(config)) return (input, config);

  final (bomStripped, _) = _detector.stripBom(input);
  final (remaining, sepDelim) = _detector.checkSepHint(bomStripped);

  if (sepDelim != null) {
    // sep= hint found: strip that line and use the hinted delimiter
    return (remaining, config.copyWith(fieldDelimiter: sepDelim));
  }

  final detected = _detector.detectDelimiter(bomStripped);
  if (detected != config.fieldDelimiter) {
    return (input, config.copyWith(fieldDelimiter: detected));
  }
  return (input, config);
}
