import 'sync/sync_service.dart';

import 'package:flutter/material.dart';

import 'cognition/record_store.dart';
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
  Passport? passport;
  bool defaultHome = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LauncherBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'homePressed' && mounted) {
        LauncherBridge.homeRequests.value++;
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          refreshPassport();
        }
      }
    });
    refresh();
    refreshPassport();
  }

  Future<void> refreshPassport() async {
    try {
      final value = await passportStore.load();
      await ReminderBridge.schedule(value);
      if (mounted) setState(() => passport = value);
    } catch (_) {
      // Launcher remains usable; Memory Passport displays storage errors.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LauncherBridge.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
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
                          await bridge.openApp(apps[index].packageName);
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
                Text(
                  s.appTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$greeting,\n${passport?.name ?? s.demoName}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF153F34),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (passport?.isDemo ?? true) ? s.demoPassport : s.savedPassport,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(96),
                    textStyle: const TextStyle(fontSize: 26),
                  ),
                  onPressed: passport == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TalkScreen(passport: passport!),
                          ),
                        ),
                  icon: const Icon(Icons.mic_none, size: 36),
                  label: Text(s.talk),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: passport == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PassportScreen(
                              store: passportStore,
                              onChanged: (value) {
                                if (mounted) setState(() => passport = value);
                              },
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.book_outlined, size: 32),
                  label: Text(s.passport),
                ),
                const SizedBox(height: 12),
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
                // Watch — Video Recall (this increment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: passport == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  WatchScreen(recordStore: recordStore),
                            ),
                          ),
                    icon: const Icon(Icons.play_circle_outline, size: 32),
                    label: Text(s.watch),
                  ),
                ),
                // Family — Family Recognition (this increment)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: passport == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FamilyScreen(
                                passport: passport!,
                                passportStore: passportStore,
                                recordStore: recordStore,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.people_outline, size: 32),
                    label: Text(s.family),
                  ),
                ),
                // Photos — placeholder
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: () => upcoming(s.photos),
                    icon: const Icon(Icons.photo_outlined, size: 32),
                    label: Text(s.photos),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: passport == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MedicineScreen(
                                passport: passport!,
                                recordStore: recordStore,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.medication_outlined, size: 32),
                    label: Text(s.medicine),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    onPressed: passport == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MyDayScreen(passport: passport!),
                            ),
                          ),
                    icon: const Icon(Icons.today_outlined, size: 32),
                    label: Text(s.myDay),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: busy ? null : () => perform(bridge.openDialer),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(s.phone),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: busy ? null : () => perform(showApps),
                  icon: const Icon(Icons.apps),
                  label: Text(s.phoneApps),
                ),
                const SizedBox(height: 24),
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
