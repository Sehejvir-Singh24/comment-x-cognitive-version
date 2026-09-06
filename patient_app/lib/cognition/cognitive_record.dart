/// The kind of cognitive exercise that produced a [CognitiveRecord].
///
/// Each kind tracks difficulty independently via [CognitiveEngine].
enum RecordKind { familyRecognition, videoRecall }

/// One recorded outcome from a cognitive exercise.
///
/// This model is the narrow interface that the rule-based [CognitiveEngine]
/// and [RecordStore] share.  The UI never constructs records directly; it
/// calls the engine, which creates and stores them.
class CognitiveRecord {
  const CognitiveRecord({
    required this.id,
    required this.kind,
    required this.entryId,
    required this.correct,
    required this.responseMs,
    required this.hintsUsed,
    required this.difficulty,
    required this.timestamp,
  });

  /// Unique opaque identifier — microseconds-since-epoch as a string.
  final String id;

  /// Which type of cognitive exercise produced this record.
  final RecordKind kind;

  /// The [MemoryEntry.id] of the subject shown to the patient.
  final String entryId;

  /// Whether the patient's answer matched the entry's name.
  final bool correct;

  /// Milliseconds from question display to the patient committing an answer.
  final int responseMs;

  /// Number of hints the patient requested (0–3).
  final int hintsUsed;

  /// Difficulty level at the time of the attempt (1 = easy, 2 = medium, 3 = hard).
  final int difficulty;

  /// Wall-clock time when the answer was committed.
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'kind': kind.name,
        'entryId': entryId,
        'correct': correct,
        'responseMs': responseMs,
        'hintsUsed': hintsUsed,
        'difficulty': difficulty,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CognitiveRecord.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported record version');
    }
    return CognitiveRecord(
      id: json['id'] as String,
      kind: RecordKind.values.byName(json['kind'] as String),
      entryId: json['entryId'] as String,
      correct: json['correct'] as bool,
      responseMs: json['responseMs'] as int,
      hintsUsed: json['hintsUsed'] as int,
      difficulty: json['difficulty'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
