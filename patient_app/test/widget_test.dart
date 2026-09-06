import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/main.dart';
import 'package:patient_app/launcher/launcher_bridge.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/memory_passport/passport_store.dart';
import 'package:patient_app/cognition/record_store.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/family/family_screen.dart';

// ---------------------------------------------------------------------------
// Lightweight fakes for the Family photo test — no real file I/O needed.
// ---------------------------------------------------------------------------

/// A PassportStore whose photoFile() returns a non-existent File path.
/// When passed to Image.file(), the errorBuilder fires immediately without
/// retrying, so pumpAndSettle() terminates normally.
class _FakePassportStore extends PassportStore {
  _FakePassportStore() : super(directory: () async => Directory.systemTemp);

  @override
  Future<Passport> load() async => Passport.demo();

  @override
  Future<void> save(Passport passport) async {}

  @override
  Future<File> photoFile(String name) async =>
      File('${Directory.systemTemp.path}/nonexistent_${name}_test');
}

/// A RecordStore that never touches the disk.
class _FakeRecordStore extends RecordStore {
  _FakeRecordStore() : super(directory: () async => Directory.systemTemp);

  @override
  Future<List<CognitiveRecord>> loadAll() async => [];

  @override
  Future<void> save(CognitiveRecord record) async {}
}

// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LauncherBridge.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isDefaultHome') return false;
          if (call.method == 'listApps') {
            return [
              {'label': 'Clock', 'packageName': 'example.clock'},
            ];
          }
          return null;
        });
  });

  testWidgets('Home works at large text size and opens Android chooser', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const CompanionApp());
    await tester.pumpAndSettle();
    expect(find.text('Talk to Saathi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choose home screen'), 400);
    await tester.tap(find.text('Choose home screen'));
    await tester.pumpAndSettle();
    expect(calls, contains('requestHome'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('App list opens an installed app through the bridge', (
    tester,
  ) async {
    await tester.pumpWidget(const CompanionApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Phone apps'), 400);
    await tester.tap(find.text('Phone apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clock'));
    await tester.pumpAndSettle();
    expect(calls, contains('openApp'));
  });

  test('Bridge reports platform errors instead of claiming success', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LauncherBridge.channel, (call) async {
          throw PlatformException(code: 'APP_UNAVAILABLE');
        });
    await expectLater(
      LauncherBridge().openApp('missing'),
      throwsA(isA<PlatformException>()),
    );
  });

  // ---------------------------------------------------------------------------
  // Family Recognition
  // ---------------------------------------------------------------------------

  testWidgets(
    'FamilyScreen shows no-photos guard when no family entries have photos',
    (tester) async {
      final passportWithoutPhotos = Passport(
        name: 'Mr. Bora',
        age: 72,
        region: 'Assam',
        isDemo: true,
        entries: [
          const MemoryEntry(
            id: 'rahul',
            kind: MemoryKind.family,
            values: {'name': 'Rahul', 'relationship': 'Son'},
            // photo is null
          ),
        ],
      );

      final passportStore = _FakePassportStore();
      final recordStore = _FakeRecordStore();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyScreen(
            passport: passportWithoutPhotos,
            passportStore: passportStore,
            recordStore: recordStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No family photos yet.'), findsOneWidget);
      expect(find.text('Open Memory Passport'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FamilyScreen shows question view when a family entry has a photo',
    (tester) async {
      // Use fakes to avoid real file I/O.
      // _FakePassportStore.photoFile() returns a non-existent path so
      // Image.file() fires the errorBuilder immediately — no infinite retry.
      final passportStore = _FakePassportStore();
      final recordStore = _FakeRecordStore();

      final passportWithPhoto = Passport(
        name: 'Mr. Bora',
        age: 72,
        region: 'Assam',
        isDemo: true,
        entries: [
          const MemoryEntry(
            id: 'rahul',
            kind: MemoryKind.family,
            values: {'name': 'Rahul', 'relationship': 'Son'},
            photo: '1234567890.photo', // passes regex; file will not exist
          ),
        ],
      );

      // Use runAsync to allow real async I/O (image codec isolate, _init())
      // to complete.  The fake timer clock used by pumpAndSettle() cannot
      // drive native isolates; runAsync lifts that restriction.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FamilyScreen(
              passport: passportWithPhoto,
              passportStore: passportStore,
              recordStore: recordStore,
            ),
          ),
        );
        // Give the codec isolate and _init() time to complete.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump(); // apply setState to the widget tree

      // Question prompt and action buttons must be visible.
      // Use skipOffstage: false since the Skip button may be scrolled off
      // the test viewport in the ListView.
      expect(find.text('Who is this?', skipOffstage: false), findsOneWidget);
      expect(
        find.text('That is my answer', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('I am not sure', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
