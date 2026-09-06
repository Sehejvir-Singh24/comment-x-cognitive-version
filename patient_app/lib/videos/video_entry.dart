/// The type of recall question — immediate (right after watching) or
/// delayed (next session).
enum RecallType { immediate, delayed }

/// A single recall question associated with a [VideoEntry].
class RecallQuestion {
  const RecallQuestion({
    required this.text,
    required this.expectedAnswer,
    required this.type,
  });

  /// The question prompt shown to the patient.
  final String text;

  /// The expected answer — used for case-insensitive, first-word matching.
  final String expectedAnswer;

  /// Whether this question is asked immediately after watching or in the
  /// next session.
  final RecallType type;
}

/// A bundled video available for the Watch / Video Recall exercise.
///
/// Each entry describes one short video and its recall questions.
/// The catalog of entries lives in [VideoCatalog].
class VideoEntry {
  const VideoEntry({
    required this.id,
    required this.title,
    required this.topic,
    required this.assetPath,
    required this.icon,
    required this.questions,
  });

  /// Unique identifier (e.g., "gardening").
  final String id;

  /// Human-readable title (e.g., "Gardening").
  final String title;

  /// Short description of the main subject — used for answer matching
  /// in delayed recall ("What was the video about?").
  final String topic;

  /// Flutter asset path to the bundled MP4 file.
  final String assetPath;

  /// Icon data for the selection card.
  final int icon; // Material icon codePoint for serialization simplicity

  /// Recall questions associated with this video.
  final List<RecallQuestion> questions;
}
