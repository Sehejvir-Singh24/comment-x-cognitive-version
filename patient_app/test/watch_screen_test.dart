import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/cognition/record_store.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/videos/video_catalog.dart';
import 'package:patient_app/videos/video_entry.dart';
import 'package:patient_app/videos/watch_screen.dart';

// ---------------------------------------------------------------------------
// Fakes — no real disk I/O or video player needed
// ---------------------------------------------------------------------------

/// A RecordStore that never touches the disk.
class _FakeRecordStore extends RecordStore {
  _FakeRecordStore() : super(directory: () async => Directory.systemTemp);

  final saved = <CognitiveRecord>[];

  @override
  Future<List<CognitiveRecord>> loadAll() async => [];

  @override
  Future<void> save(CognitiveRecord record) async => saved.add(record);
}

/// A VideoCatalog that never touches the disk and lets us control
/// the last-watched marker in memory.
class _FakeVideoCatalog extends VideoCatalog {
  _FakeVideoCatalog({this.fakeLastWatched})
    : super(directory: () async => Directory.systemTemp);

  VideoEntry? fakeLastWatched;

  @override
  Future<VideoEntry?> lastWatched() async => fakeLastWatched;

  @override
  Future<void> markWatched(VideoEntry video) async {
    fakeLastWatched = video;
  }

  @override
  Future<void> clearLastWatched() async {
    fakeLastWatched = null;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp(WatchScreen screen) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: screen,
  );

  testWidgets('WatchScreen shows video selection when no previous video', (
    tester,
  ) async {
    final recordStore = _FakeRecordStore();
    final catalog = _FakeVideoCatalog(); // no last-watched

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildApp(WatchScreen(recordStore: recordStore, catalog: catalog)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Should show the selection screen with "Choose a video to watch".
    expect(
      find.text('Choose a video to watch', skipOffstage: false),
      findsOneWidget,
    );
    // All three video titles should be visible.
    expect(find.text('Gardening', skipOffstage: false), findsOneWidget);
    expect(find.text('Cooking', skipOffstage: false), findsOneWidget);
    expect(find.text('Nature Walk', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WatchScreen shows delayed recall when previous video exists', (
    tester,
  ) async {
    final recordStore = _FakeRecordStore();
    final catalog = _FakeVideoCatalog(
      fakeLastWatched: VideoCatalog.entries.first, // gardening
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildApp(WatchScreen(recordStore: recordStore, catalog: catalog)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Should show the delayed recall prompt.
    expect(
      find.text('Earlier you watched a video.', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Do you remember what it was about?', skipOffstage: false),
      findsOneWidget,
    );
    // Skip button should be available.
    expect(find.text("I don't remember", skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skipping delayed recall saves a record and shows result', (
    tester,
  ) async {
    final recordStore = _FakeRecordStore();
    final catalog = _FakeVideoCatalog(
      fakeLastWatched: VideoCatalog.entries.first,
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        buildApp(WatchScreen(recordStore: recordStore, catalog: catalog)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Ensure the skip button is visible, then tap it.
    final skipFinder = find.text("I don't remember");
    await tester.ensureVisible(skipFinder);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(skipFinder);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Should show the incorrect result.
    expect(find.text('Not quite.', skipOffstage: false), findsOneWidget);
    // A record should have been saved.
    expect(recordStore.saved.length, 1);
    expect(recordStore.saved.first.correct, false);
    expect(recordStore.saved.first.kind, RecordKind.videoRecall);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'WatchScreen result shows Watch another and Back to home buttons',
    (tester) async {
      final recordStore = _FakeRecordStore();
      final catalog = _FakeVideoCatalog(
        fakeLastWatched: VideoCatalog.entries.first,
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          buildApp(WatchScreen(recordStore: recordStore, catalog: catalog)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Ensure the skip button is visible and tap it.
      final skipFinder = find.text("I don't remember");
      await tester.ensureVisible(skipFinder);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(skipFinder);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('Watch another', skipOffstage: false), findsOneWidget);
      expect(find.text('Back to home', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
