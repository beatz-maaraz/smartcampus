import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Low-level HTTP wrappers around the two image-scanning providers.
/// Groq is tried first (fast vision model, returns a structured JSON
/// safety brief directly). Hugging Face is the backup: a general image
/// classifier that returns label guesses when Groq is unavailable or
/// fails (e.g. rate limit, no key, network error).
class ChemicalHubService {
  final String groqApiKey;
  final String huggingFaceApiKey;

  ChemicalHubService({
    required this.groqApiKey,
    required this.huggingFaceApiKey,
  });

  /// Scans a chemical label/structure image using Groq's vision model and
  /// asks it to return a JSON safety brief directly, so the caller can
  /// parse it straight into a ChemicalInfo without a second round trip.
  Future<Map<String, dynamic>> scanChemicalWithGroq(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    // Groq (and most vision APIs) reject or time out on very large
    // base64 payloads. Fail fast with a clear message instead of a
    // confusing timeout/400 if the picker's compression didn't apply.
    if (bytes.lengthInBytes > 4 * 1024 * 1024) {
      throw Exception(
          'Image is ${(bytes.lengthInBytes / 1024 / 1024).toStringAsFixed(1)}MB '
          '— too large. Try a smaller/compressed photo.');
    }

    final base64Image = base64Encode(bytes);

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http
        .post(
      url,
      headers: {
        'Authorization': 'Bearer $groqApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'qwen/qwen3.6-27b',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    'Look at this chemical label or structure image. Identify '
                        'it and respond with ONLY a JSON object (no markdown '
                        'fences, no extra text) with exactly these keys: '
                        '"name" (string), "formula" (string), '
                        '"hazard" (one of "safe", "careful", "hazardous"), '
                        '"usage" (short string), "firstAid" (short string). '
                        'If you cannot identify the chemical, still return your '
                        'best guess with hazard set to "careful".'
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
              }
            ]
          }
        ],
        'temperature': 0.2,
        'max_completion_tokens': 512,
        // qwen3.6-27b has a "thinking" mode that can inject reasoning
        // text into the response and was the likely cause of Groq's
        // internal "json_validate_failed" crash. Disabling it (and
        // hiding any reasoning tokens that slip through) keeps the
        // response to plain final-answer text we can parse.
        'reasoning_effort': 'none',
        'reasoning_format': 'hidden',
      }),
    )
        .timeout(const Duration(seconds: 30), onTimeout: () {
      throw Exception(
          'Groq request timed out after 30s — check your internet connection.');
    });

    if (response.statusCode != 200) {
      throw Exception(
          'Groq API Error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String? ?? '';
    return _extractJson(content);
  }

  /// Pulls a JSON object out of the model's text response even if it
  /// ignored the "no extra text" instruction and wrapped the JSON in
  /// markdown fences or a sentence of commentary. Throws with the raw
  /// content included if no JSON object can be found at all, so the
  /// failure is diagnosable instead of a blank crash.
  Map<String, dynamic> _extractJson(String content) {
    var cleaned =
        content.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end < start) {
      throw Exception('Model did not return JSON. Raw response: $cleaned');
    }
    cleaned = cleaned.substring(start, end + 1);
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
          'Could not parse model JSON ($e). Raw response: $cleaned');
    }
  }

  /// Backup: general-purpose image classification using the Hugging Face
  /// Inference API. Returns raw label/score pairs — the caller is
  /// responsible for turning the top label into a chemical name and then
  /// looking up (or asking for) its safety info.
  Future<List<dynamic>> classifyChemicalWithHuggingFace(
    File imageFile, {
    String modelId = 'google/vit-base-patch16-224',
  }) async {
    final bytes = await imageFile.readAsBytes();
    final url =
        Uri.parse('https://api-inference.huggingface.co/models/$modelId');

    final response = await http
        .post(
      url,
      headers: {
        'Authorization': 'Bearer $huggingFaceApiKey',
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    )
        .timeout(const Duration(seconds: 30), onTimeout: () {
      throw Exception('Hugging Face request timed out after 30s.');
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception(
          'Hugging Face API Error: ${response.statusCode} - ${response.body}');
    }
  }
}
