import 'dart:async';

import 'package:flutter/material.dart';

import '../memory_passport/passport.dart';
import '../context/action_context.dart';
import '../medicine/medicine_store.dart';
import '../medicine/reminder_bridge.dart';
import '../voice/speech_service.dart';

/// Senior-accessible "My Day" Timeline Screen.
/// Provides a clear chronological timeline of routines and medicines:
/// - Vertical timeline pins connecting daily habits.
/// - Dynamic "Next Up / Happening Now" highlight based on system time.
/// - Audio narration via SpeechService to read the full day's plan.
/// - Interactive routine checkoff with daily accomplishment progress.
class MyDayScreen extends StatefulWidget {
  const MyDayScreen({
    super.key,
    required this.passport,
    this.store,
    this.speech,
  });

  final Passport passport;
  final MedicineStore? store;
  final SpeechService? speech;

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  late final MedicineStore _store = widget.store ?? MedicineStore();
  late final SpeechService _speech = widget.speech ?? SpeechService();
  Set<String> _completed = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _store.completedToday();
      if (mounted) {
        setState(() {
          _completed = value;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleItem(String id) async {
    if (_completed.contains(id)) return;
    try {
      await _store.markCompleted(id);
    } catch (_) {}
    if (mounted) {
      setState(() => _completed = {..._completed, id});
    }
    unawaited(ActionContext.log(
      'DAY_ACTION',
      source: 'my_day',
      action: 'confirmed a task',
    ).catchError((Object _) {}));
  }

  Future<void> _readDayAloud(List<_DayItem> items) async {
    if (items.isEmpty) {
      await _speech.speak('You do not have any routines scheduled for today.');
      return;
    }
    final buffer = StringBuffer(
      'Hello ${widget.passport.name}. Here is your schedule for today: ',
    );
    for (final item in items) {
      final timeText = item.time.isNotEmpty ? 'at ${item.time}' : '';
      buffer.write('${item.name} $timeText. ');
    }
    buffer.write('Have a peaceful day.');
    try {
      await _speech.speak(buffer.toString());
    } catch (_) {}
  }

  List<_DayItem> _buildItems() {
    final list = <_DayItem>[
      ...widget.passport.entries
          .where((entry) => entry.kind == MemoryKind.routine)
          .map(
            (entry) => _DayItem(
              id: entry.id,
              name: entry.name,
              time: entry.values['time'] ?? '',
              isMedicine: false,
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
            (medicine) => _DayItem(
              id: medicine.id,
              name: medicine.title,
              time: medicine.time,
              isMedicine: true,
            ),
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  _DayItem? _findNextUp(List<_DayItem> items) {
    if (items.isEmpty) return null;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (final item in items) {
      if (_completed.contains(item.id)) continue;
      final parts = item.time.split(':');
      if (parts.length == 2) {
        final itemMinutes =
            (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        if (itemMinutes >= currentMinutes - 30) {
          return item;
        }
      }
    }
    // Fallback: first non-completed item
    return items.firstWhere(
      (i) => !_completed.contains(i.id),
      orElse: () => items.first,
    );
  }

  IconData _iconFor(String name, bool isMedicine) {
    if (isMedicine) return Icons.medication_outlined;
    final lower = name.toLowerCase();
    if (lower.contains('breakfast') || lower.contains('tea')) {
      return Icons.free_breakfast_outlined;
    }
    if (lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('meal')) {
      return Icons.restaurant_outlined;
    }
    if (lower.contains('walk') || lower.contains('exercise')) {
      return Icons.directions_walk_rounded;
    }
    if (lower.contains('garden') || lower.contains('plant')) {
      return Icons.yard_outlined;
    }
    if (lower.contains('call') ||
        lower.contains('visit') ||
        lower.contains('family')) {
      return Icons.people_outline;
    }
    if (lower.contains('sleep') ||
        lower.contains('bed') ||
        lower.contains('rest')) {
      return Icons.bedtime_outlined;
    }
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final nextUp = _findNextUp(items);
    final total = items.length;
    final done = items.where((i) => _completed.contains(i.id)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Day',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF185A49),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 28),
            tooltip: 'Read my schedule aloud',
            onPressed: () => _readDayAloud(items),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                // ── Daily Accomplishment Card ────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B4D3E), Color(0xFF285E4D)],
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
                              value: total == 0
                                  ? 0
                                  : (done / total).clamp(0.0, 1.0),
                              strokeWidth: 6,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF4ADE80),
                              ),
                            ),
                          ),
                          Text(
                            total == 0
                                ? '0%'
                                : '${((done / total) * 100).round()}%',
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
                              done == total && total > 0
                                  ? 'All routines completed!'
                                  : '$done of $total completed',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              done == total && total > 0
                                  ? 'You had a peaceful, wonderful day!'
                                  : 'Tap any activity when you finish it.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _readDayAloud(items),
                        icon: const Icon(Icons.volume_up, color: Colors.white),
                        tooltip: 'Read plan',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Today’s Timeline',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF153F34),
                  ),
                ),
                const SizedBox(height: 14),

                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No routines or medicines are saved yet.\nA caregiver can add them in Memory Passport.',
                        style: TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < items.length; i++) ...[
                    _TimelineItemRow(
                      item: items[i],
                      icon: _iconFor(items[i].name, items[i].isMedicine),
                      isCompleted: _completed.contains(items[i].id),
                      isNextUp: nextUp?.id == items[i].id,
                      isFirst: i == 0,
                      isLast: i == items.length - 1,
                      onToggle: () => _toggleItem(items[i].id),
                    ),
                  ],
              ],
            ),
    );
  }
}

class _TimelineItemRow extends StatelessWidget {
  const _TimelineItemRow({
    required this.item,
    required this.icon,
    required this.isCompleted,
    required this.isNextUp,
    required this.isFirst,
    required this.isLast,
    required this.onToggle,
  });

  final _DayItem item;
  final IconData icon;
  final bool isCompleted;
  final bool isNextUp;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline Node & Line ───────────────────────────────────────
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    width: isFirst ? 0 : 3,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                Container(
                  width: isNextUp ? 28 : 22,
                  height: isNextUp ? 28 : 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isNextUp
                        ? const Color(0xFF0284C7)
                        : Colors.white,
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF047857)
                          : isNextUp
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF94A3B8),
                      width: isNextUp ? 3 : 2,
                    ),
                    boxShadow: isNextUp
                        ? [
                            const BoxShadow(
                              color: Color(0x600284C7),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    width: isLast ? 0 : 3,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Card Content ───────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                elevation: isNextUp ? 3 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : isNextUp
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE2E8F0),
                    width: isNextUp ? 2 : 1,
                  ),
                ),
                color: isCompleted
                    ? const Color(0xFFF0FDF4)
                    : isNextUp
                    ? const Color(0xFFF0F9FF)
                    : Colors.white,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (isCompleted
                                        ? const Color(0xFF10B981)
                                        : isNextUp
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF185A49))
                                    .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            icon,
                            color: isCompleted
                                ? const Color(0xFF047857)
                                : isNextUp
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF185A49),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isNextUp && !isCompleted) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'NEXT UP',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isCompleted
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.time.isNotEmpty
                                    ? item.time
                                    : 'Flexible time',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isCompleted
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF4B5563),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onToggle,
                          icon: Icon(
                            isCompleted
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                            size: 30,
                          ),
                          tooltip: isCompleted ? 'Completed' : 'Mark complete',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayItem {
  const _DayItem({
    required this.id,
    required this.name,
    required this.time,
    required this.isMedicine,
  });

  final String id;
  final String name;
  final String time;
  final bool isMedicine;
}
