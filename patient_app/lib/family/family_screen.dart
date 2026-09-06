import 'dart:math';

import 'package:flutter/material.dart';

import '../cognition/cognitive_engine.dart';
import '../cognition/cognitive_record.dart';
import '../cognition/record_store.dart';
import '../l10n/app_localizations.dart';
import '../memory_passport/passport.dart';
import '../memory_passport/passport_screen.dart';
import '../memory_passport/passport_store.dart';

/// Entry point for the Family Recognition exercise.
///
/// Navigated to from the main launcher.  Requires [PassportStore] to render
/// family photos and [RecordStore] to save interaction metrics.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({
    super.key,
    required this.passport,
    required this.passportStore,
    required this.recordStore,
  });

  final Passport passport;
  final PassportStore passportStore;
  final RecordStore recordStore;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _engine = const CognitiveEngine();
  List<MemoryEntry> _candidates = [];
  MemoryEntry? _initial;
  int _difficulty = 2;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Find family entries that have a saved photo.
    final candidates = widget.passport.entries
        .where((e) => e.kind == MemoryKind.family && e.photo != null)
        .toList();

    // Load existing records to determine current difficulty.
    int difficulty = 2;
    try {
      final records = await widget.recordStore.loadAll();
      difficulty = _engine.difficulty(records, RecordKind.familyRecognition);
    } catch (_) {
      // If records are unreadable, fall back to medium.
    }

    if (mounted) {
      setState(() {
        _candidates = candidates;
        _initial = candidates.isNotEmpty
            ? candidates[Random().nextInt(candidates.length)]
            : null;
        _difficulty = difficulty;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.family)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_candidates.isEmpty || _initial == null) {
      return _NoPhotosView(passportStore: widget.passportStore);
    }

    return _QuestionView(
      initial: _initial!,
      candidates: _candidates,
      passportStore: widget.passportStore,
      recordStore: widget.recordStore,
      difficulty: _difficulty,
      engine: _engine,
    );
  }
}

// ---------------------------------------------------------------------------
// No-photos guard
// ---------------------------------------------------------------------------

class _NoPhotosView extends StatelessWidget {
  const _NoPhotosView({required this.passportStore});
  final PassportStore passportStore;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.family)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_outline, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    s.noFamilyPhotos,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.noFamilyPhotosDetail,
                    style: const TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(72),
                      textStyle: const TextStyle(fontSize: 22),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 28),
                    label: Text(s.addPhotoInPassport),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question view (stateful — owns the timer, answer, hint state)
// ---------------------------------------------------------------------------

class _QuestionView extends StatefulWidget {
  const _QuestionView({
    required this.initial,
    required this.candidates,
    required this.passportStore,
    required this.recordStore,
    required this.difficulty,
    required this.engine,
  });

  final MemoryEntry initial;
  final List<MemoryEntry> candidates;
  final PassportStore passportStore;
  final RecordStore recordStore;
  final int difficulty;
  final CognitiveEngine engine;

  @override
  State<_QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<_QuestionView> {
  late MemoryEntry _entry;
  late final TextEditingController _answer;
  late final Stopwatch _timer;
  int _hintsShown = 0; // 0..3 — how many hints are visible
  bool _saving = false;
  _ResultData? _result; // non-null after answer committed

  @override
  void initState() {
    super.initState();
    _entry = widget.initial;
    _answer = TextEditingController();
    _timer = Stopwatch()..start();
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  // ---- hint text generation ------------------------------------------------

  List<String> _hints(AppLocalizations s) {
    final name = _entry.values['name'] ?? '';
    final relationship = _entry.values['relationship'] ?? '';
    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return [
      s.hint1Template,
      s.hint2Template(relationship),
      s.hint3Template(firstLetter),
    ];
  }

  // ---- answer evaluation ---------------------------------------------------

  bool _isCorrect(String raw) {
    final answer = raw.trim().toLowerCase();
    final name = (_entry.values['name'] ?? '').trim().toLowerCase();
    if (answer.isEmpty) return false;
    if (name == answer) return true;
    // Accept the first word of the name (e.g. "Rahul" matches "Rahul Bora").
    final firstName = name.split(' ').first;
    return answer == firstName;
  }

  // ---- commit answer -------------------------------------------------------

  Future<void> _commit({required bool skipped}) async {
    if (_saving) return;
    setState(() => _saving = true);
    _timer.stop();

    final correct = skipped ? false : _isCorrect(_answer.text);
    final hintsUsed = skipped ? _hintsShown : _hintsShown;

    final rec = widget.engine.record(
      kind: RecordKind.familyRecognition,
      entryId: _entry.id,
      correct: correct,
      responseMs: _timer.elapsedMilliseconds,
      hintsUsed: hintsUsed,
      difficulty: widget.difficulty,
    );

    try {
      await widget.recordStore.save(rec);
    } catch (_) {
      // Record loss is non-critical for the patient experience; continue.
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _result = _ResultData(correct: correct, entry: _entry);
      });
    }
  }

  // ---- "try another" -------------------------------------------------------

  void _tryAnother() {
    final pool = widget.candidates.where((e) => e.id != _entry.id).toList();
    final next = pool.isNotEmpty
        ? pool[Random().nextInt(pool.length)]
        : widget.candidates[Random().nextInt(widget.candidates.length)];
    setState(() {
      _entry = next;
      _answer.clear();
      _hintsShown = 0;
      _saving = false;
      _result = null;
      _timer
        ..reset()
        ..start();
    });
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.family)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: _result != null
                ? _ResultView(
                    data: _result!,
                    passportStore: widget.passportStore,
                    onTryAnother: _tryAnother,
                    onBack: () => Navigator.of(context).pop(),
                    s: s,
                  )
                : _buildQuestion(s),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(AppLocalizations s) {
    final hints = _hints(s);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ---- Family photo --------------------------------------------------
        PassportPhoto(store: widget.passportStore, photo: _entry.photo),
        const SizedBox(height: 24),

        // ---- Prompt --------------------------------------------------------
        Text(
          s.whoIsThis,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // ---- Answer field --------------------------------------------------
        TextField(
          controller: _answer,
          enabled: !_saving,
          autofocus: false,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 24),
          decoration: InputDecoration(
            labelText: s.typeYourAnswer,
            labelStyle: const TextStyle(fontSize: 20),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // ---- Progressive hints --------------------------------------------
        if (_hintsShown > 0)
          for (int i = 0; i < _hintsShown; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${s.hintLabel} ${i + 1}: ${hints[i]}',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

        // ---- Show next hint button ----------------------------------------
        if (_hintsShown < 3)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 20),
            ),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(s.showHint(_hintsShown + 1)),
            onPressed: _saving
                ? null
                : () => setState(() => _hintsShown++),
          ),
        const SizedBox(height: 20),

        // ---- Confirm button -----------------------------------------------
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          onPressed: (_saving || _answer.text.trim().isEmpty)
              ? null
              : () => _commit(skipped: false),
          child: Text(_saving ? s.saving : s.confirmAnswer),
        ),
        const SizedBox(height: 12),

        // ---- Skip button ---------------------------------------------------
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          onPressed: _saving ? null : () => _commit(skipped: true),
          child: Text(s.skipAnswer),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result overlay
// ---------------------------------------------------------------------------

class _ResultData {
  const _ResultData({required this.correct, required this.entry});
  final bool correct;
  final MemoryEntry entry;
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.data,
    required this.passportStore,
    required this.onTryAnother,
    required this.onBack,
    required this.s,
  });

  final _ResultData data;
  final PassportStore passportStore;
  final VoidCallback onTryAnother;
  final VoidCallback onBack;
  final AppLocalizations s;

  @override
  Widget build(BuildContext context) {
    final color = data.correct
        ? const Color(0xFF1B6B3A)
        : Theme.of(context).colorScheme.error;
    final icon = data.correct ? Icons.check_circle_outline : Icons.cancel_outlined;
    final label = data.correct ? s.correctAnswer : s.incorrectAnswer;
    final name = data.entry.values['name'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Icon(icon, size: 80, color: color),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PassportPhoto(store: passportStore, photo: data.entry.photo),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          onPressed: onTryAnother,
          child: Text(s.tryAnother),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 22),
          ),
          onPressed: onBack,
          child: Text(s.backHome),
        ),
      ],
    );
  }
}
