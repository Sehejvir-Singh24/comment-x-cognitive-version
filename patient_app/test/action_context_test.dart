import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/context/action_context.dart';
import 'package:patient_app/storage/app_database.dart';

void main() {
  test('stated purpose is reported with its evidence', () {
    final explanation = ActionContext.explain([
      ActionEvent(
        id: '1',
        timestamp: DateTime.now(),
        type: 'APP_OPEN',
        source: 'launcher',
        appPackage: 'com.example.video',
        appName: 'YouTube',
        intent: 'watch a video',
      ),
    ]);
    expect(explanation.text, 'You opened YouTube to watch a video.');
    expect(explanation.evidence, contains('You chose'));
    expect(explanation.appPackage, 'com.example.video');
  });

  test('app open alone does not invent a purpose', () {
    final explanation = ActionContext.explain([
      ActionEvent(
        id: '2',
        timestamp: DateTime.now(),
        type: 'APP_OPEN',
        source: 'voice',
        appName: 'WhatsApp',
      ),
    ]);
    expect(explanation.text, contains('recently opened WhatsApp'));
    expect(explanation.evidence, contains('does not know why'));
  });

  test('action history stays local and recent', () async {
    final folder = await Directory.systemTemp.createTemp('saathi-context-');
    try {
      await AppDatabase.use(() async => folder, (db) async {
        await db.logActionEvent(
          id: 'saved-intent',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          eventType: 'APP_INTENT',
          source: 'launcher',
          appName: 'YouTube',
          intent: 'watch a video',
        );
        final events = await db.recentActionEvents();
        expect(events, hasLength(1));
        expect(events.single['intent'], 'watch a video');
        expect(
          await db.customSelect('SELECT * FROM sync_outbox').get(),
          isEmpty,
        );
      });
    } finally {
      await folder.delete(recursive: true);
    }
  });

  test('three recent openings prompt a gentle return', () {
    final now = DateTime.now();
    final events = List.generate(
      3,
      (index) => ActionEvent(
        id: '$index',
        timestamp: now.subtract(Duration(minutes: index)),
        type: 'APP_OPEN',
        source: 'launcher',
        appPackage: 'com.example.app',
        appName: 'WhatsApp',
      ),
    );
    expect(ActionContext.explain(events).repeated, isTrue);
  });

  test('usage timing cannot claim an app purpose', () {
    final explanation = ActionContext.explain([
      ActionEvent(
        id: 'usage',
        timestamp: DateTime.now(),
        type: 'APP_FOREGROUND',
        source: 'usage',
        appPackage: 'com.whatsapp',
        appName: 'WhatsApp',
      ),
    ]);
    expect(explanation.text, contains('Android recently recorded'));
    expect(explanation.evidence, contains('cannot tell what you did or why'));
  });

  test('notification near WhatsApp opening is only a possible reason', () {
    final now = DateTime.now();
    final explanation = ActionContext.explain([
      ActionEvent(
        id: 'opened',
        timestamp: now,
        type: 'APP_OPEN',
        source: 'launcher',
        appPackage: 'com.whatsapp',
        appName: 'WhatsApp',
      ),
      ActionEvent(
        id: 'notification',
        timestamp: now.subtract(const Duration(minutes: 2)),
        type: 'NOTIFICATION',
        source: 'notification',
        action: 'Priya',
      ),
    ]);
    expect(explanation.evidence, contains('may have opened'));
    expect(explanation.evidence, contains('cannot know for sure'));
  });

  test('shared link is explicit evidence with a return target', () {
    final explanation = ActionContext.explain([
      ActionEvent(
        id: 'share',
        timestamp: DateTime.now(),
        type: 'SHARED_LINK',
        source: 'share',
        action: 'https://example.com/video',
      ),
    ]);
    expect(explanation.webLink, 'https://example.com/video');
    expect(explanation.evidence, contains('explicitly shared'));
  });
}
