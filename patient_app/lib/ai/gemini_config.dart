/// Configuration for Google Gemini integration in Saathi.
class GeminiConfig {
  /// The Gemini API key used for conversational AI and dynamic questions.
  /// Can be overridden at build time using `--dart-define=GEMINI_API_KEY=...`.
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Default model used for conversational companion.
  /// gemini-2.5-flash is supported, ultra-fast, and cost-effective.
  static const String modelName = 'gemini-2.5-flash';
}
