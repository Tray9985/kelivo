import '../../providers/settings_provider.dart';

const String _openRouterAppReferer = 'https://github.com/Chevey339/kelivo';
const String _openRouterAppTitle = 'Kelivo';
const String _openRouterAppCategories = 'general-chat';

bool isOpenRouterProvider(ProviderConfig config) {
  final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
  return host.contains('openrouter.ai');
}

Map<String, String> providerDefaultHeaders(ProviderConfig config) {
  final out = <String, String>{};
  if (isOpenRouterProvider(config)) {
    out.addAll(const <String, String>{
      'HTTP-Referer': _openRouterAppReferer,
      'X-OpenRouter-Title': _openRouterAppTitle,
      'X-OpenRouter-Categories': _openRouterAppCategories,
    });
  }
  for (final h in config.customHeaders) {
    final name = h['name']?.trim() ?? '';
    final value = h['value'] ?? '';
    if (name.isNotEmpty) out[name] = value;
  }
  return out;
}
