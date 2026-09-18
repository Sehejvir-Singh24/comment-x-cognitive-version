import 'package:flutter/material.dart';

import '../launcher/launcher_bridge.dart';
import 'action_context.dart';

/// Optional Android signals remain separate from Saathi's local action memory.
class ContextSignalsScreen extends StatefulWidget {
  const ContextSignalsScreen({super.key});
  @override
  State<ContextSignalsScreen> createState() => _ContextSignalsScreenState();
}

class _ContextSignalsScreenState extends State<ContextSignalsScreen>
    with WidgetsBindingObserver {
  final _bridge = LauncherBridge();
  bool _usageGranted = false;
  bool _notificationsGranted = false;
  bool _usageEnabled = false;
  bool _notificationsEnabled = false;
  bool _actionMemoryEnabled = false;
  List<Map<String, dynamic>> _previews = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final actionMemory = await ActionContext.enabled();
      final usageGranted = await _bridge.usageAccessGranted();
      final notificationsGranted = await _bridge.notificationAccessGranted();
      final usageEnabled = await ActionContext.usageEnabled();
      final notificationsEnabled = await ActionContext.notificationEnabled();
      final previews = notificationsEnabled && notificationsGranted
          ? await _bridge.notificationPreviews()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _actionMemoryEnabled = actionMemory;
        _usageGranted = usageGranted;
        _notificationsGranted = notificationsGranted;
        _usageEnabled = usageEnabled;
        _notificationsEnabled = notificationsEnabled;
        _previews = previews;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Android context settings are unavailable.'),
          ),
        );
      }
    }
  }

  Future<void> _toggleUsage() async {
    if (!_actionMemoryEnabled) return;
    if (_usageEnabled) {
      await ActionContext.setUsageEnabled(false);
      await _load();
      return;
    }
    if (!_usageGranted) {
      await _bridge.openUsageAccessSettings();
      return;
    }
    await ActionContext.setUsageEnabled(true);
    await _load();
  }

  Future<void> _toggleNotifications() async {
    if (!_actionMemoryEnabled) return;
    if (_notificationsEnabled) {
      await ActionContext.setNotificationEnabled(false);
      await _load();
      return;
    }
    if (!_notificationsGranted) {
      await _bridge.openNotificationAccessSettings();
      return;
    }
    await ActionContext.setNotificationEnabled(true);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Optional phone context')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'These signals stay on this phone. Saathi uses them as evidence, not as proof of why you acted. They are not sent to the caregiver.',
          style: TextStyle(fontSize: 18),
        ),
        if (!_actionMemoryEnabled)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'First enable local action memory from “Why am I here?” on the home screen.',
            ),
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App usage timing',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Shows when another app was in the foreground. It cannot read what you did inside the app.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _actionMemoryEnabled ? _toggleUsage : null,
                  child: Text(
                    _usageEnabled
                        ? 'Turn off usage timing'
                        : !_usageGranted
                        ? 'Grant usage access in Android settings'
                        : 'Enable usage timing',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WhatsApp notification previews',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Only notifications posted after you enable this are kept for up to 24 hours. No chat history is read.',
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _actionMemoryEnabled ? _toggleNotifications : null,
                  child: Text(
                    _notificationsEnabled
                        ? 'Turn off and clear previews'
                        : !_notificationsGranted
                        ? 'Grant Notification Access in Android settings'
                        : 'Enable notification previews',
                  ),
                ),
                if (_notificationsEnabled && _previews.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Recent previews on this phone',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ..._previews
                      .take(5)
                      .map(
                        (item) => ListTile(
                          title: Text('WhatsApp: ${item['sender']}'),
                          subtitle: Text(item['preview'] as String? ?? ''),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Share a web link to Saathi from another app to save that one link. Saathi asks before storing it and never reads the conversation it came from.',
            ),
          ),
        ),
      ],
    ),
  );
}
