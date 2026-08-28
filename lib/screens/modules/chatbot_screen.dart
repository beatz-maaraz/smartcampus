import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../services/ai_service.dart';
import '../../models/models.dart';

/// AI Campus Assistant chatbot — Application Flow §3.2.
/// Backed by OpenRouter (see AiService.askChatbot / ApiConfig).
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  late final AiService _ai;

  @override
  void initState() {
    super.initState();
    _ai = AiService(context.read<CampusDataService>());
    _messages.add(ChatMessage(
      text: 'Hi! I\'m your AI Campus Assistant. Ask me about locations, '
          'timetables, events, attendance or fees.',
      fromUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // Snapshot history before appending the new user message so we send
    // exactly the prior turns as context.
    final history = List<ChatMessage>.from(_messages);

    setState(() {
      _messages
          .add(ChatMessage(text: text, fromUser: true, time: DateTime.now()));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    final reply = await _ai.askChatbot(text, history: history);

    if (!mounted) return;
    setState(() {
      _messages
          .add(ChatMessage(text: reply, fromUser: false, time: DateTime.now()));
      _sending = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: kPad, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryDark,
                    child: Icon(Icons.smart_toy, color: Colors.white, size: 22),
                  ),
                  SizedBox(width: 12),
                  Text('AI Assistant',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
            Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(kPad),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return _bubble('Typing…', fromUser: false, typing: true);
                }
                final m = _messages[i];
                return _bubble(m.text, fromUser: m.fromUser);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask something about campus…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _bubble(String text, {required bool fromUser, bool typing = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryDark,
                child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(fromUser ? 20 : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : 20),
                ),
                boxShadow: [
                  if (!fromUser)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: fromUser ? Colors.white : AppColors.textPrimary,
                  fontStyle: typing ? FontStyle.italic : FontStyle.normal,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (fromUser)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
