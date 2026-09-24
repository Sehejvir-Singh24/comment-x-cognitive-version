import 'dart:async';

import 'sync/sync_service.dart';

import 'package:flutter/material.dart';

import 'cognition/record_store.dart';
import 'context/action_context.dart';
import 'context/context_signals_screen.dart';
import 'cognition/cognitive_games_screen.dart';
import 'cognition/cognitive_record.dart';
import 'caregiver/caregiver_dashboard_screen.dart';
import 'family/family_screen.dart';
import 'videos/watch_screen.dart';
import 'l10n/app_localizations.dart';
import 'launcher/launcher_bridge.dart';
import 'memory_passport/passport.dart';
import 'memory_passport/passport_screen.dart';
import 'memory_passport/passport_store.dart';
import 'medicine/medicine_screen.dart';
import 'medicine/reminder_bridge.dart';
import 'my_day/my_day_screen.dart';
import 'talk/talk_screen.dart';
import 'voice/speech_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CompanionApp());
  SyncService.initialize().catchError((Object _) {});
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF185A49)),
      scaffoldBackgroundColor: const Color(0xFFF7F5EF),
      textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 20)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(80),
          padding: const EdgeInsets.all(20),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    ),
    home: const LauncherHome(),
  );
}

class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});
  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome>
    with WidgetsBindingObserver {
  final bridge = LauncherBridge();
  final passportStore = PassportStore();
  final recordStore = RecordStore();
  late final SpeechService _voice;
  Timer? _checkInTimer;
  Passport? passport;
  bool defaultHome = false;
  bool busy = false;
  bool _foreground = true;
  String? _checkInQuestion;
  String? _welcomeMessage;
  int _checkInIndex = 0;
  bool _greeted = false;
  bool _remoteCheckupOpen = false;
  bool _shareDialogOpen = false;
  DateTime? _lastHomeLogAt;

  void _logReturnHome() {
    final now = DateTime.now();
    if (_lastHomeLogAt != null &&
        now.difference(_lastHomeLogAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastHomeLogAt = now;
    unawaited(
      ActionContext.log(
        'RETURN_HOME',
        source: 'launcher',
      ).catchError((Object _) {}),
    );
  }

  @override
  void initState() {
    super.initState();
    _voice = SpeechService();
    unawaited(_voice.initialize().catchError((Object _) {}));
    _startCheckIns();
    WidgetsBinding.instance.addObserver(this);
    LauncherBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'homePressed' && mounted) {
        LauncherBridge.homeRequests.value++;
        _logReturnHome();
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          refreshPassport();
        }
      }
    });
    refresh();
    refreshPassport();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkSharedLink());
    });
    unawaited(
      SyncService.startPassportListener(
        onPassportUpdated: (updated) {
          if (mounted) {
            setState(() => passport = updated);
            _welcome(updated);
          }
        },
      ),
    );
    unawaited(
      SyncService.startCheckupListener(onCheckupRequested: _openRemoteCheckup),
    );
  }

  Future<void> _openRemoteCheckup(RemoteCheckupCommand command) async {
    if (!mounted || _remoteCheckupOpen) return;
    if (passport == null) await refreshPassport();
    final currentPassport = passport;
    if (!mounted || currentPassport == null) return;

    _remoteCheckupOpen = true;
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
      await _voice.speak(
        'Your caregiver has sent a short memory checkup. Let us play together.',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CognitiveGamesScreen(
            passport: currentPassport,
            recordStore: recordStore,
            speechService: _voice,
            onCompleted: (correct, total) => SyncService.completeCheckupCommand(
              command.id,
              correct: correct,
              total: total,
            ),
          ),
        ),
      );
    } finally {
      _remoteCheckupOpen = false;
    }
  }

  Future<void> refreshPassport() async {
    try {
      final value = await passportStore.load();
      await ReminderBridge.schedule(value);
      if (mounted) {
        setState(() => passport = value);
        _welcome(value);
      }
    } catch (_) {
      // Launcher remains usable; Memory Passport displays storage errors.
    }
  }

  @override
  void dispose() {
    unawaited(SyncService.stopPassportListener());
    unawaited(SyncService.stopCheckupListener());
    WidgetsBinding.instance.removeObserver(this);
    LauncherBridge.channel.setMethodCallHandler(null);
    _checkInTimer?.cancel();
    _voice.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_checkSharedLink());
      _logReturnHome();
      refresh();
      _startCheckIns();
      SyncService.pullPassport(
        onPassportUpdated: (updated) {
          if (mounted) {
            setState(() => passport = updated);
          }
        },
      );
    } else {
      _checkInTimer?.cancel();
    }
  }

  void _startCheckIns() {
    _checkInTimer?.cancel();
    _checkInTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _askCheckInQuestion(),
    );
  }

  Future<void> _askCheckInQuestion() async {
    if (!mounted || !_foreground || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (passport == null) return;
    const questions = [
      'Would you like to do a short memory question?',
      'What would you like to do next?',
      'Would you like to talk about family or a favourite memory?',
    ];
    final question = questions[_checkInIndex++ % questions.length];
    setState(() => _checkInQuestion = question);
    await _openTalk('Saathi check-in. $question');
  }

  Future<void> _openTalk([String? openingMessage]) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TalkScreen(
            passport: passport!,
            speech: _voice,
            startListening: true,
            openingMessage: openingMessage,
          ),
        ),
      );

  String _passportQuestion(Passport value) {
    final routine = value.entries.where(
      (entry) => entry.kind == MemoryKind.routine,
    );
    if (routine.isNotEmpty) {
      return 'I remember ${routine.first.name}. Would you like to talk about it?';
    }
    final family = value.entries.where(
      (entry) => entry.kind == MemoryKind.family,
    );
    if (family.isNotEmpty) {
      return 'Would you like to tell me about ${family.first.name}?';
    }
    final place = value.entries.where(
      (entry) => entry.kind == MemoryKind.place,
    );
    if (place.isNotEmpty) {
      return 'Would you like to talk about ${place.first.name}?';
    }
    return 'Would you like to add a favourite memory to your Memory Passport?';
  }

  void _welcome(Passport value) {
    if (_greeted) return;
    _greeted = true;
    final greeting = DateTime.now().hour < 12
        ? 'Good morning'
        : DateTime.now().hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final message =
        '$greeting, ${value.name}. How are you feeling today? ${_passportQuestion(value)} What would you like to do? You can tell me which app to open.';
    setState(() => _welcomeMessage = message);
    _voice.speak(message).catchError((Object _) {});
  }

  Future<void> refresh() async {
    try {
      final value = await bridge.isDefaultHome();
      if (mounted) setState(() => defaultHome = value);
    } catch (_) {
      if (mounted) setState(() => defaultHome = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void upcoming(String title) {
    final strings = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(strings.comingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.backHome),
          ),
        ],
      ),
    );
  }

  Future<void> showApps() async {
    final apps = await bridge.apps();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final strings = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(strings.phoneApps)),
            body: apps.isEmpty
                ? Center(child: Text(strings.noApps))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: apps.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => ElevatedButton(
                      onPressed: () async {
                        try {
                          final app = apps[index];
                          final appLabel = app.label.toLowerCase();
                          final askPurpose =
                              appLabel.contains('youtube') ||
                              appLabel.contains('whatsapp') ||
                              appLabel.contains('music');
                          final purpose = askPurpose
                              ? await showDialog<String>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(
                                      'What would you like to do in ${app.label}?',
                                    ),
                                    content: const Text(
                                      'Choose a reason if you remember. Saathi can remind you later.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, ''),
                                        child: const Text('Just open it'),
                                      ),
                                      if (appLabel.contains('whatsapp'))
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            'send a message',
                                          ),
                                          child: const Text('Send a message'),
                                        ),
                                      if (appLabel.contains('youtube'))
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            'watch an exercise video',
                                          ),
                                          child: const Text(
                                            'Watch exercise video',
                                          ),
                                        ),
                                      if (appLabel.contains('music'))
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            dialogContext,
                                            'listen to music',
                                          ),
                                          child: const Text('Listen to music'),
                                        ),
                                    ],
                                  ),
                                )
                              : '';
                          if (purpose == null) return;
                          if (purpose.isNotEmpty) {
                            await ActionContext.log(
                              'APP_INTENT',
                              source: 'launcher',
                              appPackage: app.packageName,
                              appName: app.label,
                              intent: purpose,
                            ).catchError((Object _) {});
                          }
                          await bridge.openApp(apps[index].packageName);
                          unawaited(
                            ActionContext.log(
                              'APP_OPEN',
                              source: 'launcher',
                              appPackage: app.packageName,
                              appName: app.label,
                              intent: purpose.isEmpty ? null : purpose,
                            ).catchError((Object _) {}),
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.actionFailed)),
                            );
                          }
                        }
                      },
                      child: Text(apps[index].label),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Future<void> _showContext() async {
    if (!await ActionContext.enabled()) {
      if (!mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Let Saathi remember phone actions?'),
          content: const Text(
            'Saathi can remember apps you open from this launcher, purposes you choose, and simple My Day actions. This stays on this phone. It does not read messages or record your words. History is kept for up to 30 days or 500 actions. You can turn it off and clear it here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remember my actions'),
            ),
          ],
        ),
      );
      if (allow != true) return;
      await ActionContext.setEnabled(true);
    }
    final events = await ActionContext.recent();
    final explanation = ActionContext.explain(events);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Why am I here?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(explanation.text, style: const TextStyle(fontSize: 22)),
            if (explanation.repeated) ...[
              const SizedBox(height: 12),
              Text(
                'You opened ${explanation.appName} several times recently. Would you like to continue there?',
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Why Saathi thinks this',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(explanation.evidence),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ActionContext.setEnabled(false);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Turn off and clear history'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Stay here'),
          ),
          if (explanation.appPackage != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await bridge.openApp(explanation.appPackage!);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('That app could not open.')),
                    );
                  }
                }
              },
              child: Text('Take me back to ${explanation.appName}'),
            ),
          if (explanation.webLink != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await bridge.openWebLink(explanation.webLink!);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('That link could not open.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Take me back to the link'),
            ),
        ],
      ),
    );
  }

  Future<void> _showBreadcrumbs() async {
    final events = await ActionContext.recent();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Memory Breadcrumbs')),
          body: events.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No recent actions saved yet.'),
                  ),
                )
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (_, index) => ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(ActionContext.breadcrumb(events[index])),
                    subtitle: Text(
                      '${events[index].timestamp.hour.toString().padLeft(2, '0')}:${events[index].timestamp.minute.toString().padLeft(2, '0')} · Saved on this phone',
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _checkSharedLink() async {
    if (!mounted || _shareDialogOpen) return;
    String? shared;
    try {
      shared = await bridge.consumeShare();
    } catch (_) {
      return;
    }
    if (!mounted || shared == null || shared.isEmpty) return;
    final match = RegExp(r'https?://[^\s]+').firstMatch(shared);
    final url = match?.group(0)?.replaceAll(RegExp(r'[.,;!?)]+$'), '');
    if (url == null || Uri.tryParse(url)?.host.isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saathi can save web links only. Shared text was not stored.',
          ),
        ),
      );
      return;
    }
    _shareDialogOpen = true;
    try {
      Navigator.of(context).popUntil((route) => route.isFirst);
      final enabled = await ActionContext.enabled();
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save this shared link?'),
          content: Text(
            'Saathi received this one link:\n$url\n\nIt stays on this phone. Saathi cannot read the message or conversation it came from.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Do not save'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                enabled ? 'Save link' : 'Enable action memory and save',
              ),
            ),
          ],
        ),
      );
      if (save == true) {
        if (!enabled) {
          await ActionContext.setEnabled(true);
        }
        await ActionContext.log('SHARED_LINK', source: 'share', action: url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link saved. Ask “Why am I here?” to reopen it.'),
            ),
          );
        }
      }
    } finally {
      _shareDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? s.goodMorning
        : hour < 17
        ? s.goodAfternoon
        : s.goodEvening;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF153F34),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 42,
                        backgroundColor: Color(0xFFE8F0EC),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF153F34),
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saathi is here with you',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _welcomeMessage ??
                            '$greeting, ${passport?.name ?? s.demoName}.',
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.35,
                          color: Color(0xFFF7F5EF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── SOS emergency button ─────────────────────────────────
                const SizedBox(height: 4),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(72),
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Call for help?'),
                        content: const Text(
                          'This will open the phone dialler. Call someone who can help you.',
                          style: TextStyle(fontSize: 18),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Call now'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      try {
                        await bridge.openDialer();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open Phone.'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.emergency_outlined, size: 32),
                  label: const Text('SOS — Call for help'),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(108),
                    textStyle: const TextStyle(fontSize: 26),
                  ),
                  onPressed: passport == null ? null : _openTalk,
                  icon: const Icon(Icons.mic, size: 40),
                  label: const Text('Speak to Saathi'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Say "Open WhatsApp", "Open Maps", or ask Saathi a question.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.grey[800]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => perform(_showContext),
                  icon: const Icon(Icons.help_outline, size: 30),
                  label: const Text('Why am I here?'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => perform(_showBreadcrumbs),
                  icon: const Icon(Icons.history, size: 30),
                  label: const Text('Memory Breadcrumbs'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ContextSignalsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.phonelink_setup, size: 30),
                  label: const Text('Optional phone context'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(72),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: busy ? null : () => perform(showApps),
                  icon: const Icon(Icons.apps, size: 30),
                  label: const Text('Choose an app'),
                ),
                const SizedBox(height: 24),
                if (_checkInQuestion != null)
                  Card(
                    color: const Color(0xFFE8F0EC),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Saathi check-in',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(_checkInQuestion!),
                          TextButton.icon(
                            onPressed: passport == null
                                ? null
                                : () => _openTalk(
                                    _checkInQuestion != null
                                        ? 'Saathi check-in. $_checkInQuestion'
                                        : null,
                                  ),
                            icon: const Icon(Icons.mic),
                            label: const Text('Answer Saathi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ── Memory Games (Brain Gym) Card ────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(
                      color: Color(0xFF185A49),
                      width: 1.5,
                    ),
                  ),
                  color: const Color(0xFFF1F8F5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: passport == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CognitiveGamesScreen(
                                passport: passport!,
                                recordStore: recordStore,
                              ),
                            ),
                          ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFF185A49),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.psychology_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Memory Games & Brain Gym',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF153F34),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Medicine, family photos, and routine recall quiz',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFF185A49),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: const Color(0xFFFFF4DD),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.landscape,
                      size: 40,
                      color: Color(0xFF185A49),
                    ),
                    title: const Text(
                      'North-East Memories',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text('Places, textiles and Bihu sounds'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: passport == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CognitiveGamesScreen(
                                passport: passport!,
                                recordStore: recordStore,
                                initialKind: RecordKind.culturalRecall,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'More ways Saathi can help',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // ── 2×3 grid of feature tiles ────────────────────────────
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: [
                    _HomeTile(
                      icon: Icons.book_outlined,
                      label: s.passport,
                      color: const Color(0xFF185A49),
                      enabled: passport != null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PassportScreen(
                            store: passportStore,
                            onChanged: (value) {
                              if (mounted) setState(() => passport = value);
                            },
                          ),
                        ),
                      ),
                    ),
                    _HomeTile(
                      icon: Icons.play_circle_outline,
                      label: s.watch,
                      color: const Color(0xFF1A6B5A),
                      enabled: passport != null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WatchScreen(recordStore: recordStore),
                        ),
                      ),
                    ),
                    _HomeTile(
                      icon: Icons.people_outline,
                      label: s.family,
                      color: const Color(0xFF2E7D6B),
                      enabled: passport != null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FamilyScreen(
                            passport: passport!,
                            passportStore: passportStore,
                            recordStore: recordStore,
                          ),
                        ),
                      ),
                    ),
                    _HomeTile(
                      icon: Icons.medication_outlined,
                      label: s.medicine,
                      color: const Color(0xFF3D6B8C),
                      enabled: passport != null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MedicineScreen(
                            passport: passport!,
                            recordStore: recordStore,
                          ),
                        ),
                      ),
                    ),
                    _HomeTile(
                      icon: Icons.today_outlined,
                      label: s.myDay,
                      color: const Color(0xFF5C6A3D),
                      enabled: passport != null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MyDayScreen(passport: passport!),
                        ),
                      ),
                    ),
                    _HomeTile(
                      icon: Icons.call_outlined,
                      label: s.phone,
                      color: const Color(0xFF6B3D5C),
                      enabled: true,
                      onTap: () => perform(bridge.openDialer),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (passport == null)
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PassportScreen(
                            store: passportStore,
                            onChanged: (value) =>
                                setState(() => passport = value),
                          ),
                        ),
                      );
                      await refreshPassport();
                    },
                    child: const Text(
                      'Open Memory Passport to check saved data',
                    ),
                  ),
                // ── Caregiver dashboard link + set-home ──────────────────
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                  onPressed: passport == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CaregiverDashboardScreen(
                              passport: passport!,
                              recordStore: recordStore,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.insights_outlined, size: 28),
                  label: const Text('Caregiver dashboard'),
                ),
                const SizedBox(height: 16),
                Text(defaultHome ? s.homeEnabled : s.homeNotEnabled),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                  ),
                  onPressed: busy ? null : () => perform(bridge.requestHome),
                  child: Text(s.chooseHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A large square tile used in the home screen feature grid.
/// Elderly-friendly: big icon, bold label, coloured background.
class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : color.withAlpha(100),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
