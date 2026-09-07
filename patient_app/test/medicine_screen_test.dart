import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/cognition/record_store.dart';
import 'package:patient_app/medicine/medicine_screen.dart';
import 'package:patient_app/medicine/medicine_store.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/voice/speech_service.dart';

class FakeRecordStore extends RecordStore {
  final List<CognitiveRecord> saved = [];

  @override
  Future<List<CognitiveRecord>> loadAll() async => List.unmodifiable(saved);

  @override
  Future<void> save(CognitiveRecord record) async {
    saved.add(record);
  }
}

class FakeSpeechService extends SpeechService {
  String? lastSpoken;

  @override
  Future<void> speak(String text) async {
    lastSpoken = text;
  }
}

class FakeMedicineStore extends MedicineStore {
  final Set<String> completed = {};

  @override
  Future<Set<String>> completedToday([DateTime? now]) async => Set.from(completed);

  @override
  Future<void> markCompleted(String eventId, [DateTime? now]) async => completed.add(eventId);
}

void main() {
  group('MedicineScreen Widget Tests', () {
    late Passport testPassport;
    late FakeRecordStore fakeRecordStore;
    late FakeMedicineStore fakeMedicineStore;
    late FakeSpeechService fakeSpeech;

    setUp(() {
      fakeRecordStore = FakeRecordStore();
      fakeMedicineStore = FakeMedicineStore();
      fakeSpeech = FakeSpeechService();

      testPassport = Passport.demo();
    });

    testWidgets('renders medicine schedule with progress bar and time badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MedicineScreen(
            passport: testPassport,
            recordStore: fakeRecordStore,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and hero counter
      expect(find.text('Medicine Schedule'), findsOneWidget);
      expect(find.textContaining('taken today'), findsOneWidget);

      // Check memory recall challenge
      expect(find.text('Memory Check'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Medicine'), findsOneWidget);
      expect(find.text('I am not sure'), findsOneWidget);

      // Check medicine cards (e.g. 09:00 Medicine, 20:00 Medicine)
      expect(find.textContaining('09:00'), findsWidgets);
      expect(find.textContaining('Morning'), findsWidgets);
    });

    testWidgets('tapping Mark as taken logs adherence record and updates UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MedicineScreen(
            passport: testPassport,
            recordStore: fakeRecordStore,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find first "Mark as taken" button and ensure visible
      final markButton = find.widgetWithText(ElevatedButton, 'Mark as taken').first;
      await tester.ensureVisible(markButton);
      await tester.pumpAndSettle();

      await tester.tap(markButton);
      await tester.pumpAndSettle();

      // Should show confirmed state
      expect(find.text('Taken for today ✓', skipOffstage: false), findsWidgets);

      // Verify adherence was recorded in RecordStore
      expect(fakeRecordStore.saved.isNotEmpty, isTrue);
      expect(fakeRecordStore.saved.first.kind, RecordKind.medicineRecall);
      expect(fakeRecordStore.saved.first.correct, isTrue);
    });

    testWidgets('tapping audio speaker icon calls SpeechService', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MedicineScreen(
            passport: testPassport,
            recordStore: fakeRecordStore,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final speakerButton = find.byIcon(Icons.volume_up_rounded).first;
      await tester.ensureVisible(speakerButton);
      await tester.pumpAndSettle();

      await tester.tap(speakerButton);
      await tester.pump();

      expect(fakeSpeech.lastSpoken, isNotNull);
      expect(fakeSpeech.lastSpoken, contains('medicine is'));
    });

    testWidgets('answering routine recall challenge records outcome', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MedicineScreen(
            passport: testPassport,
            recordStore: fakeRecordStore,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Medicine" on the recall check
      final recallButton = find.widgetWithText(FilledButton, 'Medicine');
      expect(recallButton, findsOneWidget);
      await tester.tap(recallButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Correct! Your'), findsOneWidget);
      expect(
        fakeRecordStore.saved.any((r) => r.kind == RecordKind.routineRecall && r.correct),
        isTrue,
      );
    });
  });
}
