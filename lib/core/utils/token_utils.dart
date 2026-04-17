import '../models/chat_message.dart';

/// Shared token utilities: formatting, estimation, and trim-boundary calculation.
///
/// Single source of truth for all token-related logic. Avoids duplicated
/// estimation formulas and format strings scattered across UI and service layers.
abstract final class TokenUtils {
  // ── Formatting ─────────────────────────────────────────────────────────────

  /// Format a token / context-length count into a human-readable string.
  ///
  /// Uses integer division for K so the result never rounds up to "1000K".
  static String format(int n) {
    if (n >= 1_000_000) {
      final m = n / 1_000_000;
      return '${m >= 10 ? m.round() : m.toStringAsFixed(1)}M';
    }
    if (n >= 1_000) return '${n ~/ 1_000}K';
    return '$n';
  }

  // ── Estimation ─────────────────────────────────────────────────────────────

  /// Rough token estimate for a single API message map (~2 chars per token + 4).
  ///
  /// Handles both `String` and `List` content shapes.
  /// The +4 accounts for role / structure overhead per message.
  /// Uses chars/2 rather than the English-only chars/4 to be more conservative
  /// for mixed or CJK-heavy content — better to over-trim than overflow.
  static int estimateApiMessage(Map<String, dynamic> msg) {
    final content = msg['content'];
    final int chars;
    if (content is String) {
      chars = content.length;
    } else if (content is List) {
      int total = 0;
      for (final part in content) {
        if (part is Map) {
          final type = part['type'];
          if (type == 'text') {
            total += (part['text'] as String? ?? '').length;
          } else {
            total += part.toString().length;
          }
        } else {
          total += part.toString().length;
        }
      }
      chars = total;
    } else {
      chars = content?.toString().length ?? 0;
    }
    return (chars / 2).ceil() + 4;
  }

  // ── Conversation helpers ───────────────────────────────────────────────────

  /// Return the [promptTokens] of the most recent completed AI message.
  ///
  /// [promptTokens] = the tokens consumed by the INPUT sent to the API for
  /// that turn (system prompt + all history + last user message). It excludes
  /// the AI response, making it the correct value for the context ring's
  /// inner ring (what the AI actually received as input).
  ///
  /// Returns null when no completed AI message with [promptTokens] data exists.
  static int? lastPromptTokens(List<ChatMessage> messages) {
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role == 'assistant' &&
          !m.isStreaming &&
          (m.promptTokens ?? 0) > 0) {
        return m.promptTokens;
      }
    }
    return null;
  }
}
