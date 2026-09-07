import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/caregiver/caregiver_dashboard_screen.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/cognition/record_store.dart';
import 'package:patient_app/medicine/medicine_store.dart';
import 'package:patient_app/memory_passport/passport.dart';

class _Records extends RecordStore {
  _Records(this.records) : super(directory: () async => Directory.systemTemp);
  final List<CognitiveRecord> records;
  @override
  Future<List<CognitiveRecord>> loadAll() async => records;
}

class _Completions extends MedicineStore {
  _Completions(this.completed)
    : super(directory: () async => Directory.systemTemp);
  final Set<String> completed;
  @override
  Future<Set<String>> completedToday([DateTime? now]) async => completed;
}

void main() {
  testWidgets('shows local care and cognitive summaries', (tester) async {
    final now = DateTime(2026, 9, 7, 10);
    final record = CognitiveRecord(
      id: 'record-1',
      kind: RecordKind.familyRecognition,
      entryId: 'rahul',
      correct: false,
      responseMs: 1500,
      hintsUsed: 2,
      difficulty: 1,
      timestamp: now.subtract(const Duration(hours: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CaregiverDashboardScreen(
          passport: Passport.demo(),
          recordStore: _Records([record]),
          medicineStore: _Completions({'morning-medicine', 'breakfast'}),
          now: now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caregiver dashboard'), findsOneWidget);
    expect(find.text('Medicines confirmed'), findsOneWidget);
    expect(find.text('1 of 2'), findsNWidgets(2));
    expect(find.text('Exercises completed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('May need support', skipOffstage: false),
      300,
    );
    expect(find.text('May need support', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Family recognition', skipOffstage: false),
      300,
    );
    expect(
      find.text('Family recognition', skipOffstage: false),
      findsOneWidget,
    );
  });
}
