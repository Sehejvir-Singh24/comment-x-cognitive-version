import 'package:flutter/services.dart';

import '../memory_passport/passport.dart';

class MedicineReminder {
  const MedicineReminder({
    required this.id,
    required this.title,
    required this.time,
    required this.instructions,
  });

  final String id;
  final String title;
  final String time;
  final String instructions;

  Map<String, String> toMap() => {
    'id': id,
    'title': title,
    'time': time,
    'instructions': instructions,
  };
}

/// Native Android is used only to schedule the operating system notification.
/// All patient-facing screens and medicine logic stay in Flutter.
class ReminderBridge {
  static const _channel = MethodChannel('org.saathi/reminders');

  static List<MedicineReminder> fromPassport(Passport passport) => passport
      .entries
      .where(
        (entry) =>
            entry.kind == MemoryKind.medicine ||
            (entry.kind == MemoryKind.routine &&
                entry.name.toLowerCase().contains('medicine')),
      )
      .where((entry) => _validTime(entry.values['time']))
      .map(
        (entry) => MedicineReminder(
          id: entry.id,
          title: entry.name.isEmpty ? 'Medicine' : entry.name,
          time: entry.values['time']!,
          instructions: entry.values['instructions'] ?? '',
        ),
      )
      .toList();

  static Future<void> schedule(Passport passport) =>
      _channel.invokeMethod<void>('schedule', {
        'reminders': fromPassport(passport)
            .map((item) => item.toMap())
            .toList(),
      });

  static Future<void> requestNotificationPermission() =>
      _channel.invokeMethod<void>('requestPermission');

  static Future<bool> notificationPermissionGranted() async =>
      await _channel.invokeMethod<bool>('permissionGranted') ?? false;

  static bool _validTime(String? value) {
    if (value == null || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)) {
      return false;
    }
    final parts = value.split(':').map(int.parse).toList();
    return parts[0] < 24 && parts[1] < 60;
  }
}
