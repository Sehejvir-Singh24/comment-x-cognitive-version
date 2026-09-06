import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'video_entry.dart';

/// Static catalog of bundled demo videos and their recall questions.
///
/// Also manages the "last watched" marker used for delayed recall.
/// Replace the file-based marker with Drift at the database milestone.
class VideoCatalog {
  VideoCatalog({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

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

  Future<File> _markerFile() async {
    final base = await _directory();
    final folder =
        await Directory('${base.path}/memory_passport').create(recursive: true);
    return File('${folder.path}/last_watched.txt');
  }

  /// Returns the [VideoEntry] the patient watched most recently, or `null`.
  Future<VideoEntry?> lastWatched() async {
    try {
      final file = await _markerFile();
      if (!await file.exists()) return null;
      final id = (await file.readAsString()).trim();
      return byId(id);
    } catch (_) {
      return null;
    }
  }

  /// Records [video] as the most recently watched.
  Future<void> markWatched(VideoEntry video) async {
    try {
      final file = await _markerFile();
      await file.writeAsString(video.id, flush: true);
    } catch (_) {
      // Non-critical — delayed recall just won't trigger next time.
    }
  }

  /// Clears the last-watched marker (e.g. after delayed recall is answered).
  Future<void> clearLastWatched() async {
    try {
      final file = await _markerFile();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Non-critical.
    }
  }
}
