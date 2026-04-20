import '../models/model_catalog_meta.dart';

sealed class CatalogMatchResult {
  const CatalogMatchResult();
}

final class CatalogMatchExact extends CatalogMatchResult {
  const CatalogMatchExact(this.catalogId, this.meta);
  final String catalogId;
  final ModelCatalogMeta meta;
}

final class CatalogMatchAmbiguous extends CatalogMatchResult {
  const CatalogMatchAmbiguous(this.candidateIds);
  final List<String> candidateIds;
}

final class CatalogMatchNone extends CatalogMatchResult {
  const CatalogMatchNone();
}

/// Matches a provider model ID against the models.dev catalog using fuzzy rules.
///
/// Rules (applied in order, first match wins):
/// 1. Exact match (case-insensitive).
/// 2. Namespace strip: remove leading `<namespace>/` from both sides and compare.
/// 3. Version-tolerant: strip trailing `-YYYYMMDD` date suffixes and compare.
class ModelCatalogMatcher {
  static CatalogMatchResult match(
    String providerId,
    Map<String, ModelCatalogMeta> catalog,
  ) {
    if (catalog.isEmpty) return const CatalogMatchNone();

    final lowerProvider = providerId.toLowerCase();
    final exactKey = catalog.keys.firstWhere(
      (k) => k.toLowerCase() == lowerProvider,
      orElse: () => '',
    );
    if (exactKey.isNotEmpty) {
      return CatalogMatchExact(exactKey, catalog[exactKey]!);
    }

    final strippedProvider = _stripNamespace(lowerProvider);
    final rule2Matches = <String>[];
    for (final k in catalog.keys) {
      if (_stripNamespace(k.toLowerCase()) == strippedProvider) {
        rule2Matches.add(k);
      }
    }
    if (rule2Matches.length == 1) {
      return CatalogMatchExact(
        rule2Matches.first,
        catalog[rule2Matches.first]!,
      );
    }
    if (rule2Matches.length > 1) {
      return CatalogMatchAmbiguous(rule2Matches);
    }

    final datelessProvider = _stripDateSuffix(strippedProvider);
    if (datelessProvider == strippedProvider) return const CatalogMatchNone();

    final rule3Matches = <String>[];
    for (final k in catalog.keys) {
      final datelessCatalog = _stripDateSuffix(
        _stripNamespace(k.toLowerCase()),
      );
      if (datelessCatalog == datelessProvider) rule3Matches.add(k);
    }
    if (rule3Matches.length == 1) {
      return CatalogMatchExact(
        rule3Matches.first,
        catalog[rule3Matches.first]!,
      );
    }
    if (rule3Matches.length > 1) {
      return CatalogMatchAmbiguous(rule3Matches);
    }

    return const CatalogMatchNone();
  }

  static String _stripNamespace(String id) {
    final slash = id.indexOf('/');
    return slash >= 0 ? id.substring(slash + 1) : id;
  }

  static final RegExp _dateSuffixRe = RegExp(r'-\d{8}$');

  static String _stripDateSuffix(String id) =>
      id.replaceFirst(_dateSuffixRe, '');
}
