import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/cognition/cognitive_game_generator.dart';
import 'package:patient_app/cognition/cognitive_record.dart';
import 'package:patient_app/memory_passport/passport.dart';

void main() {
  group('CognitiveGameGenerator', () {
    const generator = CognitiveGameGenerator();
    final passport = Passport.demo();

    test('generates requested number of questions', () {
      final questions = generator.generateQuestions(passport, count: 4);
      expect(questions.length, 4);
    });

    test('respects difficulty levels for option counts', () {
      // Difficulty 1 -> 2 options
      final easy = generator.generateQuestions(passport, count: 5, difficulty: 1);
      for (final q in easy) {
        expect(q.options.length, 2);
        expect(q.correctIndex, inInclusiveRange(0, 1));
        expect(q.options[q.correctIndex], isNotEmpty);
      }

      // Difficulty 2 -> 3 options
      final med = generator.generateQuestions(passport, count: 5, difficulty: 2);
      for (final q in med) {
        expect(q.options.length, 3);
        expect(q.correctIndex, inInclusiveRange(0, 2));
      }

      // Difficulty 3 -> 4 options
      final hard = generator.generateQuestions(passport, count: 5, difficulty: 3);
      for (final q in hard) {
        expect(q.options.length, 4);
        expect(q.correctIndex, inInclusiveRange(0, 3));
      }
    });

    test('filters questions by RecordKind when requested', () {
      final famQuestions = generator.generateQuestions(
        passport,
        count: 5,
        filterKind: RecordKind.familyRecognition,
      );
      for (final q in famQuestions) {
        expect(q.kind, RecordKind.familyRecognition);
      }

      final medQuestions = generator.generateQuestions(
        passport,
        count: 5,
        filterKind: RecordKind.medicineRecall,
      );
      for (final q in medQuestions) {
        expect(q.kind, RecordKind.medicineRecall);
      }
    });

    test('handles empty or minimal passport gracefully with fallback', () {
      const minimalPassport = Passport(
        name: 'Asha',
        age: 68,
        region: '',
        entries: [],
      );

      final questions = generator.generateQuestions(
        minimalPassport,
        count: 2,
        difficulty: 2,
        random: Random(42),
      );

      expect(questions, isNotEmpty);
      expect(questions.first.question, contains('name'));
      expect(questions.first.options.length, 3);
      expect(questions.first.options[questions.first.correctIndex], 'Asha');
    });
  });
}
