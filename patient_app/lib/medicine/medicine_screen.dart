import 'package:flutter/material.dart';

import '../cognition/cognitive_engine.dart';
import '../cognition/cognitive_record.dart';
import '../cognition/record_store.dart';
import '../memory_passport/passport.dart';
import '../voice/speech_service.dart';
import 'medicine_store.dart';
import 'reminder_bridge.dart';

/// Senior-accessible Medicine Adherence & Routine Screen.
/// Displays prescribed medicines from Memory Passport with:
/// - Daily adherence progress ring.
/// - Time-of-day badges (Morning, Afternoon, Evening, Night).
/// - TTS voice read-aloud via SpeechService.
/// - Tactile adherence logging to RecordStore for caregiver insights.
/// - Interactive routine recall challenge.
class MedicineScreen extends StatefulWidget {
  const MedicineScreen({
    super.key,
    required this.passport,
    required this.recordStore,
    this.store,
    this.speech,
  });

  final Passport passport;
  final RecordStore recordStore;
  final MedicineStore? store;
  final SpeechService? speech;

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  late final MedicineStore _store = widget.store ?? MedicineStore();
  late final SpeechService _speech = widget.speech ?? SpeechService();
  final _engine = const CognitiveEngine();
  Set<String> _completed = {};
  bool _loading = false;
  bool _permissionGranted = false;
  bool _askedRecall = false;

  List<MedicineReminder> get _medicines =>
      ReminderBridge.fromPassport(widget.passport)
        ..sort((a, b) => a.time.compareTo(b.time));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final completed = await _store.completedToday();
      bool permission = false;
      try {
        permission = await ReminderBridge.notificationPermissionGranted();
      } catch (_) {
        permission = false;
      }
      if (mounted) {
        setState(() {
          _completed = completed;
          _permissionGranted = permission;
        });
      }
    } catch (_) {}
  }

  Future<void> _enableReminders() async {
    await ReminderBridge.requestNotificationPermission();
    await ReminderBridge.schedule(widget.passport);
    if (!mounted) return;
    _permissionGranted = await ReminderBridge.notificationPermissionGranted();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daily medicine reminders are active on this phone.'),
      ),
    );
  }

  Future<void> _speakMedicine(MedicineReminder medicine) async {
    final text =
        'At ${medicine.time}, your medicine is ${medicine.title}. ${medicine.instructions.isNotEmpty ? medicine.instructions : "Please take with a glass of water."}';
    try {
      await _speech.speak(text);
    } catch (_) {}
  }

  Future<void> _markTaken(MedicineReminder medicine) async {
    try {
      await _store.markCompleted(medicine.id);
    } catch (_) {}
    // Record adherence telemetry for the Caregiver Dashboard
    try {
      final records = await widget.recordStore.loadAll();
      final diff = _engine.difficulty(records, RecordKind.medicineRecall);
      await widget.recordStore.save(
        _engine.record(
          kind: RecordKind.medicineRecall,
          entryId: medicine.id,
          correct: true,
          responseMs: 0,
          hintsUsed: 0,
          difficulty: diff,
        ),
      );
    } catch (_) {}

    if (mounted) {
      setState(() => _completed = {..._completed, medicine.id});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF185A49),
          content: Text('Marked ${medicine.title} as taken. Well done!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _answerRecall(MedicineReminder medicine, bool remembered) async {
    if (_askedRecall) return;
    setState(() => _askedRecall = true);
    final difficulty = _engine.difficulty(
      await widget.recordStore.loadAll(),
      RecordKind.routineRecall,
    );
    await widget.recordStore.save(
      _engine.record(
        kind: RecordKind.routineRecall,
        entryId: medicine.id,
        correct: remembered,
        responseMs: 0,
        hintsUsed: remembered ? 0 : 1,
        difficulty: difficulty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicines = _medicines;
    final completedCount = _completed.length;
    final totalCount = medicines.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medicine Schedule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185A49),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // ── Adherence Hero Banner ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF153F34), Color(0xFF1F5C4D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x20000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: totalCount == 0
                                  ? 0
                                  : (completedCount / totalCount).clamp(0.0, 1.0),
                              strokeWidth: 6,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF4ADE80),
                              ),
                            ),
                          ),
                          Text(
                            totalCount == 0 ? '0%' : '${((completedCount / totalCount) * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              completedCount == totalCount && totalCount > 0
                                  ? 'All doses taken today!'
                                  : '$completedCount of $totalCount taken today',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              completedCount == totalCount && totalCount > 0
                                  ? 'Great job keeping healthy, ${widget.passport.name}.'
                                  : 'Follow the routine instructions below.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Reminder toggle button if notifications not enabled
                if (!_permissionGranted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        side: const BorderSide(color: Color(0xFF185A49), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: medicines.isEmpty ? null : _enableReminders,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text(
                        'Enable daily phone reminder alerts',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                if (medicines.isEmpty)
                  const _EmptyMedicineCard()
                else ...[
                  // ── Routine Recall Challenge ───────────────────────────
                  _RoutineRecallCard(
                    medicine: medicines.first,
                    answered: _askedRecall,
                    onAnswer: _answerRecall,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Prescribed Schedule',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF153F34),
                    ),
                  ),
                  const SizedBox(height: 12),

                  for (final medicine in medicines) ...[
                    _MedicineCard(
                      medicine: medicine,
                      completed: _completed.contains(medicine.id),
                      onTaken: () => _markTaken(medicine),
                      onSpeak: () => _speakMedicine(medicine),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ],
            ),
    );
  }
}

class _RoutineRecallCard extends StatelessWidget {
  const _RoutineRecallCard({
    required this.medicine,
    required this.answered,
    required this.onAnswer,
  });

  final MedicineReminder medicine;
  final bool answered;
  final Future<void> Function(MedicineReminder medicine, bool remembered)
      onAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB5D3C7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology_alt_outlined, color: Color(0xFF185A49)),
              SizedBox(width: 8),
              Text(
                'Memory Check',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF185A49),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'At ${medicine.time}, what do you normally do?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          if (!answered)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => onAnswer(medicine, false),
                    child: const Text('I am not sure', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF185A49),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => onAnswer(medicine, true),
                    child: const Text('Medicine', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF047857), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Correct! Your ${medicine.time} medicine reminder is detailed below.',
                      style: const TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.completed,
    required this.onTaken,
    required this.onSpeak,
  });

  final MedicineReminder medicine;
  final bool completed;
  final VoidCallback onTaken;
  final VoidCallback onSpeak;

  _TimeOfDayInfo _getTimeInfo(String timeStr) {
    final hour = int.tryParse(timeStr.split(':').first) ?? 9;
    if (hour < 12) {
      return const _TimeOfDayInfo('Morning', Icons.wb_sunny_outlined, Color(0xFFD97706));
    } else if (hour < 17) {
      return const _TimeOfDayInfo('Afternoon', Icons.wb_sunny_rounded, Color(0xFFB45309));
    } else if (hour < 21) {
      return const _TimeOfDayInfo('Evening', Icons.nights_stay_outlined, Color(0xFF4338CA));
    } else {
      return const _TimeOfDayInfo('Night', Icons.bedtime_outlined, Color(0xFF312E81));
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeInfo = _getTimeInfo(medicine.time);

    return Card(
      elevation: completed ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: completed ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: completed ? 2 : 1,
        ),
      ),
      color: completed ? const Color(0xFFF0FDF4) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Time badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: timeInfo.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(timeInfo.icon, size: 18, color: timeInfo.color),
                      const SizedBox(width: 6),
                      Text(
                        '${timeInfo.label} • ${medicine.time}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: timeInfo.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Audio Read Aloud Button
                IconButton.filledTonal(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_rounded, size: 22),
                  tooltip: 'Listen to instructions',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F0EC),
                    foregroundColor: const Color(0xFF185A49),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Medicine Name
            Text(
              medicine.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),

            if (medicine.instructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      medicine.instructions,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4B5563),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Tactile Adherence Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: completed
                  ? Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Taken for today ✓',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check_circle_outline, size: 24),
                      label: const Text(
                        'Mark as taken',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185A49),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOfDayInfo {
  const _TimeOfDayInfo(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class _EmptyMedicineCard extends StatelessWidget {
  const _EmptyMedicineCard();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: const [
          Icon(Icons.medication_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No medicine times are saved yet.\nA caregiver can add them in Memory Passport.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    ),
  );
}
