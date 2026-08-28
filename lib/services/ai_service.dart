import 'dart:convert';
import 'dart:io';

import '../config/api_config.dart';
import 'campus_data_service.dart';
import 'chemical_hub_service.dart';
import '../models/models.dart';
import 'openrouter_service.dart';

/// Single entry point the UI talks to for both AI features:
///   1. AI Campus Chatbot          -> OpenRouter
///   2. Chemical Hub text search   -> local DB, then OpenRouter
///   3. Chemical Hub image scan    -> Groq vision, falling back to
///                                    Hugging Face classification
///
/// If a key is missing (ApiConfig.isConfigured / hasGroqKey / etc. is
/// false) this falls back to the old mock behaviour so the app still runs
/// during development without keys.
class AiService {
  final CampusDataService dataService;

  late final OpenRouterService _openRouter = OpenRouterService(
    apiKey: ApiConfig.openRouterApiKey,
  );

  late final ChemicalHubService _chemicalHub = ChemicalHubService(
    groqApiKey: ApiConfig.groqApiKey,
    huggingFaceApiKey: ApiConfig.huggingFaceApiKey,
  );

  AiService(this.dataService);

  static const String _chatSystemPrompt = '''
You are the AI Campus Assistant for Selvam College of Technology.
Answer campus-related questions (locations, timetables, events, general
academic queries) concisely and helpfully. If asked something outside
campus context, politely redirect the user back to campus topics.
''';

  static const String _chemicalSystemPrompt = '''
You are a lab-safety assistant. When given a chemical name, respond with
ONLY a JSON object (no markdown fences, no extra text) with exactly these
keys: "name", "formula", "hazard" (one of "safe", "careful", "hazardous"),
"usage", "firstAid".
''';

  // ---------------------------------------------------------------------
  // 1. Chatbot (OpenRouter)
  // ---------------------------------------------------------------------

  /// [history] should be the prior messages in the conversation (oldest
  /// first), used to give OpenRouter multi-turn context.
  Future<String> askChatbot(String userMessage,
      {List<ChatMessage> history = const []}) async {
    if (!ApiConfig.hasOpenRouterKey) {
      return _mockChatbotReply(userMessage);
    }

    final campusContext = _buildCampusContext();
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': '$_chatSystemPrompt\n\n$campusContext'},
      for (final m in history)
        {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
      {'role': 'user', 'content': userMessage},
    ];

    try {
      return await _openRouter.sendMessage(messages: messages);
    } catch (e) {
      return 'Sorry, I couldn\'t reach the AI service right now (${e.toString()}). '
          'Please try again in a moment.';
    }
  }

  /// Pulls the app's actual stored data (CampusDataService — timetables,
  /// events, venues, notices, and the demo student's fees/attendance) into
  /// the system prompt so the chatbot answers from real records instead of
  /// guessing. The whole dataset is small enough here to include in full
  /// on every request — if this grows much larger, switch to only
  /// including the sections relevant to the user's question (keyword
  /// match on "timetable"/"event"/"venue"/etc.) to keep the prompt short.
  String _buildCampusContext({String demoStudentId = 'student'}) {
    final buffer = StringBuffer();
    buffer.writeln(
        'Use ONLY the data below to answer campus questions — do not invent '
        'schedules, locations, or dates that aren\'t listed here. If '
        'something isn\'t covered below, say you don\'t have that record '
        'yet rather than guessing.');

    // Timetable
    final timetable = dataService.fullTimetable;
    buffer.writeln('\n## Timetable');
    if (timetable.isEmpty) {
      buffer.writeln('(none entered yet)');
    } else {
      for (final t in timetable) {
        buffer.writeln(
            '- ${t.day} ${t.hour}: ${t.subject} with ${t.faculty} in ${t.room}');
      }
    }

    // Events
    final events = dataService.events;
    buffer.writeln('\n## Upcoming Events');
    if (events.isEmpty) {
      buffer.writeln('(none scheduled)');
    } else {
      for (final e in events) {
        buffer.writeln(
            '- "${e.title}" on ${e.date.toLocal().toString().split(' ').first} '
            'at ${e.venue}: ${e.description}');
      }
    }

    // Venues / locations
    final venues = dataService.venues;
    buffer.writeln('\n## Campus Locations');
    if (venues.isEmpty) {
      buffer.writeln('(none mapped)');
    } else {
      for (final v in venues) {
        buffer.writeln('- ${v.name} — ${v.block}');
      }
    }

    // Notices
    final notices = dataService.notices;
    buffer.writeln('\n## Notices');
    if (notices.isEmpty) {
      buffer.writeln('(none posted)');
    } else {
      for (final n in notices.take(10)) {
        buffer.writeln('- [${n.scope}] "${n.title}": ${n.body}');
      }
    }

    // Demo student's own fee + attendance (the app has one seeded
    // demo student — swap this for the actual logged-in user's id once
    // auth is wired to real accounts).
    final fee = dataService.feeStatusFor(demoStudentId);
    if (fee != null) {
      buffer.writeln('\n## Fee Status (current student)');
      buffer.writeln(fee.paid
          ? '- Paid in full.'
          : '- Pending: ₹${fee.amountDue.toStringAsFixed(0)} due.');
    }

    final attendancePercent = dataService.attendancePercentFor(demoStudentId);
    buffer.writeln('\n## Attendance (current student)');
    buffer.writeln('- Overall: ${attendancePercent.toStringAsFixed(1)}%');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------
  // 2. Chemical Hub — text search
  // ---------------------------------------------------------------------

  Future<ChemicalInfo> lookupChemicalSafety(String rawName) async {
    final local = dataService.lookupChemical(rawName);
    if (local != null) return local;

    if (!ApiConfig.hasOpenRouterKey) {
      return _mockChemicalInfo(rawName);
    }

    try {
      final raw = await _openRouter.sendMessage(messages: [
        {'role': 'system', 'content': _chemicalSystemPrompt},
        {'role': 'user', 'content': 'Chemical: "$rawName"'},
      ]);
      return _parseChemicalJson(raw, fallbackName: rawName);
    } catch (_) {
      return _mockChemicalInfo(rawName);
    }
  }

  // ---------------------------------------------------------------------
  // 3. Chemical Hub — image scan (Groq primary, Hugging Face backup)
  // ---------------------------------------------------------------------

  Future<ChemicalInfo> scanChemicalImage(File imageFile) async {
    String? groqError;
    String? hfError;

    if (ApiConfig.hasGroqKey) {
      try {
        final json = await _chemicalHub.scanChemicalWithGroq(imageFile);
        return _chemicalInfoFromJson(json);
      } catch (e) {
        groqError = e.toString();
        // ignore: avoid_print
        print('[ChemicalHub] Groq scan failed: $e');
      }
    } else {
      groqError = 'No Groq API key configured.';
    }

    if (ApiConfig.hasHuggingFaceKey) {
      try {
        final labels =
            await _chemicalHub.classifyChemicalWithHuggingFace(imageFile);
        if (labels.isNotEmpty) {
          final topLabel = (labels.first as Map)['label']?.toString() ?? '';
          if (topLabel.isNotEmpty) {
            return lookupChemicalSafety(topLabel);
          }
        }
        hfError = 'Hugging Face returned no usable labels.';
      } catch (e) {
        hfError = e.toString();
        // ignore: avoid_print
        print('[ChemicalHub] Hugging Face fallback failed: $e');
      }
    } else {
      hfError = 'No Hugging Face API key configured.';
    }

    // Both providers failed — show the ACTUAL reason right in the app
    // instead of a generic message, so you don't need the terminal to
    // debug this on a phone.
    return ChemicalInfo(
      name: 'Scan failed',
      formula: '—',
      hazard: HazardLevel.careful,
      usage: 'Groq error: $groqError',
      firstAid: 'Hugging Face error: $hfError',
    );
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  ChemicalInfo _parseChemicalJson(String raw, {required String fallbackName}) {
    try {
      final cleaned =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return _chemicalInfoFromJson(json);
    } catch (_) {
      return _mockChemicalInfo(fallbackName);
    }
  }

  ChemicalInfo _chemicalInfoFromJson(Map<String, dynamic> json) {
    final hazardStr = (json['hazard'] as String? ?? 'careful').toLowerCase();
    final hazard = switch (hazardStr) {
      'safe' => HazardLevel.safe,
      'hazardous' => HazardLevel.hazardous,
      _ => HazardLevel.careful,
    };
    return ChemicalInfo(
      name: json['name'] as String? ?? 'Unknown Chemical',
      formula: json['formula'] as String? ?? '—',
      hazard: hazard,
      usage: json['usage'] as String? ?? 'No usage info available.',
      firstAid: json['firstAid'] as String? ?? 'Consult the lab supervisor.',
    );
  }

  Future<String> _mockChatbotReply(String message) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final m = message.toLowerCase();

    if (m.contains('library')) {
      return 'The Main Library is in Block A, near the central quadrangle. '
          'Open your Smart Navigation tab and search "Main Library" for directions.';
    }
    if (m.contains('event')) {
      final upcoming = dataService.events;
      if (upcoming.isEmpty) return 'No upcoming events are listed right now.';
      final next = upcoming.first;
      return 'The next campus event is "${next.title}" at ${next.venue}.';
    }
    if (m.contains('attendance')) {
      return 'You can check your attendance percentage on your dashboard, '
          'right under "Today\'s Summary".';
    }
    if (m.contains('fee') || m.contains('fees')) {
      return 'Your fee status is shown on the dashboard. If it says '
          '"Pending", please clear it at the accounts office or check for an SMS reminder.';
    }
    if (m.contains('timetable') || m.contains('schedule')) {
      return 'Your today\'s timetable is shown on the dashboard. Tap "Time Table" for the full weekly schedule.';
    }
    return 'I can help with campus locations, events, attendance, fees, '
        'and your timetable. Could you rephrase your question with one of those topics?\n\n'
        '(Note: no OPENROUTER_API_KEY was supplied at build time, so I\'m running in offline demo mode.)';
  }

  ChemicalInfo _mockChemicalInfo(String name) {
    return ChemicalInfo(
      name: name.isEmpty ? 'Unknown Chemical' : name,
      formula: '—',
      hazard: HazardLevel.careful,
      usage: 'No verified record found for "$name" yet. Treat with standard '
          'lab caution: gloves, goggles, and fume hood where applicable.',
      firstAid: 'If exposure occurs, flush the area with water and contact '
          'the lab supervisor immediately. This is a fallback response — ask '
          'admin to add "$name" to the verified Chemical Hub database.',
    );
  }
}
