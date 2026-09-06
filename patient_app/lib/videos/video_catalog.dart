import 'dart:io';

import 'package:drift/drift.dart';

import '../storage/app_database.dart';

import 'package:path_provider/path_provider.dart';

import 'video_entry.dart';

/// Static catalog of bundled demo videos and their recall questions.
///
/// Also manages the "last watched" marker used for delayed recall.
/// Replace the file-based marker with Drift at the database milestone.
class VideoCatalog {
  VideoCatalog({
    Future<Directory> Function()? directory,
    DateTime Function()? now,
  }) : _directory = directory ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _now;

  /// All available videos.  Order matches the selection UI.
  static const List<VideoEntry> entries = [
    VideoEntry(
      id: 'gardening',
      title: 'Gardening',
      topic: 'gardening',
      assetPath: 'assets/videos/gardening.mp4',
      icon: 0xe25a, // Icons.yard
      questions: [
        RecallQuestion(
          text: 'What was this video mainly about?',
          expectedAnswer: 'Gardening',
          type: RecallType.immediate,
        ),
        RecallQuestion(
          text: 'What activity did you see in the video?',
          expectedAnswer: 'Planting',
          type: RecallType.immediate,
        ),
        RecallQuestion(
          text: 'Do you remember what you watched earlier?',
          expectedAnswer: 'Gardening',
          type: RecallType.delayed,
        ),
      ],
    ),
    VideoEntry(
      id: 'cooking',
      title: 'Cooking',
      topic: 'cooking',
      assetPath: 'assets/videos/cooking.mp4',
      icon: 0xe56a, // Icons.restaurant
      questions: [
        RecallQuestion(
          text: 'What was this video mainly about?',
          expectedAnswer: 'Cooking',
          type: RecallType.immediate,
        ),
        RecallQuestion(
          text: 'What was being prepared in the video?',
          expectedAnswer: 'Food',
          type: RecallType.immediate,
        ),
        RecallQuestion(
          text: 'Do you remember what you watched earlier?',
          expectedAnswer: 'Cooking',
          type: RecallType.delayed,
        ),
      ],
    ),
    VideoEntry(
      id: 'nature_walk',
      title: 'Nature Walk',
      topic: 'nature walk',
      assetPath: 'assets/videos/nature_walk.mp4',
      icon: 0xeef3, // Icons.park
      questions: [
        RecallQuestion(
          text: 'What was this video mainly about?',
          expectedAnswer: 'Nature Walk',
          type: RecallType.immediate,
        ),
        RecallQuestion(
          text: 'Where was the walk taking place?',
          expectedAnswer: 'Nature',
          type: RecallType.immediate,
        ),
        RecallQuestion(
          text: 'Do you remember what you watched earlier?',
          expectedAnswer: 'Nature Walk',
          type: RecallType.delayed,
        ),
      ],
    ),
  ];

  /// Returns the [VideoEntry] matching [id], or `null` if not found.
  static VideoEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ---------- last-watched marker ----------

  static const recallDelay = Duration(minutes: 5);
  Future<VideoEntry?> lastWatched() => AppDatabase.use(_directory, (db) async {
    final rows = await db
        .customSelect(
          'SELECT id FROM video_sessions WHERE completed = 0 AND due_at <= ? ORDER BY watched_at LIMIT 1',
          variables: [Variable(_now().millisecondsSinceEpoch)],
        )
        .get();
    return rows.isEmpty ? null : byId(rows.first.read<String>('id'));
  });
  Future<void> markWatched(VideoEntry video) =>
      AppDatabase.use(_directory, (db) async {
        final now = _now().millisecondsSinceEpoch;
        await db.customStatement(
          'INSERT OR REPLACE INTO video_sessions VALUES (?, ?, ?, 0)',
          [video.id, now, now + recallDelay.inMilliseconds],
        );
      });
  Future<void> clearLastWatched() => AppDatabase.use(_directory, (db) async {
    await db.customStatement(
      'UPDATE video_sessions SET completed = 1 WHERE id = (SELECT id FROM video_sessions WHERE completed = 0 AND due_at <= ? ORDER BY watched_at LIMIT 1)',
      [_now().millisecondsSinceEpoch],
    );
  });
}
