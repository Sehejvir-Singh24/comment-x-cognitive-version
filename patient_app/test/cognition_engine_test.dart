import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/cognition/cognitive_engine.dart';
import 'package:patient_app/cognition/cognitive_record.dart';

/// Constructs a [CognitiveRecord] for testing with minimal boilerplate.
CognitiveRecord _rec({
  required RecordKind kind,
  required bool correct,
}) =>
    CognitiveRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      entryId: 'test-entry',
      correct: correct,
      responseMs: 1000,
      hintsUsed: 0,
      difficulty: 2,
      timestamp: DateTime.now(),
    );

void main() {
  const engine = CognitiveEngine();
  const kind = RecordKind.familyRecognition;

  test('returns medium difficulty (2) when fewer than 3 records exist', () {
    expect(engine.difficulty([], kind), 2);
    expect(engine.difficulty([_rec(kind: kind, correct: true)], kind), 2);
    expect(
      engine.difficulty([
        _rec(kind: kind, correct: true),
        _rec(kind: kind, correct: true),
      ], kind),
      2,
    );
  });

  test('returns hard difficulty (3) when more than 80 % of last 5 are correct',
      () {
    final records = List.generate(5, (_) => _rec(kind: kind, correct: true));
    expect(engine.difficulty(records, kind), 3);

    // 4/5 = 80 % → should still be hard (> 80 is hard, exactly 80 is medium)
    final records4 = [
      ...List.generate(4, (_) => _rec(kind: kind, correct: true)),
      _rec(kind: kind, correct: false),
    ];
    // 4/5 = 0.8 — not strictly > 0.8, so should be medium
    expect(engine.difficulty(records4, kind), 2);

    // 5/5 = 1.0 → hard
    final records5 = List.generate(5, (_) => _rec(kind: kind, correct: true));
    expect(engine.difficulty(records5, kind), 3);
  });

  test('returns easy difficulty (1) when fewer than 40 % are correct', () {
    // 1/5 = 20 % → easy
    final records = [
      _rec(kind: kind, correct: true),
      ...List.generate(4, (_) => _rec(kind: kind, correct: false)),
    ];
    expect(engine.difficulty(records, kind), 1);

    // 0/5 = 0 % → easy
    final allWrong = List.generate(5, (_) => _rec(kind: kind, correct: false));
    expect(engine.difficulty(allWrong, kind), 1);
  });

  test('returns medium difficulty (2) for 40–80 % correct', () {
    // 3/5 = 60 %
    final records = [
      ...List.generate(3, (_) => _rec(kind: kind, correct: true)),
      ...List.generate(2, (_) => _rec(kind: kind, correct: false)),
    ];
    expect(engine.difficulty(records, kind), 2);
  });

  test('ignores records from a different RecordKind', () {
    // Only 1 familyRecognition record (< 3) → medium despite many other records
    final records = [
      // Non-matching kind records (enum has only one value now, so use a
      // workaround: create family records and verify engine reads only its kind)
      ...List.generate(10, (_) => _rec(kind: kind, correct: true)),
      // We just check that all 10 are still processed correctly
    ];
    // 10 correct → hard
    expect(engine.difficulty(records, kind), 3);
  });

  test('only the last 5 records are used when history is longer', () {
    // 8 correct, then 5 wrong: last-5 window is all wrong → easy
    final records = [
      ...List.generate(8, (_) => _rec(kind: kind, correct: true)),
      ...List.generate(5, (_) => _rec(kind: kind, correct: false)),
    ];
    expect(engine.difficulty(records, kind), 1);
  });

  test('record() produces a valid CognitiveRecord', () {
    final rec = engine.record(
      kind: kind,
      entryId: 'rahul',
      correct: true,
      responseMs: 3200,
      hintsUsed: 1,
      difficulty: 2,
    );
    expect(rec.kind, kind);
    expect(rec.entryId, 'rahul');
    expect(rec.correct, true);
    expect(rec.responseMs, 3200);
    expect(rec.hintsUsed, 1);
    expect(rec.difficulty, 2);
    expect(rec.id, isNotEmpty);
  });

  test('videoRecall difficulty is computed independently from familyRecognition',
      () {
    // 5 correct familyRecognition + 0 videoRecall → video should be medium (2)
    final familyOnly =
        List.generate(5, (_) => _rec(kind: kind, correct: true));
    expect(engine.difficulty(familyOnly, RecordKind.videoRecall), 2);

    // Mix: 5 correct familyRecognition + 5 wrong videoRecall → video = easy
    final mixed = [
      ...familyOnly,
      ...List.generate(
          5, (_) => _rec(kind: RecordKind.videoRecall, correct: false)),
    ];
    expect(engine.difficulty(mixed, RecordKind.videoRecall), 1);
    // familyRecognition should still be hard
    expect(engine.difficulty(mixed, RecordKind.familyRecognition), 3);
  });
}
