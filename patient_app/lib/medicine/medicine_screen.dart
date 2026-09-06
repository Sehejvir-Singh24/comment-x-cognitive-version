import 'package:flutter/material.dart';

import '../cognition/cognitive_engine.dart';
import '../cognition/cognitive_record.dart';
import '../cognition/record_store.dart';
import '../memory_passport/passport.dart';
import 'medicine_store.dart';
import 'reminder_bridge.dart';

class MedicineScreen extends StatefulWidget {
  const MedicineScreen({
    super.key,
    required this.passport,
    required this.recordStore,
    this.store,
  });

  final Passport passport;
  final RecordStore recordStore;
  final MedicineStore? store;

  @override
  State<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends State<MedicineScreen> {
  late final MedicineStore _store = widget.store ?? MedicineStore();
  final _engine = const CognitiveEngine();
  Set<String> _completed = {};
  bool _loading = true;
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
    final values = await Future.wait<Object>([
      _store.completedToday(),
      ReminderBridge.notificationPermissionGranted(),
    ]);
    if (mounted) {
      setState(() {
        _completed = values[0] as Set<String>;
        _permissionGranted = values[1] as bool;
        _loading = false;
      });
    }
  }

  Future<void> _enableReminders() async {
    await ReminderBridge.requestNotificationPermission();
    await ReminderBridge.schedule(widget.passport);
    if (!mounted) return;
    // Android shows its permission sheet asynchronously. Keep the button
    // visible until the next screen visit if permission was declined.
    _permissionGranted = await ReminderBridge.notificationPermissionGranted();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daily medicine reminders are set on this phone.'),
      ),
    );
  }

  Future<void> _markTaken(MedicineReminder medicine) async {
    await _store.markCompleted(medicine.id);
    if (mounted) setState(() => _completed = {..._completed, medicine.id});
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
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Today’s medicine',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use this as a reminder. Follow the caregiver’s instructions. Do not change a dose here.',
                ),
                const SizedBox(height: 20),
                if (!_permissionGranted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: FilledButton.icon(
                      onPressed: medicines.isEmpty ? null : _enableReminders,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Enable phone reminders'),
                    ),
                  ),
                if (medicines.isEmpty)
                  const _EmptyMedicineCard()
                else ...[
                  _RoutineRecallCard(
                    medicine: medicines.first,
                    answered: _askedRecall,
                    onAnswer: _answerRecall,
                  ),
                  const SizedBox(height: 16),
                  for (final medicine in medicines) ...[
                    _MedicineCard(
                      medicine: medicine,
                      completed: _completed.contains(medicine.id),
                      onTaken: () => _markTaken(medicine),
                    ),
                    const SizedBox(height: 12),
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
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFE5F1EC),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A small memory exercise',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('At ${medicine.time}, what do you normally do?'),
          const SizedBox(height: 14),
          if (!answered)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onAnswer(medicine, false),
                    child: const Text('I am not sure'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onAnswer(medicine, true),
                    child: const Text('Medicine'),
                  ),
                ),
              ],
            )
          else
            Text(
              'Your ${medicine.time} medicine reminder is shown below.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    ),
  );
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.medicine,
    required this.completed,
    required this.onTaken,
  });
  final MedicineReminder medicine;
  final bool completed;
  final VoidCallback onTaken;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medicine.time,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          Text(medicine.title, style: const TextStyle(fontSize: 24)),
          if (medicine.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(medicine.instructions),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: completed ? null : onTaken,
            icon: Icon(
              completed ? Icons.check_circle : Icons.check_circle_outline,
            ),
            label: Text(completed ? 'Marked taken today' : 'Mark as taken'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyMedicineCard extends StatelessWidget {
  const _EmptyMedicineCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        'No medicine times are saved yet. A caregiver can add them in Memory Passport.',
      ),
    ),
  );
}
