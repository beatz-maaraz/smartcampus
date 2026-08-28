import 'env_keys.dart';

/// Central place for the three AI provider API keys used across the app:
///   - Groq        -> primary chemical-image scanning (vision model)
///   - Hugging Face-> backup chemical-image classification
///   - OpenRouter  -> AI campus chatbot (and text-based chemical lookup)
///
/// Keys resolve in this order:
///   1. --dart-define, if you passed one (useful for CI/release builds
///      without editing source), e.g.:
///        flutter run --dart-define=GROQ_API_KEY=your_groq_key
///   2. lib/env_keys.dart — so a plain `flutter run` with no flags still
///      works. That file is gitignored; edit it directly to change keys.
class ApiConfig {
  static const _groqDefine = String.fromEnvironment('GROQ_API_KEY');
  static const _hfDefine = String.fromEnvironment('HUGGINGFACE_API_KEY');
  static const _openRouterDefine = String.fromEnvironment('OPENROUTER_API_KEY');

  // Note: '.isEmpty' is a getter call, not allowed in a const expression.
  // '==' on Strings IS allowed in const expressions, so we compare
  // against '' instead.
  static const groqApiKey =
      _groqDefine == '' ? EnvKeys.groqApiKey : _groqDefine;
  static const huggingFaceApiKey =
      _hfDefine == '' ? EnvKeys.huggingFaceApiKey : _hfDefine;
  static const openRouterApiKey =
      _openRouterDefine == '' ? EnvKeys.openRouterApiKey : _openRouterDefine;

  static bool get hasGroqKey => groqApiKey.isNotEmpty;
  static bool get hasHuggingFaceKey => huggingFaceApiKey.isNotEmpty;
  static bool get hasOpenRouterKey => openRouterApiKey.isNotEmpty;

  /// True once at least the chatbot key is present — used to decide
  /// whether AiService should hit real APIs or fall back to mock replies.
  static bool get isConfigured => hasOpenRouterKey;
}
