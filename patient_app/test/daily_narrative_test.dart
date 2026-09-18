import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/context/action_context.dart';
import 'package:patient_app/context/daily_narrative.dart';

void main() {
  test('summary counts selected events without exporting private event details', () {
    final day = DateTime(2026, 9, 15, 12);
    final events = [
      ActionEvent(id: '1', timestamp: day, type: 'VOICE_QUERY', source: 'saathi', action: 'private speech'),
      ActionEvent(id: '2', timestamp: day, type: 'DAY_ACTION', source: 'saathi', action: 'Medicine: private dosage'),
      ActionEvent(id: '3', timestamp: day, type: 'APP_OPEN', source: 'saathi', appName: 'Camera', intent: 'private reason'),
      ActionEvent(id: '4', timestamp: day, type: 'NOTIFICATION', source: 'notification', action: 'private sender'),
      ActionEvent(id: '5', timestamp: day, type: 'SHARED_LINK', source: 'share', action: 'https://private.example'),
    ];
    final narrative = DailyNarrative.fromEvents(events, day);
    expect(narrative.day, '2026-09-15');
    expect(narrative.text, contains('Camera'));
    for (final secret in ['private speech', 'private dosage', 'private reason', 'private sender', 'https://private.example']) {
      expect(narrative.text, isNot(contains(secret)));
    }
  });
}
