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

  static const String _counselingSystemPrompt = '''
You are 'CampusCare AI', an empathetic, non-judgmental, and highly confidential substance abuse and mental health awareness counselor for college students. 

Your goals:
1. Provide a safe space for students struggling with drug or alcohol addiction.
2. Educate students on the physiological and psychological impacts of substance abuse using scientifically accurate data.
3. Encourage harm reduction, seeking professional help, and healthy coping mechanisms.

Strict Rules:
- NEVER judge, shame, or lecture the student. Use a supportive, warm, and conversational tone.
- NEVER prescribe medication, give medical diagnoses, or encourage illegal activities.
- NEVER ask for the student's real name, roll number, or personal identifiers.
- Keep your responses concise (1-2 paragraphs max) so it feels like a real chat.
- If a user asks a question unrelated to mental health, counseling, or substance abuse, politely guide them back to your purpose.
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

  // ---------------------------------------------------------------------
  // 1b. Counseling Chatbot (OpenRouter)
  // ---------------------------------------------------------------------

  Future<String> askCounselor(String userMessage,
      {List<ChatMessage> history = const []}) async {
      
    // 1. Emergency Redirection Check
    final lowerMessage = userMessage.toLowerCase();
    const emergencyKeywords = ["suicide", "kill myself", "die", "overdose", "end it all"];
    final isEmergency = emergencyKeywords.any((k) => lowerMessage.contains(k));
    
    if (isEmergency) {
      return "🚨 EMERGENCY: It sounds like you are going through a very difficult time. Please reach out for immediate help. Call the Campus Emergency Helpline at +1-800-CAMPUS or the Crisis Lifeline at 988 right away. Your life matters.";
    }

    if (!ApiConfig.hasOpenRouterKey) {
      return _mockCounselorReply(userMessage);
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _counselingSystemPrompt},
      for (final m in history)
        {'role': m.fromUser ? 'user' : 'assistant', 'content': m.text},
      {'role': 'user', 'content': userMessage},
    ];

    try {
      return await _openRouter.sendMessage(messages: messages);
    } catch (e) {
      return 'Sorry, I am currently unavailable. Please try again later.';
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

  Future<String> _mockCounselorReply(String message) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final m = message.toLowerCase();

    if (m.contains('alcohol') || m.contains('drink')) {
      return 'Alcohol can have significant impacts on your academic performance and mental health. It\'s important to understand your limits. Have you been feeling pressured to drink?';
    }
    if (m.contains('drug') || m.contains('weed') || m.contains('smoke')) {
      return 'Substance use often starts as a coping mechanism, but it can quickly escalate. I am here to listen without judgment. Do you want to talk about what\'s been going on?';
    }
    if (m.contains('help') || m.contains('stress')) {
      return 'College can be incredibly stressful, and it takes courage to ask for help. We have campus counselors available for completely free, confidential sessions. Would you like me to share their contact info?';
    }
    
    return 'I am CampusCare AI, a confidential space to talk about mental health, stress, or substance use. How are you feeling today?\n\n'
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

  Future<String> getEmergencyGuidance(String severityType) async {
    final prompt = 'A student has triggered an emergency alarm for type: $severityType. Please provide exactly 3-4 bullet points of immediate first-response safety guidance or first aid steps they should follow while campus security and faculty are en route. Keep it extremely concise, clear, and actionable.';
    if (!ApiConfig.hasOpenRouterKey) {
      return _getMockGuidance(severityType);
    }
    try {
      final response = await _openRouter.sendMessage(messages: [
        {'role': 'system', 'content': 'You are a campus safety first-responder bot. Give concise, actionable safety steps.'},
        {'role': 'user', 'content': prompt},
      ]);
      return response;
    } catch (_) {
      return _getMockGuidance(severityType);
    }
  }

  String _getMockGuidance(String type) {
    switch (type.toLowerCase()) {
      case 'medical':
        return '• Remain calm and do not move if severely injured.\n• Apply pressure to any bleeding wounds using clean cloth.\n• If breathing is difficult, try to sit upright.\n• Stay in place; security and medical staff are en route.';
      case 'fire':
        return '• Evacuate the room immediately if there is smoke or flame.\n• Stay low to the ground to avoid inhaling smoke.\n• Do not use elevators; use nearest stairwell to exit.\n• Assemble in the designated outdoor safety zone.';
      case 'threat':
        return '• Find a secure room and lock/barricade the door.\n• Turn off lights and silence your mobile phone.\n• Keep low, hide behind solid objects, and stay quiet.\n• Do not open the door unless identity of security is confirmed.';
      default:
        return '• Move to a safe, well-lit public area if possible.\n• Stay calm and alert; help is on the way.\n• Keep your mobile phone active for location sharing.\n• Avoid confronting any source of danger.';
    }
  }
}
