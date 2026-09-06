import 'cognitive_record.dart';

/// Stateless, deterministic, rule-based cognitive difficulty engine.
///
/// Examines the last [_windowSize] records for a given [RecordKind] and
/// returns the appropriate difficulty level for the next attempt.
///
/// Difficulty levels:
///   1 — easy   (< 40 % correct in last 5 answers)
///   2 — medium (40–80 % correct — default when data is sparse)
///   3 — hard   (> 80 % correct in last 5 answers)
///
/// No LLM is required.  The engine is pure Dart and fully testable offline.
class CognitiveEngine {
  const CognitiveEngine();

  static const int _windowSize = 5;

  /// Returns the difficulty (1–3) for the next attempt of [kind].
  ///
  /// [allRecords] should be the full sorted list from [RecordStore.loadAll].
  /// The engine filters by [kind] and looks at the last [_windowSize] results.
  int difficulty(List<CognitiveRecord> allRecords, RecordKind kind) {
    final relevant = allRecords.where((r) => r.kind == kind).toList();
    if (relevant.length < 3) return 2; // not enough data → medium default

    final window = relevant.length > _windowSize
        ? relevant.sublist(relevant.length - _windowSize)
        : relevant;

    final correctCount = window.where((r) => r.correct).length;
    final ratio = correctCount / window.length;

    if (ratio > 0.8) return 3;
    if (ratio >= 0.4) return 2;
    return 1;
  }

  /// Constructs a [CognitiveRecord] for a completed attempt.
  ///
  /// Call this after the patient answers (correct or incorrect) so the result
  /// can be stored via [RecordStore.save].
  CognitiveRecord record({
    required RecordKind kind,
    required String entryId,
    required bool correct,
    required int responseMs,
    required int hintsUsed,
    required int difficulty,
  }) =>
      CognitiveRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        kind: kind,
        entryId: entryId,
        correct: correct,
        responseMs: responseMs,
        hintsUsed: hintsUsed,
        difficulty: difficulty,
        timestamp: DateTime.now(),
      );
}
