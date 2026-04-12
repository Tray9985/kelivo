/// OpenRouter public model catalog metadata.
///
/// Used as a universal metadata source for all providers.
/// Context keys written to [ProviderConfig.modelOverrides] use the `or`
/// prefix to avoid collisions with existing override fields.
class OpenRouterModelMeta {
  const OpenRouterModelMeta({
    this.contextLength,
    this.maxCompletionTokens,
    this.supportsTools = false,
    this.supportsReasoning = false,
    this.supportsVision = false,
  });

  /// Key used in modelOverrides map for context window size.
  static const String kContextLength = 'orContextLength';

  /// Key used in modelOverrides map for max completion tokens.
  static const String kMaxCompletionTokens = 'orMaxCompletionTokens';

  final int? contextLength;
  final int? maxCompletionTokens;

  /// Detected from [supported_parameters] containing "tools".
  final bool supportsTools;

  /// Detected from [supported_parameters] containing "reasoning" or
  /// "include_reasoning".
  final bool supportsReasoning;

  /// Detected from [architecture.input_modalities] containing "image".
  final bool supportsVision;

  factory OpenRouterModelMeta.fromOpenRouterJson(Map<String, dynamic> json) {
    final topProvider = json['top_provider'];
    int? contextLength;
    int? maxCompletionTokens;

    if (topProvider is Map) {
      contextLength = topProvider['context_length'] as int?;
      maxCompletionTokens = topProvider['max_completion_tokens'] as int?;
    }
    // Fall back to root-level context_length if top_provider doesn't have it.
    contextLength ??= json['context_length'] as int?;

    final params =
        (json['supported_parameters'] as List?)?.cast<String>() ?? [];
    final supportsTools = params.contains('tools');
    final supportsReasoning =
        params.contains('reasoning') || params.contains('include_reasoning');

    final arch = json['architecture'];
    final inputMods =
        (arch is Map ? arch['input_modalities'] as List? : null)
            ?.cast<String>() ??
        [];
    final supportsVision = inputMods.contains('image');

    return OpenRouterModelMeta(
      contextLength: contextLength,
      maxCompletionTokens: maxCompletionTokens,
      supportsTools: supportsTools,
      supportsReasoning: supportsReasoning,
      supportsVision: supportsVision,
    );
  }

  /// Builds the override map to merge into a modelOverrides entry.
  ///
  /// [existingOverride] is the current modelOverrides entry for the model
  /// (may be empty). OR-detected abilities/input are merged with existing
  /// values (only added, never removed) so manually-set preferences survive.
  Map<String, dynamic> toFullOverrideMap(
    Map<String, dynamic> existingOverride,
  ) {
    final result = <String, dynamic>{
      if (contextLength != null) kContextLength: contextLength,
      if (maxCompletionTokens != null)
        kMaxCompletionTokens: maxCompletionTokens,
    };

    // Merge abilities.
    final currentAbilities = <String>{};
    final existingAbilities = existingOverride['abilities'];
    if (existingAbilities is List) {
      for (final v in existingAbilities) {
        if (v is String) currentAbilities.add(v);
      }
    }
    if (supportsTools) currentAbilities.add('tool');
    if (supportsReasoning) currentAbilities.add('reasoning');
    if (currentAbilities.isNotEmpty) {
      result['abilities'] = currentAbilities.toList();
    }

    // Merge input modalities if vision detected.
    if (supportsVision) {
      final inputSet = <String>{'text'};
      final existingInput = existingOverride['input'];
      if (existingInput is List) {
        for (final v in existingInput) {
          if (v is String) inputSet.add(v);
        }
      }
      inputSet.add('image');
      result['input'] = inputSet.toList();
    }

    return result;
  }

  /// Reads back from an existing modelOverrides entry.
  factory OpenRouterModelMeta.fromOverrideMap(Map<String, dynamic> map) {
    final abilities = map['abilities'];
    final abList = abilities is List
        ? abilities.cast<String>()
        : const <String>[];
    return OpenRouterModelMeta(
      contextLength: map[kContextLength] as int?,
      maxCompletionTokens: map[kMaxCompletionTokens] as int?,
      supportsTools: abList.contains('tool'),
      supportsReasoning: abList.contains('reasoning'),
    );
  }

  bool get hasData =>
      contextLength != null ||
      maxCompletionTokens != null ||
      supportsTools ||
      supportsReasoning ||
      supportsVision;

  @override
  String toString() =>
      'OpenRouterModelMeta(contextLength: $contextLength, '
      'maxCompletionTokens: $maxCompletionTokens, '
      'supportsTools: $supportsTools, '
      'supportsReasoning: $supportsReasoning, '
      'supportsVision: $supportsVision)';
}
