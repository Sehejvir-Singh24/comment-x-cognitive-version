import 'package:flutter/material.dart';

import '../ai/saathi_companion_service.dart';
import '../l10n/app_localizations.dart';
import '../memory_passport/passport.dart';

/// The conversational companion screen for "Talk to Saathi".
/// Designed specifically for elderly accessibility: large text, high contrast,
/// easy quick-prompt chips, and a warm, patient voice.
class TalkScreen extends StatefulWidget {
  const TalkScreen({
    super.key,
    required this.passport,
    this.service,
  });

  final Passport passport;
  final SaathiCompanionService? service;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  late final SaathiCompanionService _service;
  final List<CompanionMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SaathiCompanionService();
    _service.initChat(widget.passport);

    // Initial greeting from Saathi
    _messages.add(
      CompanionMessage(
        text: 'Hello ${widget.passport.name}. I am Saathi, your companion. How can I help you today?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _loading) return;

    _controller.clear();
    setState(() {
      _messages.add(
        CompanionMessage(
          text: cleanText,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _loading = true;
    });
    _scrollToBottom();

    final reply = await _service.sendMessage(cleanText);

    if (mounted) {
      setState(() {
        _messages.add(
          CompanionMessage(
            text: reply,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s?.talk ?? 'Talk to Saathi',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(
              s?.talkSubtitle ?? 'Your personal memory companion',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF185A49),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat history list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _MessageBubble(message: msg);
                },
              ),
            ),

            // Loading indicator
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      s?.saathiThinking ?? 'Saathi is thinking…',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                        color: Color(0xFF185A49),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick suggestion chips (Elderly touch friendly)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _QuickChip(
                    label: s?.quickPromptFamily ?? 'Tell me about my family',
                    icon: Icons.people_outline,
                    onTap: () => _sendMessage(s?.quickPromptFamily ?? 'Tell me about my family'),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    label: s?.quickPromptDay ?? 'What is my routine today?',
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _sendMessage(s?.quickPromptDay ?? 'What is my routine today?'),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    label: s?.quickPromptGardening ?? "Let's talk about gardening",
                    icon: Icons.yard_outlined,
                    onTap: () => _sendMessage(s?.quickPromptGardening ?? "Let's talk about gardening"),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Input bar with large touch targets
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: s?.talkPlaceholder ?? 'Ask Saathi anything…',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF185A49), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF185A49), width: 2.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185A49),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _sendMessage(_controller.text),
                      child: const Icon(Icons.send, size: 28),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final CompanionMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF185A49) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: isUser ? null : Border.all(color: const Color(0xFFE2DFD2)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 20,
            height: 1.4,
            fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
            color: isUser ? Colors.white : const Color(0xFF232B2B),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: const Color(0xFF185A49), size: 20),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF185A49),
        ),
      ),
      backgroundColor: const Color(0xFFE8F0EC),
      side: const BorderSide(color: Color(0xFFB5D3C7)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: onTap,
    );
  }
}
