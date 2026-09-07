import '../sync/sync_service.dart';

import 'dart:async';

import '../voice/device_command.dart';
import '../voice/speech_service.dart';
import '../family/family_screen.dart';
import '../videos/watch_screen.dart';
import '../memory_passport/passport_screen.dart';
import '../memory_passport/passport_store.dart';
import '../cognition/record_store.dart';
import '../launcher/launcher_bridge.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai/saathi_companion_service.dart';
import '../l10n/app_localizations.dart';
import '../memory_passport/passport.dart';
import 'nebula_animation.dart';

/// The conversational companion screen for "Talk to Saathi".
/// Designed specifically for elderly accessibility: large text, high contrast,
/// easy quick-prompt chips, and a warm, patient voice.
class TalkScreen extends StatefulWidget {
  const TalkScreen({
    super.key,
    required this.passport,
    this.service,
    this.speech,
    this.startListening = false,
    this.openingMessage,
  });

  final Passport passport;
  final SaathiCompanionService? service;
  final SpeechService? speech;
  final bool startListening;
  /// When provided, this message is shown as Saathi's first line and spoken
  /// aloud before listening starts (used for check-in prompts).
  final String? openingMessage;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> with WidgetsBindingObserver {
  late final SaathiCompanionService _service;
  final List<CompanionMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _foreground = true;
  SpeechService? _speech;
  StreamSubscription<String>? _transcripts;
  bool _listening = false;
  bool _voiceBusy = false;
  bool _consent = false;
  bool _voiceConversation = false;
  bool _speaking = false;
  int _voiceEpoch = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SaathiCompanionService();
    _speech = widget.speech;
    _service.initChat(widget.passport, openingMessage: widget.openingMessage);
    WidgetsBinding.instance.addObserver(this);
    if (widget.service == null) {
      _service
          .loadConsent()
          .then((_) {
            if (mounted) setState(() => _consent = _service.router.consent);
          })
          .catchError((Object _) {});
    }

    // Initial greeting or check-in question from Saathi
    final greeting = widget.openingMessage ??
        'Hello ${widget.passport.name}. I am Saathi, your companion. How can I help you today?';
    _messages.add(
      CompanionMessage(
        text: greeting,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    if (widget.startListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Speak the greeting / check-in question aloud before listening.
        try {
          await _speech?.speak(greeting);
        } catch (_) {}
        if (mounted) _toggleVoice();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transcripts?.cancel();
    _voiceConversation = false;
    _voiceEpoch++;
    _speech?.cancelListening();
    _speech?.stopSpeaking();
    if (widget.speech == null) _speech?.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _loading) return;
    final requestVoiceEpoch = _voiceEpoch;

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

    final deviceReply = await _runDeviceCommand(cleanText);
    if (!mounted) return;
    final reply = deviceReply ?? await _service.sendMessage(cleanText);
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
      final action = deviceReply == null ? _service.lastAction : null;
      if (action != null) {
        _endVoice();
        await _navigate(action);
      } else if (_foreground &&
          requestVoiceEpoch == _voiceEpoch &&
          ModalRoute.of(context)?.isCurrent == true &&
          _speech != null) {
        final epoch = _voiceEpoch;
        setState(() => _speaking = true);
        try {
          await _speech!.speak(reply);
        } catch (_) {
          _endVoice();
          if (mounted) {
            _notice('I could not read that aloud. Your reply is on screen.');
          }
        } finally {
          if (mounted) setState(() => _speaking = false);
        }
        if (mounted &&
            _foreground &&
            _voiceConversation &&
            epoch == _voiceEpoch &&
            ModalRoute.of(context)?.isCurrent == true) {
          unawaited(_listenForTurn());
        }
      }
    }
  }

  /// Executes recognised launcher commands locally, before a message can be
  /// sent to Gemini. This keeps phone controls private and predictable.
  Future<String?> _runDeviceCommand(String text) async {
    final commandText = text.trim().toLowerCase();
    if (CompanionRouter.local(commandText, widget.passport).action != null) {
      return null;
    }
    final bridge = LauncherBridge();

    // Parse without apps first for system commands that don't need app list.
    final basic = DeviceCommandParser.parse(commandText, const []);

    if (basic?.type == DeviceCommandType.home) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return 'Going home.';
    }
    if (basic?.type == DeviceCommandType.phone) {
      try {
        await bridge.openDialer();
        return 'Opening Phone.';
      } catch (_) {
        return 'I could not open Phone.';
      }
    }
    if (basic?.type == DeviceCommandType.call) {
      final name = basic!.contactName ?? 'them';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Call $name?'),
          content: Text(
            'Do you want to call $name?',
            style: const TextStyle(fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Call'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await bridge.openDialer();
          return 'Opening Phone to call $name.';
        } catch (_) {
          return 'I could not open Phone.';
        }
      }
      return 'Okay, I will not call $name.';
    }
    if (basic?.type == DeviceCommandType.settings) {
      try {
        await bridge.openSettings();
        return 'Opening Settings.';
      } catch (_) {
        return 'I could not open Settings.';
      }
    }
    if (basic?.type == DeviceCommandType.maps) {
      try {
        await bridge.openMaps();
        return 'Opening Maps.';
      } catch (_) {
        return 'I could not open Maps.';
      }
    }
    if (basic?.type == DeviceCommandType.calendar) {
      try {
        await bridge.openCalendar();
        return 'Opening Calendar.';
      } catch (_) {
        return 'I could not open Calendar.';
      }
    }
    if (basic?.type == DeviceCommandType.contacts) {
      try {
        await bridge.openContacts();
        return 'Opening Contacts.';
      } catch (_) {
        return 'I could not open Contacts.';
      }
    }

    if (!RegExp(r'^(open|start|launch)\s+').hasMatch(commandText)) {
      return null;
    }
    try {
      final apps = await bridge.apps();
      final command = DeviceCommandParser.parse(commandText, apps);
      if (command?.type == DeviceCommandType.app) {
        await bridge.openApp(command!.app!.packageName);
        return 'Opening ${command.app!.label}.';
      }
      // Keep an unrecognised device command local as well. Gemini should not
      // interpret commands aimed at the phone.
      return 'I could not find that app on this phone.';
    } catch (_) {
      return 'I cannot check your phone apps right now.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _endVoice();
    }
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _toggleVoice() async {
    if (_voiceConversation) {
      _endVoice();
      return;
    }
    if (_loading) return;
    _voiceConversation = true;
    _voiceEpoch++;
    await _listenForTurn();
  }

  void _endVoice() {
    _voiceConversation = false;
    _voiceEpoch++;
    _speech?.cancelListening();
    _speech?.stopSpeaking();
    if (mounted) {
      setState(() {
        _listening = false;
        _speaking = false;
        _voiceBusy = false;
      });
    }
  }

  Future<void> _listenForTurn() async {
    if (!mounted ||
        !_foreground ||
        !_voiceConversation ||
        _loading ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final epoch = _voiceEpoch;
    setState(() => _voiceBusy = true);
    try {
      _speech ??= SpeechService();
      _transcripts ??= _speech!.transcripts.stream.listen((text) {
        if (mounted) setState(() => _controller.text = text);
      });
      await _speech!.startListening();
      if (!mounted || epoch != _voiceEpoch) {
        await _speech!.cancelListening();
        return;
      }
      setState(() {
        _listening = true;
        _voiceBusy = false;
      });
      final text = await _speech!.finalTranscript();
      if (!mounted || !_foreground || epoch != _voiceEpoch) return;
      setState(() => _listening = false);
      if (text.trim().isEmpty) {
        _endVoice();
        _notice(
          'Conversation paused. Tap Start voice conversation when you’re ready.',
        );
      } else if (RegExp(
        r'^(stop|stop listening|stop talking|end conversation)[.!]?$',
      ).hasMatch(text.trim().toLowerCase())) {
        _endVoice();
      } else {
        await _sendMessage(text);
      }
    } catch (_) {
      if (mounted) {
        _endVoice();
        _notice('Voice is unavailable. Please use the buttons or keyboard.');
      }
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  Future<void> _syncSettings() async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud backup — caregiver setup'),
        content: const Text(
          'Allow saved Passport text and exercise results to sync to protected cloud storage for this app? Photos and voice recordings stay on the phone. Turning this off stops future uploads; it does not delete existing cloud copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Turn off'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow backup'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      await SyncService.setEnabled(value);
      if (mounted) {
        _notice(value ? 'Cloud backup enabled.' : 'Cloud backup disabled.');
      }
    } catch (_) {
      if (mounted) {
        _notice(
          'Cloud backup is unavailable. Your data remains saved on this phone.',
        );
      }
    }
  }

  Future<void> _onlineSettings() async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Online Saathi — caregiver setup'),
        content: const Text(
          'When enabled, your request and relevant saved facts are sent to Google Gemini. Audio stays on this phone. General questions do not include your Memory Passport. You can turn this off at any time. Gemini may make mistakes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Do not enable'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow online replies'),
          ),
        ],
      ),
    );
    if (value == null) return;
    try {
      await _service.setConsent(value);
      if (mounted) setState(() => _consent = value);
    } catch (_) {
      if (mounted) _notice('Could not save this setting. Please try again.');
    }
  }

  Future<void> _navigate(CompanionAction? action) async {
    if (action == null || !mounted) return;
    final store = PassportStore();
    switch (action) {
      case CompanionAction.family:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => FamilyScreen(
              passport: widget.passport,
              passportStore: store,
              recordStore: RecordStore(),
            ),
          ),
        );
      case CompanionAction.watch:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => WatchScreen(recordStore: RecordStore()),
          ),
        );
      case CompanionAction.passport:
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => PassportScreen(
              store: store,
              onChanged: (p) => _service.initChat(p),
            ),
          ),
        );
      case CompanionAction.apps:
        try {
          final bridge = LauncherBridge();
          final apps = await bridge.apps();
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Phone Apps')),
                body: ListView(
                  children: apps
                      .map(
                        (app) => ElevatedButton(
                          onPressed: () async {
                            try {
                              await bridge.openApp(app.packageName);
                            } catch (_) {
                              if (mounted) _notice('That app is unavailable.');
                            }
                          },
                          child: Text(app.label),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        } catch (_) {
          if (mounted) _notice('Phone Apps are unavailable.');
        }
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
        actions: [
          IconButton(
            onPressed: _endVoice,
            tooltip: 'Stop speaking',
            icon: const Icon(Icons.volume_off),
          ),
          IconButton(
            onPressed: _syncSettings,
            tooltip: 'Caregiver cloud backup',
            icon: const Icon(Icons.cloud_outlined),
          ),
        ],
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
            ValueListenableBuilder<CompanionMode>(
              valueListenable: _service.router.mode,
              builder: (_, mode, child) => Text(
                mode == CompanionMode.checking
                    ? 'Saathi is thinking…'
                    : mode == CompanionMode.online
                    ? 'Gemini Saathi'
                    : 'Saathi',
              ),
            ),
            TextButton(
              onPressed: _onlineSettings,
              child: Text(
                _consent
                    ? 'Gemini replies allowed — change'
                    : 'Enable Gemini — caregiver settings',
              ),
            ),
            NebulaVisualizer(
              isListening: _listening,
              isSpeaking: _speaking,
              isLoading: _loading,
              isVoiceConversation: _voiceConversation,
              voiceBusy: _voiceBusy,
              onToggleVoice: _toggleVoice,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text(
                'Gemini answers questions. Google speech is used for voice input.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            // Chat history list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _MessageBubble(message: msg);
                },
              ),
            ),

            // Thinking animation while waiting for Gemini
            if (_loading) const _ThinkingBubble(),

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
                    onTap: () => _sendMessage(
                      s?.quickPromptFamily ?? 'Tell me about my family',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    label: s?.quickPromptDay ?? 'What is my routine today?',
                    icon: Icons.calendar_today_outlined,
                    onTap: () => _sendMessage(
                      s?.quickPromptDay ?? 'What is my routine today?',
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickChip(
                    label:
                        s?.quickPromptGardening ?? "Let's talk about gardening",
                    icon: Icons.yard_outlined,
                    onTap: () => _sendMessage(
                      s?.quickPromptGardening ?? "Let's talk about gardening",
                    ),
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
                      focusNode: _inputFocus,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: s?.talkPlaceholder ?? 'Ask Saathi anything…',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF185A49),
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF185A49),
                            width: 2.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
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

/// Animated "Saathi is thinking" bubble with three pulsing dots.
/// Shown in the chat list while waiting for a Gemini reply.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, left: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFFE2DFD2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (_, _a) {
                // Stagger each dot by 0.2 of the cycle
                final phase = (_controller.value - i * 0.2).clamp(0.0, 1.0);
                final opacity = (1 - (2 * phase - 1).abs()).clamp(0.2, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(24, 90, 73, opacity),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
