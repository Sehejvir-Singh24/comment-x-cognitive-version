import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/cognition/record_store.dart';

int nextRecordId = 0;
CognitiveRecord _makeRecord({bool correct = true, int hintsUsed = 0}) =>
    CognitiveRecord(
      id: (nextRecordId++).toString(),
      kind: RecordKind.familyRecognition,
      entryId: 'rahul',
      correct: correct,
      responseMs: 2000,
      hintsUsed: hintsUsed,
      difficulty: 2,
      timestamp: DateTime.now(),
    );

void main() {
  late Directory folder;
  late RecordStore store;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('saathi-records-test-');
    store = RecordStore(directory: () async => folder);
  });

  tearDown(() async => folder.delete(recursive: true));

  test('loadAll returns empty list when no file exists', () async {
    final records = await store.loadAll();
    expect(records, isEmpty);
  });

  test('saves a record and reloads it correctly', () async {
    final rec = _makeRecord(correct: true, hintsUsed: 2);
    await store.save(rec);

    final reloaded = await store.loadAll();
    expect(reloaded.length, 1);
    expect(reloaded.first.entryId, 'rahul');
    expect(reloaded.first.correct, true);
    expect(reloaded.first.hintsUsed, 2);
    expect(reloaded.first.kind, RecordKind.familyRecognition);
  });

  test(
    'first hint timing survives storage and legacy records remain readable',
    () async {
      final original = _makeRecord(hintsUsed: 1);
      final timed = CognitiveRecord(
        id: original.id,
        kind: original.kind,
        entryId: original.entryId,
        correct: original.correct,
        responseMs: original.responseMs,
        hintsUsed: original.hintsUsed,
        firstHintMs: 700,
        difficulty: original.difficulty,
        timestamp: original.timestamp,
      );
      await store.save(timed);
      expect((await store.loadAll()).single.firstHintMs, 700);
      expect(CognitiveRecord.fromJson(original.toJson()).firstHintMs, isNull);
    },
  );

  test('appends multiple records in order', () async {
    final r1 = _makeRecord(correct: true);
    await Future.delayed(const Duration(milliseconds: 1));
    final r2 = _makeRecord(correct: false, hintsUsed: 1);
    await Future.delayed(const Duration(milliseconds: 1));
    final r3 = _makeRecord(correct: true, hintsUsed: 3);

    await store.save(r1);
    await store.save(r2);
    await store.save(r3);

    final all = await store.loadAll();
    expect(all.length, 3);
    expect(all[0].correct, true);
    expect(all[1].correct, false);
    expect(all[2].hintsUsed, 3);
  });

  test('recent(n) returns the last n records', () async {
    for (var i = 0; i < 8; i++) {
      await store.save(_makeRecord(correct: i.isEven));
    }
    final last5 = await store.recent(5);
    expect(last5.length, 5);
    // i=7 is odd → correct = false
    expect(last5.last.correct, false);
  });

  test('recent(n) returns all records when total < n', () async {
    await store.save(_makeRecord());
    await store.save(_makeRecord(correct: false));
    final result = await store.recent(10);
    expect(result.length, 2);
  });

  test('corrupt file throws FormatException and preserves data', () async {
    await Directory('${folder.path}/memory_passport').create(recursive: true);
    final file = File('${folder.path}/memory_passport/records.json');
    await file.writeAsString('corrupt data here');

    await expectLater(store.loadAll(), throwsA(isA<FormatException>()));
    // File must not have been replaced
    expect(await file.readAsString(), 'corrupt data here');
  });

  test('unknown schema version throws FormatException', () async {
    await Directory('${folder.path}/memory_passport').create(recursive: true);
    final file = File('${folder.path}/memory_passport/records.json');
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'records': [_makeRecord().toJson()],
    };
    json['schemaVersion'] = 9;
    await file.writeAsString(jsonEncode(json));

    await expectLater(store.loadAll(), throwsA(isA<FormatException>()));
    // File must be preserved
    expect((jsonDecode(await file.readAsString()) as Map)['schemaVersion'], 9);
  });

  test('concurrent initial saves do not lose records', () async {
    final r1 = _makeRecord(correct: true);
    final r2 = _makeRecord(correct: false);
    // Fire two saves simultaneously — the serialized queue ensures both land
    await Future.wait([store.save(r1), store.save(r2)]);

    final all = await store.loadAll();
    expect(all.length, 2);
  });

  test('CognitiveRecord round-trips through JSON', () {
    final rec = _makeRecord(correct: false, hintsUsed: 1);
    final json = rec.toJson();
    final restored = CognitiveRecord.fromJson(json);
    expect(restored.correct, false);
    expect(restored.hintsUsed, 1);
    expect(restored.kind, RecordKind.familyRecognition);
    expect(restored.entryId, rec.entryId);
    expect(restored.responseMs, rec.responseMs);
  });
}
