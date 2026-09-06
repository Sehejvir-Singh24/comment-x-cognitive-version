import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/videos/video_catalog.dart';
import 'package:patient_app/videos/video_entry.dart';

void main() {
  group('VideoCatalog', () {
    test('entries contains 3 bundled videos', () {
      expect(VideoCatalog.entries.length, 3);
      final ids = VideoCatalog.entries.map((e) => e.id).toSet();
      expect(ids, {'gardening', 'cooking', 'nature_walk'});
    });

    test('byId returns the correct entry', () {
      final entry = VideoCatalog.byId('gardening');
      expect(entry, isNotNull);
      expect(entry!.title, 'Gardening');
      expect(entry.topic, 'gardening');
    });

    test('byId returns null for unknown id', () {
      expect(VideoCatalog.byId('nonexistent'), isNull);
    });

    test('every video has at least one immediate and one delayed question', () {
      for (final video in VideoCatalog.entries) {
        final immediate = video.questions.where(
          (q) => q.type == RecallType.immediate,
        );
        final delayed = video.questions.where(
          (q) => q.type == RecallType.delayed,
        );
        expect(
          immediate.isNotEmpty,
          isTrue,
          reason: '${video.id} should have immediate questions',
        );
        expect(
          delayed.isNotEmpty,
          isTrue,
          reason: '${video.id} should have delayed questions',
        );
      }
    });
  });

  group('last-watched marker', () {
    late Directory folder;
    late VideoCatalog catalog;
    late DateTime now;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('saathi-video-test-');
      now = DateTime(2026, 9, 6);
      catalog = VideoCatalog(directory: () async => folder, now: () => now);
    });

    tearDown(() async {
      if (await folder.exists()) await folder.delete(recursive: true);
    });

    test('lastWatched returns null when no marker exists', () async {
      expect(await catalog.lastWatched(), isNull);
    });

    test('markWatched persists and lastWatched retrieves', () async {
      final video = VideoCatalog.entries.first;
      await catalog.markWatched(video);
      expect(await catalog.lastWatched(), isNull);
      now = now.add(VideoCatalog.recallDelay);

      final last = await catalog.lastWatched();
      expect(last, isNotNull);
      expect(last!.id, video.id);
    });

    test('clearLastWatched removes the marker', () async {
      final video = VideoCatalog.entries.first;
      await catalog.markWatched(video);
      expect(await catalog.lastWatched(), isNull);
      now = now.add(VideoCatalog.recallDelay);
      expect(await catalog.lastWatched(), isNotNull);

      await catalog.clearLastWatched();
      expect(await catalog.lastWatched(), isNull);
    });

    test('pending videos are retained in order', () async {
      await catalog.markWatched(VideoCatalog.entries[0]);
      await catalog.markWatched(VideoCatalog.entries[1]);
      now = now.add(VideoCatalog.recallDelay);

      final last = await catalog.lastWatched();
      expect(last!.id, VideoCatalog.entries[0].id);
    });
  });

  group('answer matching (via VideoEntry metadata)', () {
    test('each video has a non-empty topic', () {
      for (final v in VideoCatalog.entries) {
        expect(v.topic.isNotEmpty, isTrue);
      }
    });

    test('each question has a non-empty expectedAnswer', () {
      for (final v in VideoCatalog.entries) {
        for (final q in v.questions) {
          expect(q.expectedAnswer.isNotEmpty, isTrue);
        }
      }
    });
  });
}
