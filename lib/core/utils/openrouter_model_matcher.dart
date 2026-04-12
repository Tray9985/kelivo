import '../models/openrouter_model_meta.dart';

/// Result of matching a provider model ID against the OpenRouter catalog.
sealed class OpenRouterMatchResult {
  const OpenRouterMatchResult();
}

/// Exactly one match found.
final class OpenRouterMatchExact extends OpenRouterMatchResult {
  const OpenRouterMatchExact(this.catalogId, this.meta);
  final String catalogId;
  final OpenRouterModelMeta meta;
}

/// Multiple plausible matches found; user must choose.
final class OpenRouterMatchAmbiguous extends OpenRouterMatchResult {
  const OpenRouterMatchAmbiguous(this.candidateIds);
  final List<String> candidateIds;
}

/// No match found.
final class OpenRouterMatchNone extends OpenRouterMatchResult {
  const OpenRouterMatchNone();
}

/// Matches a provider model ID against the OpenRouter catalog using fuzzy rules.
///
/// Rules (applied in order, first match wins):
/// 1. Exact match (case-insensitive).
/// 2. Namespace strip: remove leading `<namespace>/` from both sides and compare.
/// 3. Version-tolerant: strip trailing `-YYYYMMDD` date suffixes and compare.
///
/// Returns [OpenRouterMatchExact] when exactly one candidate remains,
/// [OpenRouterMatchAmbiguous] when multiple candidates remain,
/// or [OpenRouterMatchNone] when nothing matches.
class OpenRouterModelMatcher {
  /// Entry point for matching.
  static OpenRouterMatchResult match(
    String providerId,
    Map<String, OpenRouterModelMeta> catalog,
  ) {
    if (catalog.isEmpty) return const OpenRouterMatchNone();

    // Rule 1: exact match (case-insensitive).
    final lowerProvider = providerId.toLowerCase();
    final exactKey = catalog.keys.firstWhere(
      (k) => k.toLowerCase() == lowerProvider,
      orElse: () => '',
    );
    if (exactKey.isNotEmpty) {
      return OpenRouterMatchExact(exactKey, catalog[exactKey]!);
    }

    // Rule 2: strip namespace prefix from provider ID and compare against
    // catalog IDs with namespace stripped as well.
    final strippedProvider = _stripNamespace(lowerProvider);
    final rule2Matches = <String>[];
    for (final k in catalog.keys) {
      if (_stripNamespace(k.toLowerCase()) == strippedProvider) {
        rule2Matches.add(k);
      }
    }
    if (rule2Matches.length == 1) {
      return OpenRouterMatchExact(
        rule2Matches.first,
        catalog[rule2Matches.first]!,
      );
    }
    if (rule2Matches.length > 1) {
      return OpenRouterMatchAmbiguous(rule2Matches);
    }

    // Rule 3: strip trailing date suffix (e.g., -20241022) and compare.
    final datelessProvider = _stripDateSuffix(strippedProvider);
    if (datelessProvider == strippedProvider) {
      // No date suffix present; nothing more to try.
      return const OpenRouterMatchNone();
    }
    final rule3Matches = <String>[];
    for (final k in catalog.keys) {
      final datelessCatalog = _stripDateSuffix(
        _stripNamespace(k.toLowerCase()),
      );
      if (datelessCatalog == datelessProvider) {
        rule3Matches.add(k);
      }
    }
    if (rule3Matches.length == 1) {
      return OpenRouterMatchExact(
        rule3Matches.first,
        catalog[rule3Matches.first]!,
      );
    }
    if (rule3Matches.length > 1) {
      return OpenRouterMatchAmbiguous(rule3Matches);
    }

    return const OpenRouterMatchNone();
  }

  /// Removes `<namespace>/` prefix (everything up to and including the first `/`).
  static String _stripNamespace(String id) {
    final slash = id.indexOf('/');
    return slash >= 0 ? id.substring(slash + 1) : id;
  }

  /// Removes a trailing `-YYYYMMDD` date suffix.
  static final RegExp _dateSuffixRe = RegExp(r'-\d{8}$');

  static String _stripDateSuffix(String id) =>
      id.replaceFirst(_dateSuffixRe, '');
}
