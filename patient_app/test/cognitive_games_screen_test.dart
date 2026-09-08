import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/cognition/cognitive_games_screen.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/cognition/record_store.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/voice/speech_service.dart';

class _FakeRecordStore extends RecordStore {
  _FakeRecordStore() : super(directory: () async => Directory.systemTemp);

  final saved = <CognitiveRecord>[];

  @override
  Future<List<CognitiveRecord>> loadAll() async => saved;

  @override
  Future<void> save(CognitiveRecord record) async => saved.add(record);
}

class _FakeSpeechService extends SpeechService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> dispose() async {}
}

Widget buildTestableScreen({
  required Passport passport,
  required RecordStore recordStore,
  required SpeechService speechService,
  Future<void> Function(int correct, int total)? onCompleted,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: CognitiveGamesScreen(
      passport: passport,
      recordStore: recordStore,
      speechService: speechService,
      onCompleted: onCompleted,
    ),
  );
}

void main() {
  group('CognitiveGamesScreen widget tests', () {
    testWidgets('renders question view with options and audio speech', (
      tester,
    ) async {
      final recordStore = _FakeRecordStore();
      final speech = _FakeSpeechService();
      final passport = Passport.demo();

      await tester.pumpWidget(
        buildTestableScreen(
          passport: passport,
          recordStore: recordStore,
          speechService: speech,
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and question progress
      expect(find.text('Saathi Memory Games'), findsOneWidget);
      expect(find.textContaining('Question 1 of 3'), findsOneWidget);

      // Verify speech service spoke the question
      expect(speech.spoken, isNotEmpty);
    });

    testWidgets('selecting an answer commits record to store', (tester) async {
      final recordStore = _FakeRecordStore();
      final speech = _FakeSpeechService();
      final passport = Passport.demo();

      await tester.pumpWidget(
        buildTestableScreen(
          passport: passport,
          recordStore: recordStore,
          speechService: speech,
        ),
      );
      await tester.pumpAndSettle();

      // Find an option container and tap it
      final optionFinder = find.byKey(const ValueKey('option_0'));
      expect(optionFinder, findsOneWidget);

      // Tap the first option
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      // Verify a CognitiveRecord was saved to record store
      expect(recordStore.saved.length, 1);
      expect(recordStore.saved.first.difficulty, 2);

      // Next question or complete game button is visible
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('reports the final score when a remote game completes', (
      tester,
    ) async {
      final recordStore = _FakeRecordStore();
      final speech = _FakeSpeechService();
      int? completedCorrect;
      int? completedTotal;

      await tester.pumpWidget(
        buildTestableScreen(
          passport: Passport.demo(),
          recordStore: recordStore,
          speechService: speech,
          onCompleted: (correct, total) async {
            completedCorrect = correct;
            completedTotal = total;
          },
        ),
      );
      await tester.pumpAndSettle();

      for (var question = 0; question < 3; question++) {
        await tester.tap(find.byKey(const ValueKey('option_0')));
        await tester.pumpAndSettle();
        final next = find.byType(FilledButton).last;
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }

      expect(completedCorrect, isNotNull);
      expect(completedTotal, 3);
      expect(
        find.textContaining('You completed your memory exercises'),
        findsOneWidget,
      );
    });
  });
}
