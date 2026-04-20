import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/model_catalog_meta.dart';
import '../../core/utils/model_catalog_matcher.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';

/// Resolves an OpenRouter [ModelCatalogMeta] for [modelId] against [catalog].
///
/// Matching rules (delegated to [ModelCatalogMatcher]):
/// - Exact match → returns the meta directly.
/// - Ambiguous match → shows a picker pre-filtered to the candidates.
/// - No match → shows the full catalog picker for manual selection.
/// - User dismisses any picker → returns `null` (no-op for the caller).
Future<ModelCatalogMeta?> resolveOrMeta(
  BuildContext context, {
  required String modelId,
  required Map<String, ModelCatalogMeta> catalog,
}) async {
  final result = ModelCatalogMatcher.match(modelId, catalog);
  switch (result) {
    case CatalogMatchExact(:final meta):
      return meta;
    case CatalogMatchAmbiguous(:final candidateIds):
      final chosen = await showOrModelPickerDialog(
        context,
        catalog: catalog,
        candidates: candidateIds,
      );
      return chosen == null ? null : catalog[chosen];
    case CatalogMatchNone():
      final chosen = await showOrModelPickerDialog(context, catalog: catalog);
      return chosen == null ? null : catalog[chosen];
  }
}

/// Shows a dialog asking the user to manually select which OpenRouter catalog
/// entry corresponds to a given provider model ID.
///
/// Returns the chosen OpenRouter catalog ID, or `null` if the user skips.
Future<String?> showOrModelPickerDialog(
  BuildContext context, {
  required Map<String, ModelCatalogMeta> catalog,

  /// Pre-filtered candidate IDs (from ambiguous match). When empty or null,
  /// the full catalog is shown.
  List<String>? candidates,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) =>
        _OrModelPickerDialog(catalog: catalog, candidates: candidates),
  );
}

class _OrModelPickerDialog extends StatefulWidget {
  const _OrModelPickerDialog({required this.catalog, this.candidates});

  final Map<String, ModelCatalogMeta> catalog;
  final List<String>? candidates;

  @override
  State<_OrModelPickerDialog> createState() => _OrModelPickerDialogState();
}

class _OrModelPickerDialogState extends State<_OrModelPickerDialog> {
  final TextEditingController _search = TextEditingController();
  late List<String> _source;

  @override
  void initState() {
    super.initState();
    _source =
        (widget.candidates?.isNotEmpty == true)
              ? widget.candidates!
              : widget.catalog.keys.toList()
          ..sort();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[/\-.]'), '');

  static bool _isSubsequence(String query, String target) {
    int qi = 0;
    for (int ti = 0; ti < target.length && qi < query.length; ti++) {
      if (target[ti] == query[qi]) qi++;
    }
    return qi == query.length;
  }

  List<String> _filtered() {
    final q = _normalize(_search.text.trim());
    if (q.isEmpty) return _source;
    return _source.where((id) => _isSubsequence(q, _normalize(id))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                l10n.orModelPickerTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.orModelPickerSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              // Search field
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.orModelPickerSearchHint,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF2F3F5),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.orModelPickerNoResults,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final id = filtered[i];
                          final meta = widget.catalog[id];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: IosCardPress(
                              borderRadius: BorderRadius.circular(10),
                              baseColor: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF5F5F5),
                              pressedScale: 0.98,
                              haptics: false,
                              onTap: () => Navigator.of(context).pop(id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        id,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (meta != null) ...[
                                      const SizedBox(width: 8),
                                      _MetaChips(meta: meta),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              // Skip button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(l10n.orModelPickerSkip),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Displays context length + tool/reasoning capsules for a catalog entry.
class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.meta});

  final ModelCatalogMeta meta;

  static const double _iconSize = 12;
  static const EdgeInsets _pillPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 3,
  );

  Widget _pill(Widget icon, Color color, String tooltip, bool isDark) {
    final bg = isDark
        ? color.withValues(alpha: 0.20)
        : color.withValues(alpha: 0.16);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        child: ExcludeSemantics(
          child: Container(
            padding: _pillPadding,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: icon,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toolsLabel = l10n?.modelDetailSheetToolsAbility ?? 'Tools';
    final reasoningLabel =
        l10n?.modelDetailSheetReasoningAbility ?? 'Reasoning';

    final chips = <Widget>[];

    if (meta.contextLength != null) {
      chips.add(
        Text(
          _fmt(meta.contextLength!),
          style: TextStyle(
            fontSize: 11.5,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (meta.supportsTools) {
      chips.add(
        _pill(
          Icon(Lucide.Hammer, size: _iconSize, color: cs.primary),
          cs.primary,
          toolsLabel,
          isDark,
        ),
      );
    }

    if (meta.supportsReasoning) {
      chips.add(
        _pill(
          SvgPicture.asset(
            'assets/icons/deepthink.svg',
            width: _iconSize,
            height: _iconSize,
            colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
            errorBuilder: (_, __, ___) {
              if (kDebugMode) {
                debugPrint(
                  '[OrModelPicker] Failed to load assets/icons/deepthink.svg',
                );
              }
              return Icon(Lucide.Brain, size: _iconSize, color: cs.secondary);
            },
            placeholderBuilder: (_) =>
                Icon(Lucide.Brain, size: _iconSize, color: cs.secondary),
          ),
          cs.secondary,
          reasoningLabel,
          isDark,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}
