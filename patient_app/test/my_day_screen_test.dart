import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/medicine/medicine_store.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/my_day/my_day_screen.dart';
import 'package:patient_app/voice/speech_service.dart';

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
  group('MyDayScreen Widget Tests', () {
    late Passport testPassport;
    late FakeMedicineStore fakeMedicineStore;
    late FakeSpeechService fakeSpeech;

    setUp(() {
      testPassport = Passport.demo();
      fakeMedicineStore = FakeMedicineStore();
      fakeSpeech = FakeSpeechService();
    });

    testWidgets('renders daily timeline items and accomplishment header', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyDayScreen(
            passport: testPassport,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Day'), findsOneWidget);
      expect(find.text('Today’s Timeline'), findsOneWidget);
      expect(find.textContaining('completed'), findsWidgets);

      // Check routines from demo passport (Breakfast, Medicine, Walk)
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Medicine'), findsWidgets);
      expect(find.text('Walk'), findsOneWidget);
    });

    testWidgets('tapping a timeline item marks it as completed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyDayScreen(
            passport: testPassport,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Breakfast item, scroll to it, and tap
      final breakfastItem = find.text('Breakfast');
      await tester.ensureVisible(breakfastItem);
      await tester.pumpAndSettle();

      await tester.tap(breakfastItem);
      await tester.pumpAndSettle();

      // Breakfast should now be registered in fake store
      expect(fakeMedicineStore.completed, contains('breakfast'));

      // Checkmark icon should now be displayed
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });

    testWidgets('tapping read schedule button triggers speech audio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MyDayScreen(
            passport: testPassport,
            store: fakeMedicineStore,
            speech: fakeSpeech,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final readButton = find.byIcon(Icons.volume_up_rounded);
      expect(readButton, findsOneWidget);

      await tester.tap(readButton);
      await tester.pump();

      expect(fakeSpeech.lastSpoken, isNotNull);
      expect(fakeSpeech.lastSpoken, contains('schedule for today'));
      expect(fakeSpeech.lastSpoken, contains('Breakfast'));
    });
  });
}
