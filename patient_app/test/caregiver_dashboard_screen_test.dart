import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/caregiver/caregiver_dashboard_screen.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/cognition/record_store.dart';
import 'package:patient_app/medicine/medicine_store.dart';
import 'package:patient_app/memory_passport/passport.dart';

class FakeRecordStore extends RecordStore {
  final List<CognitiveRecord> fakeRecords = [];
  @override
  Future<List<CognitiveRecord>> loadAll() async => fakeRecords;
}

class FakeMedicineStore extends MedicineStore {
  @override
  Future<Set<String>> completedToday([DateTime? now]) async => {'test_med'};
}

void main() {
  group('CaregiverDashboardScreen Tests', () {
    testWidgets('renders overview, cloud sync card, and recent activity', (
      tester,
    ) async {
      final passport = Passport.demo();
      final recordStore = FakeRecordStore();
      final medicineStore = FakeMedicineStore();

      bool syncEnabled = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CaregiverDashboardScreen(
            passport: passport,
            recordStore: recordStore,
            medicineStore: medicineStore,
            now: DateTime(2026, 9, 8, 10, 0),
            isSyncEnabled: () async => syncEnabled,
            getSyncUid: () async => 'test_uid_12345',
            getPendingSyncCount: () async => 2,
            setSyncEnabled: (val) async => syncEnabled = val,
            onSyncNow: () async => 2,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Caregiver dashboard'), findsOneWidget);
      expect(find.text('${passport.name} — local overview'), findsOneWidget);
      expect(find.text('Cloud sync & Caretaker portal'), findsOneWidget);
      expect(find.text('Firebase: Connected (hiasaathi)'), findsOneWidget);
      expect(find.text('Link code: test_uid_12345'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('2 changes waiting to sync'), findsOneWidget);
      expect(find.text('Sync Now to Cloud'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Medicines confirmed'), findsOneWidget);

      // Tap Sync Now
      await tester.tap(find.text('Sync Now to Cloud'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Synced 2 item(s) to Firebase Firestore!'),
        findsOneWidget,
      );
    });
  });
}
