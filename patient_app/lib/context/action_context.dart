import 'dart:math';

import '../storage/app_database.dart';
import '../launcher/launcher_bridge.dart';

class ActionEvent {
  const ActionEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.source,
    this.appPackage,
    this.appName,
    this.action,
    this.intent,
  });

  final String id;
  final DateTime timestamp;
  final String type;
  final String source;
  final String? appPackage;
  final String? appName;
  final String? action;
  final String? intent;

  factory ActionEvent.fromRow(Map<String, dynamic> row) => ActionEvent(
    id: row['id'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
    type: row['eventType'] as String,
    source: row['source'] as String,
    appPackage: row['appPackage'] as String?,
    appName: row['appName'] as String?,
    action: row['action'] as String?,
    intent: row['intent'] as String?,
  );
}

class ContextExplanation {
  const ContextExplanation({
    required this.text,
    required this.evidence,
    this.appPackage,
    this.appName,
    this.repeated = false,
    this.webLink,
  });

  final String text;
  final String evidence;
  final String? appPackage;
  final String? appName;
  final bool repeated;
  final String? webLink;
}

class ActionContext {
  static final Random _random = Random.secure();

  static Future<bool> enabled() => AppDatabase.use(
    null,
    (db) async => await db.setting('contextConsent') == 'yes',
  );

  static Future<void> setEnabled(bool value) => AppDatabase.use(
    null,
    (db) => db.transaction(() async {
      await db.setSetting('contextConsent', value ? 'yes' : 'no');
      if (!value) await db.customStatement('DELETE FROM action_events');
      if (!value) {
        await db.setSetting('usageConsent', 'no');
        await db.setSetting('notificationConsent', 'no');
        await LauncherBridge().setNotificationCapture(false);
      }
    }),
  );

  static Future<bool> usageEnabled() => AppDatabase.use(
    null,
    (db) async => await db.setting('usageConsent') == 'yes',
  );
  static Future<bool> notificationEnabled() => AppDatabase.use(
    null,
    (db) async => await db.setting('notificationConsent') == 'yes',
  );

  static Future<void> setUsageEnabled(bool value) => AppDatabase.use(
    null,
    (db) => db.transaction(() async {
      await db.setSetting('usageConsent', value ? 'yes' : 'no');
      if (value) {
        await db.setSetting(
          'lastUsageAt',
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } else {
        await db.customStatement(
          "DELETE FROM action_events WHERE event_type = 'APP_FOREGROUND'",
        );
      }
    }),
  );

  static Future<void> setNotificationEnabled(bool value) async {
    await LauncherBridge().setNotificationCapture(value);
    await AppDatabase.use(
      null,
      (db) => db.transaction(() async {
        await db.setSetting('notificationConsent', value ? 'yes' : 'no');
        if (value) {
          await db.setSetting(
            'lastNotificationAt',
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
        } else {
          await db.customStatement(
            "DELETE FROM action_events WHERE event_type = 'NOTIFICATION'",
          );
        }
      }),
    );
  }

  static Future<void> collectOptionalSignals() async {
    if (!await enabled()) return;
    final bridge = LauncherBridge();
    if (await usageEnabled() && await bridge.usageAccessGranted()) {
      final signals = await bridge.recentUsage();
      await AppDatabase.use(null, (db) async {
        final after =
            int.tryParse(await db.setting('lastUsageAt') ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
        var newest = after;
        for (final signal in signals) {
          final time = (signal['timestamp'] as num).toInt();
          if (time <= after || time > DateTime.now().millisecondsSinceEpoch) {
            continue;
          }
          final packageName = signal['packageName'] as String;
          await db.logActionEvent(
            id: 'usage-$time-$packageName',
            timestamp: time,
            eventType: 'APP_FOREGROUND',
            source: 'usage',
            appPackage: packageName,
            appName: signal['appName'] as String?,
          );
          if (time > newest) newest = time;
        }
        await db.setSetting('lastUsageAt', newest.toString());
      });
    }
    if (await notificationEnabled() &&
        await bridge.notificationAccessGranted()) {
      final signals = await bridge.notificationPreviews();
      await AppDatabase.use(null, (db) async {
        final after =
            int.tryParse(await db.setting('lastNotificationAt') ?? '') ??
            DateTime.now().millisecondsSinceEpoch;
        var newest = after;
        for (final signal in signals) {
          final time = (signal['timestamp'] as num).toInt();
          if (time <= after || time > DateTime.now().millisecondsSinceEpoch) {
            continue;
          }
          final sender = signal['sender'] as String? ?? '';
          await db.logActionEvent(
            id: 'notification-$time-${sender.hashCode}',
            timestamp: time,
            eventType: 'NOTIFICATION',
            source: 'notification',
            appPackage: signal['packageName'] as String?,
            appName: 'WhatsApp',
            action: sender.isEmpty ? null : sender,
          );
          if (time > newest) newest = time;
        }
        await db.setSetting('lastNotificationAt', newest.toString());
      });
    }
  }

  static Future<void> log(
    String type, {
    String source = 'saathi',
    String? appPackage,
    String? appName,
    String? action,
    String? intent,
  }) async {
    if (!await enabled()) return;
    final now = DateTime.now();
    await AppDatabase.use(
      null,
      (db) => db.logActionEvent(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
        timestamp: now.millisecondsSinceEpoch,
        eventType: type,
        source: source,
        appPackage: appPackage,
        appName: appName,
        action: action,
        intent: intent,
      ),
    );
  }

  static Future<List<ActionEvent>> recent() async {
    if (!await enabled()) return [];
    try {
      await collectOptionalSignals();
    } catch (_) {
      /* Optional source may be unavailable. */
    }
    return AppDatabase.use(
      null,
      (db) async =>
          (await db.recentActionEvents()).map(ActionEvent.fromRow).toList(),
    );
  }

  static Future<List<ActionEvent>> today() async {
    if (!await enabled()) return [];
    return AppDatabase.use(
      null,
      (db) async =>
          (await db.recentActionEvents(limit: 500))
              .map(ActionEvent.fromRow)
              .toList(),
    );
  }

  static ContextExplanation explain(List<ActionEvent> events) {
    final now = DateTime.now();
    for (final event in events) {
      if (now.difference(event.timestamp) > const Duration(hours: 2)) {
        continue;
      }
      if (event.type == 'SHARED_LINK' && event.action != null) {
        return ContextExplanation(
          text: 'You saved a web link. Would you like to open it?',
          evidence: 'You explicitly shared this one link to Saathi. Saathi did not read the conversation it came from.',
          webLink: event.action,
        );
      }
      if (event.type == 'APP_FOREGROUND') {
        final name = event.appName ?? 'an app';
        return ContextExplanation(
          text: 'Android recently recorded $name on your screen.',
          evidence:
              'Usage access showed when $name was in the foreground. It cannot tell what you did or why.',
          appPackage: event.appPackage,
          appName: name,
        );
      }
      if (event.type != 'APP_OPEN') continue;
      final name = event.appName ?? 'that app';
      final purpose = event.intent;
      final repeats = event.appPackage == null
          ? 0
          : events
                .where(
                  (other) =>
                      other.type == 'APP_OPEN' &&
                      other.appPackage == event.appPackage &&
                      now.difference(other.timestamp) <=
                          const Duration(minutes: 10),
                )
                .length;
      if (purpose != null && purpose.isNotEmpty) {
        return ContextExplanation(
          text: 'You opened $name to $purpose.',
          evidence:
              'You chose "$purpose" before opening $name. This is a saved intention.',
          appPackage: event.appPackage,
          appName: name,
          repeated: repeats >= 3,
        );
      }
      return ContextExplanation(
        text: 'You recently opened $name. Do you want to go back to it?',
        evidence: _appEvidence(event, events),
        appPackage: event.appPackage,
        appName: name,
        repeated: repeats >= 3,
      );
    }
    return const ContextExplanation(
      text: 'I do not have enough recent activity to tell what you were doing.',
      evidence: 'Saathi only uses actions it has saved on this phone.',
    );
  }

  static String _appEvidence(ActionEvent opened, List<ActionEvent> events) {
    final nearby = events.where(
      (event) =>
          event.type == 'NOTIFICATION' &&
          opened.appPackage == 'com.whatsapp' &&
          event.action != null &&
          !opened.timestamp.isBefore(event.timestamp) &&
          opened.timestamp.difference(event.timestamp) <=
              const Duration(minutes: 5),
    );
    if (nearby.isNotEmpty) {
      return 'Saathi saw you open WhatsApp. A WhatsApp notification from ${nearby.first.action} appeared shortly before. You may have opened it to check that message, but Saathi cannot know for sure.';
    }
    return 'Saathi saw you open ${opened.appName ?? 'that app'} from the launcher. It does not know why.';
  }

  static String breadcrumb(ActionEvent event) => switch (event.type) {
    'APP_OPEN' =>
      'Opened ${event.appName ?? 'an app'}${event.intent == null ? '' : ' to ${event.intent}'}',
    'APP_INTENT' => 'Chose to ${event.intent ?? 'open an app'}',
    'RETURN_HOME' => 'Returned to Saathi home',
    'VOICE_QUERY' => 'Asked Saathi a question',
    'DAY_ACTION' => 'Confirmed a task in My Day',
    'APP_FOREGROUND' => 'Used ${event.appName ?? 'an app'} (Android timing)',
    'NOTIFICATION' =>
      'WhatsApp notification${event.action == null ? '' : ' from ${event.action}'} appeared',
    'SHARED_LINK' => 'Saved a shared link',
    _ => event.action ?? 'Used Saathi',
  };
}
