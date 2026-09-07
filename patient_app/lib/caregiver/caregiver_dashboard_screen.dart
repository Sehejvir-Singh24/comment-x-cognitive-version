import 'package:flutter/material.dart';

import '../cognition/cognitive_record.dart';
import '../cognition/record_store.dart';
import '../medicine/medicine_store.dart';
import '../medicine/reminder_bridge.dart';
import '../memory_passport/passport.dart';

/// A local-only view for a family member or caregiver.
///
/// This screen reads the same data that the patient app creates. Nothing is
/// uploaded, shared, or interpreted as a medical diagnosis.
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({
    super.key,
    required this.passport,
    this.recordStore,
    this.medicineStore,
    this.now,
  });

  final Passport passport;
  final RecordStore? recordStore;
  final MedicineStore? medicineStore;
  final DateTime? now;

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  late final RecordStore _recordStore = widget.recordStore ?? RecordStore();
  late final MedicineStore _medicineStore =
      widget.medicineStore ?? MedicineStore();
  _DashboardData? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _data = null;
    });
    try {
      final now = widget.now ?? DateTime.now();
      final results = await Future.wait<Object>([
        _recordStore.loadAll(),
        _medicineStore.completedToday(now),
      ]);
      if (!mounted) return;
      setState(
        () => _data = _DashboardData(
          passport: widget.passport,
          records: results[0] as List<CognitiveRecord>,
          completed: results[1] as Set<String>,
          now: now,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Caregiver dashboard'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _error != null
        ? _ErrorState(onRetry: _load)
        : _data == null
        ? const Center(child: CircularProgressIndicator())
        : _DashboardBody(data: _data!),
  );
}

class _DashboardData {
  const _DashboardData({
    required this.passport,
    required this.records,
    required this.completed,
    required this.now,
  });

  final Passport passport;
  final List<CognitiveRecord> records;
  final Set<String> completed;
  final DateTime now;

  List<CognitiveRecord> get recentRecords {
    final cutoff = now.subtract(const Duration(days: 7));
    return records
        .where((record) => !record.timestamp.isBefore(cutoff))
        .toList();
  }

  int get correctCount =>
      recentRecords.where((record) => record.correct).length;
  int get needsSupportCount => recentRecords
      .where((record) => !record.correct || record.hintsUsed >= 2)
      .length;

  List<_TodayItem> get todayItems {
    final routines = passport.entries
        .where((entry) => entry.kind == MemoryKind.routine)
        .map(
          (entry) => _TodayItem(
            entry.id,
            entry.name,
            entry.values['time'] ?? '',
            entry.name.toLowerCase().contains('medicine'),
          ),
        );
    final medicines = ReminderBridge.fromPassport(passport)
        .where(
          (medicine) => !passport.entries.any(
            (entry) =>
                entry.id == medicine.id && entry.kind == MemoryKind.routine,
          ),
        )
        .map(
          (medicine) =>
              _TodayItem(medicine.id, medicine.title, medicine.time, true),
        );
    return [...routines, ...medicines]
      ..sort((a, b) => a.time.compareTo(b.time));
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final items = data.todayItems;
    final medicineCount = items.where((item) => item.medicine).length;
    final medicinesDone = items
        .where((item) => item.medicine && data.completed.contains(item.id))
        .length;
    final routinesDone = items
        .where((item) => !item.medicine && data.completed.contains(item.id))
        .length;
    final records = data.recentRecords.reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${data.passport.name} — local overview',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'This information stays on this phone. It supports care; it is not a diagnosis.',
        ),
        const SizedBox(height: 20),
        _SectionTitle('Today'),
        _SummaryCard(
          icon: Icons.medication_outlined,
          title: 'Medicines confirmed',
          value: '$medicinesDone of $medicineCount',
          detail: medicineCount == 0
              ? 'No medicine times saved in Memory Passport.'
              : medicinesDone == medicineCount
              ? 'All scheduled medicines were confirmed.'
              : '${medicineCount - medicinesDone} still need confirmation.',
        ),
        _SummaryCard(
          icon: Icons.today_outlined,
          title: 'Daily routines completed',
          value:
              '$routinesDone of ${items.where((item) => !item.medicine).length}',
          detail: 'Based on the My Day checklist.',
        ),
        const SizedBox(height: 16),
        _SectionTitle('Cognitive activity — last 7 days'),
        _SummaryCard(
          icon: Icons.psychology_outlined,
          title: 'Exercises completed',
          value: '${data.recentRecords.length}',
          detail: data.recentRecords.isEmpty
              ? 'No cognitive exercises recorded yet.'
              : '${data.correctCount} answered correctly.',
        ),
        _SummaryCard(
          icon: Icons.support_outlined,
          title: 'May need support',
          value: '${data.needsSupportCount}',
          detail: data.needsSupportCount == 0
              ? 'No recent answers needed extra hints.'
              : 'Includes incorrect answers or exercises needing two or more hints.',
        ),
        const SizedBox(height: 16),
        _SectionTitle('Recent activity'),
        if (records.isEmpty)
          const _InfoCard(
            'Recent exercises will appear here after the patient uses Family or Watch.',
          ),
        for (final record in records.take(8))
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                record.correct
                    ? Icons.check_circle_outline
                    : Icons.help_outline,
                color: record.correct ? const Color(0xFF185A49) : null,
              ),
              title: Text(_recordLabel(record.kind)),
              subtitle: Text(
                '${record.correct ? 'Answered correctly' : 'Needed more support'} • ${record.hintsUsed} hint${record.hintsUsed == 1 ? '' : 's'} • ${_when(record.timestamp, data.now)}',
              ),
            ),
          ),
        const SizedBox(height: 16),
        _SectionTitle('Today’s plan'),
        if (items.isEmpty)
          const _InfoCard('No routines or medicines are saved yet.'),
        for (final item in items)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                item.medicine ? Icons.medication_outlined : Icons.schedule,
              ),
              title: Text(item.name.isEmpty ? 'Unnamed item' : item.name),
              subtitle: Text(item.time.isEmpty ? 'No time set' : item.time),
              trailing: Icon(
                data.completed.contains(item.id)
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: data.completed.contains(item.id)
                    ? const Color(0xFF185A49)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The local dashboard could not be loaded.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _TodayItem {
  const _TodayItem(this.id, this.name, this.time, this.medicine);
  final String id;
  final String name;
  final String time;
  final bool medicine;
}

String _recordLabel(RecordKind kind) => switch (kind) {
  RecordKind.familyRecognition => 'Family recognition',
  RecordKind.videoRecall => 'Video recall',
  RecordKind.routineRecall => 'Routine recall',
};

String _when(DateTime timestamp, DateTime now) {
  final difference = now.difference(timestamp);
  if (difference.inDays == 0) return 'Today';
  if (difference.inDays == 1) return 'Yesterday';
  return '${difference.inDays} days ago';
}
