import 'dart:math';

import 'package:flutter/material.dart';

import '../memory_passport/passport.dart';
import 'cognitive_record.dart';

class CognitiveQuestion {
  const CognitiveQuestion({
    required this.id,
    required this.kind,
    required this.entryId,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.hint,
    this.photoPath,
    this.icon,
  });

  final String id;
  final RecordKind kind;
  final String entryId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String hint;
  final String? photoPath;
  final IconData? icon;

  String get correctAnswer => options[correctIndex];
}

class CognitiveGameGenerator {
  const CognitiveGameGenerator();

  /// Generates a randomized list of [count] questions based on the [passport].
  ///
  /// [difficulty]: 1 = 2 options, 2 = 3 options, 3 = 4 options.
  /// [filterKind]: optional filter to restrict questions to a specific category.
  List<CognitiveQuestion> generateQuestions(
    Passport passport, {
    int count = 3,
    int difficulty = 2,
    RecordKind? filterKind,
    Random? random,
  }) {
    final rng = random ?? Random();
    final optionCount = switch (difficulty) {
      1 => 2,
      3 => 4,
      _ => 3,
    };

    final pool = <CognitiveQuestion>[];

    if (filterKind == null || filterKind == RecordKind.familyRecognition) {
      pool.addAll(_generateFamilyQuestions(passport, optionCount, rng));
    }
    if (filterKind == null || filterKind == RecordKind.medicineRecall) {
      pool.addAll(_generateMedicineQuestions(passport, optionCount, rng));
    }
    if (filterKind == null || filterKind == RecordKind.routineRecall) {
      pool.addAll(_generateRoutineQuestions(passport, optionCount, rng));
    }
    if (filterKind == null || filterKind == RecordKind.episodicRecall) {
      pool.addAll(_generateEpisodicQuestions(passport, optionCount, rng));
    }

    if (pool.isEmpty) {
      // Fallback in case passport is empty or has minimal data.
      pool.add(_fallbackQuestion(passport, optionCount));
    }

    pool.shuffle(rng);
    return pool.take(count).toList();
  }

  List<CognitiveQuestion> _generateFamilyQuestions(
    Passport passport,
    int optionCount,
    Random rng,
  ) {
    final questions = <CognitiveQuestion>[];
    final family =
        passport.entries.where((e) => e.kind == MemoryKind.family).toList();
    if (family.isEmpty) return questions;

    final familyNames = family.map((e) => e.name).toSet().toList();
    const commonNames = ['Rahul', 'Ananya', 'Meera', 'Amit', 'Priya', 'Vikram', 'Sunita'];

    for (final member in family) {
      final rel = member.values['relationship'] ?? 'Family Member';

      // 1. Photo identification question (if photo present)
      if (member.photo != null && member.photo!.isNotEmpty) {
        final distractors = _pickDistractors(
          member.name,
          [...familyNames, ...commonNames],
          optionCount - 1,
          rng,
        );
        final choices = [member.name, ...distractors]..shuffle(rng);
        questions.add(
          CognitiveQuestion(
            id: 'fam_photo_${member.id}',
            kind: RecordKind.familyRecognition,
            entryId: member.id,
            question: 'Who is this in the photo?',
            options: choices,
            correctIndex: choices.indexOf(member.name),
            photoPath: member.photo,
            icon: Icons.person,
            hint: 'This is your $rel.',
            explanation: '${member.name} is your $rel.',
          ),
        );
      }

      // 2. Relationship question
      const commonRel = ['Son', 'Daughter', 'Wife', 'Husband', 'Brother', 'Sister', 'Friend', 'Caregiver'];
      final relDistractors = _pickDistractors(
        rel,
        commonRel,
        optionCount - 1,
        rng,
      );
      final relChoices = [rel, ...relDistractors]..shuffle(rng);
      questions.add(
        CognitiveQuestion(
          id: 'fam_rel_${member.id}',
          kind: RecordKind.familyRecognition,
          entryId: member.id,
          question: 'What is your relationship to ${member.name}?',
          options: relChoices,
          correctIndex: relChoices.indexOf(rel),
          icon: Icons.favorite_border,
          photoPath: member.photo,
          hint: 'Think about how ${member.name} is related to your family.',
          explanation: '${member.name} is your $rel.',
        ),
      );

      // 3. Shared activity / visit day question
      final activity = member.values['sharedActivity'];
      if (activity != null && activity.isNotEmpty) {
        const otherActivities = ['Cricket', 'Chess', 'Gardening', 'Walking', 'Cooking', 'Music'];
        final actDistractors = _pickDistractors(
          activity,
          otherActivities,
          optionCount - 1,
          rng,
        );
        final actChoices = [activity, ...actDistractors]..shuffle(rng);
        questions.add(
          CognitiveQuestion(
            id: 'fam_act_${member.id}',
            kind: RecordKind.familyRecognition,
            entryId: member.id,
            question: 'What activity do you enjoy sharing with ${member.name}?',
            options: actChoices,
            correctIndex: actChoices.indexOf(activity),
            icon: Icons.sports_cricket,
            hint: 'It is a sport or pastime you both enjoy.',
            explanation: 'You and ${member.name} enjoy $activity together.',
          ),
        );
      }

      final visits = member.values['visits'];
      if (visits != null && visits.isNotEmpty) {
        const days = ['Sunday', 'Monday', 'Wednesday', 'Friday', 'Saturday'];
        final dayDistractors = _pickDistractors(
          visits,
          days,
          optionCount - 1,
          rng,
        );
        final dayChoices = [visits, ...dayDistractors]..shuffle(rng);
        questions.add(
          CognitiveQuestion(
            id: 'fam_visit_${member.id}',
            kind: RecordKind.familyRecognition,
            entryId: member.id,
            question: 'On which day does ${member.name} usually come to visit?',
            options: dayChoices,
            correctIndex: dayChoices.indexOf(visits),
            icon: Icons.calendar_today,
            hint: 'It is usually on the weekend.',
            explanation: '${member.name} usually visits on $visits.',
          ),
        );
      }
    }

    return questions;
  }

  List<CognitiveQuestion> _generateMedicineQuestions(
    Passport passport,
    int optionCount,
    Random rng,
  ) {
    final questions = <CognitiveQuestion>[];
    final meds = passport.entries
        .where(
          (e) =>
              e.kind == MemoryKind.medicine ||
              (e.kind == MemoryKind.routine &&
                  (e.name.toLowerCase().contains('medicine') ||
                      e.name.toLowerCase().contains('med'))),
        )
        .toList();

    const sampleTimes = ['08:00', '09:00', '13:00', '17:00', '20:00', '21:30'];

    for (final med in meds) {
      final time = med.values['time'];
      if (time != null && time.isNotEmpty) {
        final distractors = _pickDistractors(
          time,
          sampleTimes,
          optionCount - 1,
          rng,
        );
        final choices = [time, ...distractors]..shuffle(rng);
        questions.add(
          CognitiveQuestion(
            id: 'med_time_${med.id}',
            kind: RecordKind.medicineRecall,
            entryId: med.id,
            question: 'At what time is your ${med.name} scheduled?',
            options: choices,
            correctIndex: choices.indexOf(time),
            icon: Icons.medication_outlined,
            hint: 'Check whether it is morning, afternoon, or evening.',
            explanation: 'Your ${med.name} is scheduled for $time.',
          ),
        );
      }
    }

    for (final med in meds) {
      final time = med.values['time'];
      if (time != null && time.isNotEmpty) {
        const otherRoutines = ['Morning Walk', 'Reading the paper', 'Breakfast', 'Afternoon Nap', 'Gardening'];
        final nameDistractors = _pickDistractors(
          med.name,
          [...otherRoutines, 'Evening Tea'],
          optionCount - 1,
          rng,
        );
        final choices = [med.name, ...nameDistractors]..shuffle(rng);
        questions.add(
          CognitiveQuestion(
            id: 'med_sched_${med.id}',
            kind: RecordKind.medicineRecall,
            entryId: med.id,
            question: 'What health routine is scheduled for $time?',
            options: choices,
            correctIndex: choices.indexOf(med.name),
            icon: Icons.alarm_on,
            hint: 'It is related to your daily medications or health.',
            explanation: '${med.name} is scheduled at $time.',
          ),
        );
      }
    }

    return questions;
  }

  List<CognitiveQuestion> _generateRoutineQuestions(
    Passport passport,
    int optionCount,
    Random rng,
  ) {
    final questions = <CognitiveQuestion>[];
    final routines =
        passport.entries.where((e) => e.kind == MemoryKind.routine).toList();
    if (routines.isEmpty) return questions;

    const allTimes = ['08:00', '09:00', '12:30', '17:00', '19:00', '21:00'];
    final routineNames = routines.map((e) => e.name).toList();

    for (final r in routines) {
      final time = r.values['time'];
      if (time != null && time.isNotEmpty) {
        final distractors = _pickDistractors(
          time,
          allTimes,
          optionCount - 1,
          rng,
        );
        final choices = [time, ...distractors]..shuffle(rng);
        questions.add(
          CognitiveQuestion(
            id: 'routine_time_${r.id}',
            kind: RecordKind.routineRecall,
            entryId: r.id,
            question: 'Around what time do you usually do ${r.name}?',
            options: choices,
            correctIndex: choices.indexOf(time),
            icon: Icons.schedule,
            hint: 'Think about your daily rhythm for ${r.name}.',
            explanation: '${r.name} is usually at $time.',
          ),
        );
      }

      const genericActivities = ['Breakfast', 'Morning Walk', 'Lunch', 'Evening Walk', 'Dinner'];
      final actDistractors = _pickDistractors(
        r.name,
        [...routineNames, ...genericActivities],
        optionCount - 1,
        rng,
      );
      final choices = [r.name, ...actDistractors]..shuffle(rng);
      questions.add(
        CognitiveQuestion(
          id: 'routine_name_${r.id}',
          kind: RecordKind.routineRecall,
          entryId: r.id,
          question: time != null && time.isNotEmpty
              ? 'What do you usually do at $time?'
              : 'Which of these is part of your daily routine?',
          options: choices,
          correctIndex: choices.indexOf(r.name),
          icon: Icons.checklist_rtl,
          hint: 'It is part of your regular day.',
          explanation: '${r.name} is part of your saved daily routine.',
        ),
      );
    }

    return questions;
  }

  List<CognitiveQuestion> _generateEpisodicQuestions(
    Passport passport,
    int optionCount,
    Random rng,
  ) {
    final questions = <CognitiveQuestion>[];

    final places =
        passport.entries.where((e) => e.kind == MemoryKind.place).toList();
    for (final p in places) {
      const otherPlaces = [
        'Kamakhya Temple',
        'Kaziranga Park',
        'Riverfront Walk',
        'Tea Gardens',
        'Central Park',
      ];
      final distractors = _pickDistractors(
        p.name,
        otherPlaces,
        optionCount - 1,
        rng,
      );
      final choices = [p.name, ...distractors]..shuffle(rng);
      questions.add(
        CognitiveQuestion(
          id: 'place_${p.id}',
          kind: RecordKind.episodicRecall,
          entryId: p.id,
          question: 'Which of these is one of your special, saved places?',
          options: choices,
          correctIndex: choices.indexOf(p.name),
          icon: Icons.place_outlined,
          hint: 'It is a memorable place you enjoy visiting.',
          explanation: '${p.name} is one of your treasured places.',
        ),
      );
    }

    final activities =
        passport.entries.where((e) => e.kind == MemoryKind.activity).toList();
    for (final a in activities) {
      const otherActivities = [
        'Gardening',
        'Reading',
        'Listening to music',
        'Painting',
        'Walking in the park',
      ];
      final distractors = _pickDistractors(
        a.name,
        otherActivities,
        optionCount - 1,
        rng,
      );
      final choices = [a.name, ...distractors]..shuffle(rng);
      questions.add(
        CognitiveQuestion(
          id: 'activity_${a.id}',
          kind: RecordKind.episodicRecall,
          entryId: a.id,
          question: 'What is one of your favorite hobbies or activities?',
          options: choices,
          correctIndex: choices.indexOf(a.name),
          icon: Icons.spa_outlined,
          hint: 'It brings you peace and joy in your free time.',
          explanation: '${a.name} is one of your favorite activities.',
        ),
      );
    }

    if (passport.region.isNotEmpty) {
      const regions = ['Assam', 'Bengal', 'Punjab', 'Kerala', 'Maharashtra', 'Gujarat'];
      final distractors = _pickDistractors(
        passport.region,
        regions,
        optionCount - 1,
        rng,
      );
      final choices = [passport.region, ...distractors]..shuffle(rng);
      questions.add(
        CognitiveQuestion(
          id: 'patient_region',
          kind: RecordKind.episodicRecall,
          entryId: 'region',
          question: 'Which region or home state is in your Memory Passport?',
          options: choices,
          correctIndex: choices.indexOf(passport.region),
          icon: Icons.map_outlined,
          hint: 'Think about where your roots and family home are.',
          explanation: 'Your home region is ${passport.region}.',
        ),
      );
    }

    return questions;
  }

  CognitiveQuestion _fallbackQuestion(Passport passport, int optionCount) {
    final name = passport.name.isNotEmpty ? passport.name : 'Mr. Bora';
    const otherNames = ['Mr. Sharma', 'Mr. Verma', 'Mr. Das', 'Mr. Sen'];
    final distractors = otherNames.take(optionCount - 1).toList();
    final choices = [name, ...distractors]..shuffle();
    return CognitiveQuestion(
      id: 'fallback_name',
      kind: RecordKind.episodicRecall,
      entryId: 'name',
      question: 'What name does Saathi address you by?',
      options: choices,
      correctIndex: choices.indexOf(name),
      icon: Icons.account_circle_outlined,
      hint: 'It is your own name.',
      explanation: 'You are $name.',
    );
  }

  List<String> _pickDistractors(
    String target,
    List<String> candidates,
    int needed,
    Random rng,
  ) {
    final available = candidates
        .where((c) => c.toLowerCase() != target.toLowerCase())
        .toSet()
        .toList();
    available.shuffle(rng);

    if (available.length >= needed) {
      return available.take(needed).toList();
    }

    final result = List<String>.from(available);
    var padIndex = 1;
    while (result.length < needed) {
      final pad = 'Option $padIndex';
      if (!result.contains(pad) && pad.toLowerCase() != target.toLowerCase()) {
        result.add(pad);
      }
      padIndex++;
    }
    return result;
  }
}
