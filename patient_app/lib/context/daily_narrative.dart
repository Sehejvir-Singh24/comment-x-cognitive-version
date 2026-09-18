import '../storage/app_database.dart';
import '../sync/sync_service.dart';
import 'action_context.dart';

class DailyNarrative {
  const DailyNarrative(this.day, this.lines);
  final String day;
  final List<String> lines;

  static DailyNarrative fromEvents(List<ActionEvent> events, DateTime now) {
    final day =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final today =
        events
            .where(
              (e) =>
                  e.timestamp.year == now.year &&
                  e.timestamp.month == now.month &&
                  e.timestamp.day == now.day,
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final lines = <String>[];
    final opened = today.where((e) => e.type == 'APP_OPEN').toList();
    final confirmed = today.where((e) => e.type == 'DAY_ACTION').length;
    final questions = today.where((e) => e.type == 'VOICE_QUERY').length;
    if (confirmed > 0) {
      lines.add(
        '$confirmed My Day task${confirmed == 1 ? '' : 's'} confirmed on the phone.',
      );
    }
    if (questions > 0) {
      lines.add(
        'Asked Saathi $questions question${questions == 1 ? '' : 's'}.',
      );
    }
    if (opened.isNotEmpty) {
      final names = opened
          .map((e) => e.appName)
          .whereType<String>()
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .take(4)
          .toList();
      lines.add(
        names.isEmpty
            ? 'Opened ${opened.length} app${opened.length == 1 ? '' : 's'} from Saathi.'
            : 'Opened ${names.join(', ')} from Saathi.',
      );
    }
    if (lines.isEmpty) {
      lines.add('No selected Saathi actions were saved today.');
    }
    return DailyNarrative(day, lines);
  }

  String get text => lines.join('\n');

  // The raw events, intentions, URLs, notification contents and speech are not sent.
  Future<void> share() async {
    if (!await ActionContext.enabled()) {
      throw StateError('Action memory is off.');
    }
    if (!await SyncService.enabled()) throw StateError('Cloud sync is off.');
    await AppDatabase.use(
      null,
      (db) => db.enqueue('dailyNarratives', day, {
        'day': day,
        'lines': lines,
        'sharedAt': DateTime.now().toUtc().toIso8601String(),
        'source': 'patient_selected_summary',
      }),
    );
    await SyncService.flush();
  }
}
