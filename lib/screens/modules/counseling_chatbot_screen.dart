import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../services/ai_service.dart';
import '../../models/models.dart';

class CounselingChatbotScreen extends StatefulWidget {
  const CounselingChatbotScreen({super.key});

  @override
  State<CounselingChatbotScreen> createState() => _CounselingChatbotScreenState();
}

class _CounselingChatbotScreenState extends State<CounselingChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  late final AiService _ai;

  @override
  void initState() {
    super.initState();
    _ai = AiService(context.read<CampusDataService>());
    _startSession();
  }

  void _startSession() {
    _messages.clear();
    _messages.add(ChatMessage(
      text: 'Hi there. I\'m CampusCare AI. This is a safe, anonymous, and confidential space. '
          'I am here to listen if you want to talk about stress, mental health, or substance use.',
      fromUser: false,
      time: DateTime.now(),
    ));
  }

  void _clearSession() {
    setState(() {
      _startSession();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session cleared. Your previous messages have been deleted.'),
        backgroundColor: AppColors.safe,
      )
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final history = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(ChatMessage(text: text, fromUser: true, time: DateTime.now()));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    final reply = await _ai.askCounselor(text, history: history);

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: reply, fromUser: false, time: DateTime.now()));
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: AppColors.danger, size: 24),
            SizedBox(width: 8),
            Text('Confidential Counseling', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        actions: [
          TextButton.icon(
            onPressed: _clearSession,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            label: const Text('Clear Session', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              width: double.infinity,
              color: AppColors.warning.withValues(alpha: 0.1),
              child: const Text(
                'This chat is strictly confidential and not saved to any database. Tap "Clear Session" anytime to wipe history.',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
                textAlign: TextAlign.center,
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
                        decoration: InputDecoration(
                          hintText: 'Type securely...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
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
    final isEmergency = text.startsWith('🚨 EMERGENCY:');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.accent,
                child: Icon(Icons.favorite, size: 16, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.primary : (isEmergency ? AppColors.danger : Colors.grey.shade100),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(fromUser ? 20 : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : 20),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: fromUser || isEmergency ? Colors.white : AppColors.textPrimary,
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
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
