import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../cognition/cognitive_engine.dart';
import '../cognition/cognitive_record.dart';
import '../cognition/record_store.dart';
import '../l10n/app_localizations.dart';
import 'video_catalog.dart';
import 'video_entry.dart';

/// Entry point for the Watch / Video Recall exercise.
///
/// Flow:
/// 1. If a previous video was watched → delayed recall question first.
/// 2. Video selection grid.
/// 3. Video player.
/// 4. Immediate recall questions.
/// 5. Result overlay.
class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.recordStore, this.catalog});

  final RecordStore recordStore;

  /// Optional [VideoCatalog] override for testing.  When `null`, a default
  /// instance using [getApplicationDocumentsDirectory] is created.
  final VideoCatalog? catalog;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

enum _Phase {
  failed,
  loading,
  delayedRecall,
  selection,
  playing,
  recall,
  result,
}

class _WatchScreenState extends State<WatchScreen> {
  final _engine = const CognitiveEngine();
  late final VideoCatalog _catalog;

  _Phase _phase = _Phase.loading;
  int _difficulty = 2;

  // Delayed recall
  VideoEntry? _lastWatched;

  // Current video
  VideoEntry? _current;
  VideoPlayerController? _playerController;

  // Recall state
  final _answer = TextEditingController();
  int _questionIndex = 0;
  int _hintsShown = 0;
  bool _saving = false;
  late Stopwatch _timer;
  _RecallResult? _result;
  CognitiveRecord? _pendingRecord;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog ?? VideoCatalog();
    _timer = Stopwatch();
    _init();
  }

  Future<void> _init() async {
    // Load difficulty.
    try {
      final records = await widget.recordStore.loadAll();
      _difficulty = _engine.difficulty(records, RecordKind.videoRecall);
    } catch (_) {
      _saveError();
      return;
    }

    // Check for delayed recall.
    VideoEntry? last;
    try {
      last = await _catalog.lastWatched();
    } catch (_) {
      _saveError();
    }
    if (mounted) {
      setState(() {
        _lastWatched = last;
        _phase = last != null ? _Phase.delayedRecall : _Phase.selection;
      });
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  // ---------- delayed recall -------------------------------------------------

  void _skipDelayedRecall() {
    _commitDelayed(skipped: true);
  }

  Future<void> _commitDelayed({required bool skipped}) async {
    if (_saving || _lastWatched == null) return;
    setState(() => _saving = true);
    _timer.stop();

    final delayedQ = _lastWatched!.questions
        .where((q) => q.type == RecallType.delayed)
        .toList();
    final expected = delayedQ.isNotEmpty
        ? delayedQ.first.expectedAnswer
        : _lastWatched!.topic;
    final correct = skipped ? false : _matchAnswer(_answer.text, expected);

    final rec = _pendingRecord ??= _engine.record(
      kind: RecordKind.videoRecall,
      entryId: '${_lastWatched!.id}_delayed',
      correct: correct,
      responseMs: _timer.elapsedMilliseconds,
      hintsUsed: _hintsShown,
      difficulty: _difficulty,
    );

    try {
      await widget.recordStore.save(rec);
    } catch (_) {
      _saveError();
      return;
    }

    try {
      await _catalog.clearLastWatched();
    } catch (_) {
      _saveError();
      return;
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _result = _RecallResult(correct: correct, label: _lastWatched!.title);
        _phase = _Phase.result;
      });
    }
  }

  // ---------- video playback -------------------------------------------------

  Future<void> _selectVideo(VideoEntry video) async {
    setState(() {
      _current = video;
      _phase = _Phase.playing;
    });

    _playerController?.dispose();
    final controller = VideoPlayerController.asset(video.assetPath);
    _playerController = controller;
    controller.addListener(() {
      if (mounted && _phase == _Phase.playing) setState(() {});
    });

    try {
      await controller.initialize();
      if (mounted) {
        setState(() {});
        await controller.play();
      }
    } catch (_) {
      // Video may fail to load (e.g. placeholder file).
      if (mounted) setState(() => _phase = _Phase.selection);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed)),
        );
      }
    }
  }

  void _finishWatching() {
    _playerController?.pause();
    final immediateQuestions = _current!.questions
        .where((q) => q.type == RecallType.immediate)
        .toList();
    setState(() {
      _questionIndex = 0;
      _hintsShown = 0;
      _answer.clear();
      _timer
        ..reset()
        ..start();
      _phase = _Phase.recall;
      _result = null;
      _pendingRecord = null;
    });
    // If no immediate questions, go to result.
    if (immediateQuestions.isEmpty) {
      _phase = _Phase.result;
      _result = _RecallResult(correct: true, label: _current!.title);
    }
  }

  // ---------- immediate recall -----------------------------------------------

  List<RecallQuestion> get _immediateQuestions =>
      _current?.questions
          .where((q) => q.type == RecallType.immediate)
          .toList() ??
      [];

  Future<void> _commitImmediate({required bool skipped}) async {
    if (_saving) return;
    setState(() => _saving = true);
    _timer.stop();

    final questions = _immediateQuestions;
    final q = questions[_questionIndex];
    final correct = skipped
        ? false
        : _matchAnswer(_answer.text, q.expectedAnswer);

    final rec = _pendingRecord ??= _engine.record(
      kind: RecordKind.videoRecall,
      entryId: '${_current!.id}_q$_questionIndex',
      correct: correct,
      responseMs: _timer.elapsedMilliseconds,
      hintsUsed: _hintsShown,
      difficulty: _difficulty,
    );

    try {
      await widget.recordStore.save(rec);
    } catch (_) {
      _saveError();
      return;
    }

    // Mark as watched for delayed recall next time.
    if (_questionIndex + 1 < questions.length) {
      if (!mounted) return;
      setState(() {
        _pendingRecord = null;
        _questionIndex++;
        _saving = false;
        _answer.clear();
        _hintsShown = 0;
        _timer
          ..reset()
          ..start();
      });
      return;
    }
    try {
      await _catalog.markWatched(_current!);
    } catch (_) {
      _saveError();
      return;
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _result = _RecallResult(correct: correct, label: _current!.title);
        _phase = _Phase.result;
      });
    }
  }

  // ---------- answer matching (same as Family Recognition) -------------------

  bool _matchAnswer(String raw, String expected) {
    final answer = raw.trim().toLowerCase();
    final target = expected.trim().toLowerCase();
    if (answer.isEmpty) return false;
    if (target == answer) return true;
    // Accept the first word (e.g. "nature" matches "nature walk").
    final firstWord = target.split(' ').first;
    if (answer == firstWord) return true;
    // Accept if expected is contained in answer.

    return false;
  }

  // ---------- navigation helpers ---------------------------------------------

  void _saveError() {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not save or load this exercise. Please try again.',
        ),
      ),
    );
  }

  void _goToSelection() {
    setState(() {
      _phase = _Phase.selection;
      _result = null;
      _pendingRecord = null;
      _answer.clear();
      _hintsShown = 0;
      _questionIndex = 0;
    });
  }

  // ---------- hint text generation -------------------------------------------

  List<String> _videoHints(AppLocalizations s) {
    if (_current == null) return [];
    return [
      s.videoHint1,
      s.videoHint2(
        _immediateQuestions[_questionIndex].expectedAnswer[0].toUpperCase(),
      ),
    ];
  }

  List<String> _delayedHints(AppLocalizations s) {
    if (_lastWatched == null) return [];
    return [s.videoHint1, s.videoHint2(_lastWatched!.topic[0].toUpperCase())];
  }

  // ---------- build ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(s.watchTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: switch (_phase) {
              _Phase.failed => TextButton(
                onPressed: _init,
                child: const Text('Could not load exercises. Tap to retry.'),
              ),
              _Phase.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              _Phase.delayedRecall => _buildDelayedRecall(s),
              _Phase.selection => _buildSelection(s),
              _Phase.playing => _buildPlayer(s),
              _Phase.recall => _buildRecall(s),
              _Phase.result => _buildResult(s),
            },
          ),
        ),
      ),
    );
  }

  // ---------- delayed recall view --------------------------------------------

  Widget _buildDelayedRecall(AppLocalizations s) {
    if (_lastWatched == null) return const SizedBox.shrink();

    final hints = _delayedHints(s);

    // Start timer on first build.
    if (!_timer.isRunning) {
      _timer
        ..reset()
        ..start();
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.replay, size: 64),
        const SizedBox(height: 24),
        Text(
          s.delayedRecallPrompt,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          s.delayedRecallQuestion,
          style: const TextStyle(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _answer,
          enabled: !_saving,
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

        // Progressive hints
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

        if (_hintsShown < hints.length)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 20),
            ),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(s.showHint(_hintsShown + 1)),
            onPressed: _saving ? null : () => setState(() => _hintsShown++),
          ),
        const SizedBox(height: 20),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: (_saving || _answer.text.trim().isEmpty)
              ? null
              : () => _commitDelayed(skipped: false),
          child: Text(_saving ? s.saving : s.confirmAnswer),
        ),
        const SizedBox(height: 12),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          onPressed: _saving ? null : _skipDelayedRecall,
          child: Text(s.dontRemember),
        ),
      ],
    );
  }

  // ---------- video selection view -------------------------------------------

  Widget _buildSelection(AppLocalizations s) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          s.chooseVideo,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        for (final video in VideoCatalog.entries) ...[
          _VideoCard(video: video, onTap: () => _selectVideo(video)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ---------- video player view ----------------------------------------------

  Widget _buildPlayer(AppLocalizations s) {
    final controller = _playerController;
    final initialized = controller != null && controller.value.isInitialized;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (initialized) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          const SizedBox(height: 16),
          // Play/pause + progress
          Row(
            children: [
              IconButton(
                iconSize: 48,
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                ),
                onPressed: () {
                  setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  });
                },
              ),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(
            height: 260,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.check, size: 28),
          label: Text(s.finishedWatching),
          onPressed:
              initialized &&
                  !controller.value.hasError &&
                  controller.value.duration > Duration.zero &&
                  controller.value.position >= controller.value.duration
              ? _finishWatching
              : null,
        ),
      ],
    );
  }

  // ---------- immediate recall view ------------------------------------------

  Widget _buildRecall(AppLocalizations s) {
    final questions = _immediateQuestions;
    if (questions.isEmpty || _questionIndex >= questions.length) {
      return const Center(child: CircularProgressIndicator());
    }

    final q = questions[_questionIndex];
    final hints = _videoHints(s);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          s.immediateRecallPrompt(_current!.title),
          style: const TextStyle(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          q.text,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _answer,
          enabled: !_saving,
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

        // Progressive hints
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

        if (_hintsShown < hints.length)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 20),
            ),
            icon: const Icon(Icons.lightbulb_outline),
            label: Text(s.showHint(_hintsShown + 1)),
            onPressed: _saving ? null : () => setState(() => _hintsShown++),
          ),
        const SizedBox(height: 20),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: (_saving || _answer.text.trim().isEmpty)
              ? null
              : () => _commitImmediate(skipped: false),
          child: Text(_saving ? s.saving : s.confirmAnswer),
        ),
        const SizedBox(height: 12),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 20),
          ),
          onPressed: _saving ? null : () => _commitImmediate(skipped: true),
          child: Text(s.skipAnswer),
        ),
      ],
    );
  }

  // ---------- result view ----------------------------------------------------

  Widget _buildResult(AppLocalizations s) {
    if (_result == null) return const SizedBox.shrink();
    final color = _result!.correct
        ? const Color(0xFF1B6B3A)
        : Theme.of(context).colorScheme.error;
    final icon = _result!.correct
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;
    final label = _result!.correct ? s.correctAnswer : s.incorrectAnswer;

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
          _result!.label,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _goToSelection,
          child: Text(s.watchAnother),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 22),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.backHome),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Video selection card
// ---------------------------------------------------------------------------

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});
  final VideoEntry video;
  final VoidCallback onTap;

  static const _icons = <String, IconData>{
    'gardening': Icons.yard,
    'cooking': Icons.restaurant,
    'nature_walk': Icons.park,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[video.id] ?? Icons.play_circle_outline;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  video.title,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.play_circle_outline,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result data
// ---------------------------------------------------------------------------

class _RecallResult {
  const _RecallResult({required this.correct, required this.label});
  final bool correct;
  final String label;
}

