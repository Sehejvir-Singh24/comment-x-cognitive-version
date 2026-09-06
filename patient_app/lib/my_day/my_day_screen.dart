import 'package:flutter/material.dart';

import '../memory_passport/passport.dart';
import '../medicine/medicine_store.dart';
import '../medicine/reminder_bridge.dart';

class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key, required this.passport, this.store});
  final Passport passport;
  final MedicineStore? store;

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  late final MedicineStore _store = widget.store ?? MedicineStore();
  Set<String> _completed = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await _store.completedToday();
    if (mounted) setState(() => _completed = value);
  }

  @override
  Widget build(BuildContext context) {
    final items = <_DayItem>[
      ...widget.passport.entries
          .where((entry) => entry.kind == MemoryKind.routine)
          .map(
            (entry) => _DayItem(
              entry.id,
              entry.name,
              entry.values['time'] ?? '',
              false,
            ),
          ),
      ...ReminderBridge.fromPassport(widget.passport)
          .where(
            (medicine) => !widget.passport.entries.any(
              (entry) =>
                  entry.id == medicine.id && entry.kind == MemoryKind.routine,
            ),
          )
          .map(
            (medicine) =>
                _DayItem(medicine.id, medicine.title, medicine.time, true),
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return Scaffold(
      appBar: AppBar(title: const Text('My Day')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Today',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Your simple plan for the day.'),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No routines are saved yet. Add them in Memory Passport.',
                ),
              ),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: Icon(
                    item.medicine ? Icons.medication_outlined : Icons.schedule,
                    size: 34,
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item.time.isEmpty ? 'No time set' : item.time,
                    style: const TextStyle(fontSize: 20),
                  ),
                  trailing: _completed.contains(item.id)
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF185A49),
                          size: 32,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayItem {
  const _DayItem(this.id, this.name, this.time, this.medicine);
  final String id;
  final String name;
  final String time;
  final bool medicine;
}
