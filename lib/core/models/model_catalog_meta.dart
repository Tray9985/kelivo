/// Model metadata from the models.dev catalog.
///
/// Used as a universal metadata source for all providers.
/// Context keys written to [ProviderConfig.modelOverrides] use plain names
/// without any provider prefix.
class ModelCatalogMeta {
  const ModelCatalogMeta({
    this.name,
    this.contextLength,
    this.maxOutputTokens,
    this.supportsTools = false,
    this.supportsReasoning = false,
    this.supportsVision = false,
  });

  static const String kContextLength = 'contextLength';
  static const String kMaxOutputTokens = 'maxOutputTokens';

  final String? name;
  final int? contextLength;
  final int? maxOutputTokens;
  final bool supportsTools;
  final bool supportsReasoning;
  final bool supportsVision;

  factory ModelCatalogMeta.fromModelsDevJson(Map<String, dynamic> json) {
    final limit = json['limit'];
    final int? contextLength = limit is Map
        ? (limit['context'] as num?)?.toInt()
        : null;
    final int? maxOutputTokens = limit is Map
        ? (limit['output'] as num?)?.toInt()
        : null;

    final modalities = json['modalities'];
    final inputMods =
        (modalities is Map ? modalities['input'] as List? : null)
            ?.cast<String>() ??
        [];

    return ModelCatalogMeta(
      name: json['name'] as String?,
      contextLength: contextLength,
      maxOutputTokens: maxOutputTokens,
      supportsTools: (json['tool_call'] as bool?) ?? false,
      supportsReasoning: (json['reasoning'] as bool?) ?? false,
      supportsVision: inputMods.contains('image'),
    );
  }

  /// Builds the override map to merge into a modelOverrides entry.
  ///
  /// Abilities and input modalities are merged with existing values
  /// (only added, never removed) so manually-set preferences survive.
  Map<String, dynamic> toFullOverrideMap(
    Map<String, dynamic> existingOverride,
  ) {
    final result = <String, dynamic>{
      if (contextLength != null) kContextLength: contextLength,
      if (maxOutputTokens != null) kMaxOutputTokens: maxOutputTokens,
    };

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

  factory ModelCatalogMeta.fromOverrideMap(Map<String, dynamic> map) {
    final abilities = map['abilities'];
    final abList = abilities is List
        ? abilities.cast<String>()
        : const <String>[];
    return ModelCatalogMeta(
      contextLength: map[kContextLength] as int?,
      maxOutputTokens: map[kMaxOutputTokens] as int?,
      supportsTools: abList.contains('tool'),
      supportsReasoning: abList.contains('reasoning'),
    );
  }

  bool get hasData =>
      contextLength != null ||
      maxOutputTokens != null ||
      supportsTools ||
      supportsReasoning ||
      supportsVision;

  @override
  String toString() =>
      'ModelCatalogMeta(name: $name, contextLength: $contextLength, '
      'maxOutputTokens: $maxOutputTokens, '
      'supportsTools: $supportsTools, '
      'supportsReasoning: $supportsReasoning, '
      'supportsVision: $supportsVision)';
}
