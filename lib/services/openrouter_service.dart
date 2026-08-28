import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenRouterService {
  final String apiKey;
  final String siteUrl;
  final String siteName;

  OpenRouterService({
    required this.apiKey,
    this.siteUrl = 'https://myapp.com',
    this.siteName = 'Chemical & Campus Assistant',
  });

  /// Sends conversation messages to OpenRouter API endpoint.
  ///
  /// Defaults to `openrouter/free` — OpenRouter's own router that picks a
  /// $0 model for you, so this works out of the box on a free account.
  /// [maxTokens] is capped by default (OpenRouter requires enough balance
  /// to cover whatever max_tokens you request, even on models you never
  /// end up using the full length of — leaving it unset can ask for far
  /// more than a free/low-balance account can afford and return a 402).
  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    String model = 'openrouter/free',
    int maxTokens = 700,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': siteUrl,
        'X-Title': siteName,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] ??
          'No response received.';
    } else {
      throw Exception(
          'OpenRouter API Error: ${response.statusCode} - ${response.body}');
    }
  }
}
