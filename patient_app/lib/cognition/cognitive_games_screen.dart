import 'dart:io';

import 'package:flutter/material.dart';

import '../memory_passport/passport.dart';
import '../voice/speech_service.dart';
import 'cognitive_engine.dart';
import 'cognitive_game_generator.dart';
import 'cognitive_record.dart';
import 'record_store.dart';

class CognitiveGamesScreen extends StatefulWidget {
  const CognitiveGamesScreen({
    super.key,
    required this.passport,
    required this.recordStore,
    this.engine = const CognitiveEngine(),
    this.generator = const CognitiveGameGenerator(),
    this.initialKind,
    this.speechService,
  });

  final Passport passport;
  final RecordStore recordStore;
  final CognitiveEngine engine;
  final CognitiveGameGenerator generator;
  final RecordKind? initialKind;
  final SpeechService? speechService;

  @override
  State<CognitiveGamesScreen> createState() => _CognitiveGamesScreenState();
}

class _CognitiveGamesScreenState extends State<CognitiveGamesScreen> {
  late final SpeechService _speech;
  bool _ownsSpeech = false;

  List<CognitiveQuestion> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  int _difficulty = 2;
  RecordKind? _selectedCategory;

  // Question state
  final Stopwatch _timer = Stopwatch();
  int? _selectedIndex;
  bool _answered = false;
  bool _isCorrect = false;
  bool _showHint = false;
  int _hintsUsed = 0;
  int _correctCount = 0;
  bool _gameCompleted = false;

  @override
  void initState() {
    super.initState();
    if (widget.speechService != null) {
      _speech = widget.speechService!;
    } else {
      _speech = SpeechService();
      _ownsSpeech = true;
    }
    _selectedCategory = widget.initialKind;
    _startNewGame(_selectedCategory);
  }

  @override
  void dispose() {
    _timer.stop();
    if (_ownsSpeech) {
      _speech.dispose();
    }
    super.dispose();
  }

  Future<void> _startNewGame(RecordKind? category) async {
    setState(() {
      _loading = true;
      _gameCompleted = false;
      _currentIndex = 0;
      _correctCount = 0;
      _selectedCategory = category;
    });

    int difficulty = 2;
    try {
      final records = await widget.recordStore.loadAll();
      final targetKind = category ?? RecordKind.familyRecognition;
      difficulty = widget.engine.difficulty(records, targetKind);
    } catch (_) {}

    final questions = widget.generator.generateQuestions(
      widget.passport,
      count: 3,
      difficulty: difficulty,
      filterKind: category,
    );

    if (mounted) {
      setState(() {
        _difficulty = difficulty;
        _questions = questions;
        _loading = false;
        _resetQuestionState();
      });
      _speakCurrentQuestion();
    }
  }

  void _resetQuestionState() {
    _selectedIndex = null;
    _answered = false;
    _isCorrect = false;
    _showHint = false;
    _hintsUsed = 0;
    _timer
      ..reset()
      ..start();
  }

  void _speakCurrentQuestion() {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;
    final q = _questions[_currentIndex];
    _speech.speak(q.question);
  }

  Future<void> _onOptionSelected(int index) async {
    if (_answered && _isCorrect) return;

    final q = _questions[_currentIndex];
    final isCorrect = (index == q.correctIndex);
    _timer.stop();

    setState(() {
      _selectedIndex = index;
      _answered = true;
      _isCorrect = isCorrect;
      if (!isCorrect) {
        _showHint = true;
        _hintsUsed++;
      } else {
        _correctCount++;
      }
    });

    final rec = widget.engine.record(
      kind: q.kind,
      entryId: q.entryId,
      correct: isCorrect,
      responseMs: _timer.elapsedMilliseconds,
      hintsUsed: _hintsUsed,
      difficulty: _difficulty,
    );

    try {
      await widget.recordStore.save(rec);
    } catch (_) {}

    if (isCorrect) {
      _speech.speak('Wonderful! ${q.explanation}');
    } else {
      _speech.speak('Almost! ${q.hint}');
    }
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _resetQuestionState();
      });
      _speakCurrentQuestion();
    } else {
      setState(() {
        _gameCompleted = true;
      });
      final name = widget.passport.name.isNotEmpty ? widget.passport.name : '';
      _speech.speak('Great job $name! You have finished today’s memory exercises.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        title: const Text('Saathi Memory Games'),
        backgroundColor: const Color(0xFF185A49),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Read question aloud',
            onPressed: _speakCurrentQuestion,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _gameCompleted
            ? _buildCompletionView()
            : _buildQuestionView(),
      ),
    );
  }

  Widget _buildQuestionView() {
    if (_questions.isEmpty) {
      return const Center(child: Text('No questions available.'));
    }

    final q = _questions[_currentIndex];
    final categoryName = switch (q.kind) {
      RecordKind.familyRecognition => 'Family & Friends',
      RecordKind.medicineRecall => 'Medication & Health',
      RecordKind.routineRecall => 'Daily Routine',
      RecordKind.episodicRecall => 'Life Memories',
      _ => 'Memory Exercise',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Category badge and progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                backgroundColor: const Color(0xFFE8F0EC),
                avatar: Icon(q.icon ?? Icons.psychology, size: 20, color: const Color(0xFF185A49)),
                label: Text(
                  categoryName,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF185A49)),
                ),
              ),
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Optional Photo Preview
          if (q.photoPath != null && q.photoPath!.isNotEmpty) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Image.file(
                    File(q.photoPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackIcon(q.icon),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(q.icon ?? Icons.help_outline, size: 48, color: const Color(0xFF185A49)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Question Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  q.question,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A332B),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _speakCurrentQuestion,
                  icon: const Icon(Icons.volume_up, size: 20),
                  label: const Text('Listen again', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options List
          ...List.generate(q.options.length, (index) {
            final option = q.options[index];
            final isSelected = (_selectedIndex == index);
            final isCorrectAnswer = (index == q.correctIndex);

            Color bgColor = Colors.white;
            Color borderColor = const Color(0xFFD4DFD9);
            Color textColor = const Color(0xFF153F34);
            IconData? trailingIcon;

            if (_answered) {
              if (isSelected) {
                if (_isCorrect) {
                  bgColor = const Color(0xFFD7EBDD);
                  borderColor = const Color(0xFF2E7D4E);
                  textColor = const Color(0xFF155724);
                  trailingIcon = Icons.check_circle;
                } else {
                  bgColor = const Color(0xFFFBE8E8);
                  borderColor = const Color(0xFFC93B3B);
                  textColor = const Color(0xFF721C24);
                  trailingIcon = Icons.close;
                }
              } else if (isCorrectAnswer && !_isCorrect) {
                // Highlight correct answer gently if patient chose wrong
                borderColor = const Color(0xFF2E7D4E);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                key: ValueKey('option_$index'),
                onTap: () => _onOptionSelected(index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (trailingIcon != null)
                        Icon(trailingIcon, color: borderColor, size: 28),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Hint or Explanation banner
          if (_answered) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.stars : Icons.lightbulb_outline,
                    color: _isCorrect ? const Color(0xFF2E7D4E) : const Color(0xFF856404),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isCorrect ? q.explanation : 'Hint: ${q.hint}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _isCorrect ? const Color(0xFF155724) : const Color(0xFF856404),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF185A49),
                minimumSize: const Size.fromHeight(60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _nextQuestion,
              icon: Icon(_isCorrect ? Icons.arrow_forward : Icons.refresh),
              label: Text(
                _isCorrect
                    ? (_currentIndex + 1 < _questions.length ? 'Next Question' : 'Complete Game')
                    : 'Try Next Question',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(IconData? icon) {
    return Container(
      color: const Color(0xFFE8F0EC),
      child: Center(child: Icon(icon ?? Icons.person, size: 64, color: const Color(0xFF185A49))),
    );
  }

  Widget _buildCompletionView() {
    final name = widget.passport.name.isNotEmpty ? widget.passport.name : 'friend';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 54,
              backgroundColor: Color(0xFFD7EBDD),
              child: Icon(Icons.celebration, size: 64, color: Color(0xFF185A49)),
            ),
            const SizedBox(height: 24),
            Text(
              'Wonderful, $name!',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF185A49),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You completed your memory exercises for today! You got $_correctCount of ${_questions.length} right on the first try.',
              style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Category Buttons
            const Text(
              'Play another round:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.shuffle, size: 18),
                  label: const Text('Random Mix'),
                  onPressed: () => _startNewGame(null),
                ),
                ActionChip(
                  avatar: const Icon(Icons.people, size: 18),
                  label: const Text('Family'),
                  onPressed: () => _startNewGame(RecordKind.familyRecognition),
                ),
                ActionChip(
                  avatar: const Icon(Icons.medication, size: 18),
                  label: const Text('Medicine'),
                  onPressed: () => _startNewGame(RecordKind.medicineRecall),
                ),
                ActionChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: const Text('Routine'),
                  onPressed: () => _startNewGame(RecordKind.routineRecall),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF185A49),
                minimumSize: const Size.fromHeight(64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
