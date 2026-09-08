import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../memory_passport/passport.dart';
import '../cognition/cognitive_record.dart';

/// SQL is kept behind repositories; legacy snapshots remain recovery copies.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(File file) : super(NativeDatabase.createInBackground(file));
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await _createOutbox();
      await customStatement(
        'CREATE TABLE patient_profiles (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE memory_entries (id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE cognitive_records (id TEXT PRIMARY KEY, timestamp TEXT NOT NULL, payload TEXT NOT NULL)',
      );
      await customStatement(
        'CREATE TABLE video_sessions (id TEXT PRIMARY KEY, watched_at INTEGER NOT NULL, due_at INTEGER NOT NULL, completed INTEGER NOT NULL DEFAULT 0)',
      );
      await customStatement(
        'CREATE TABLE assistant_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      await _createDailyCompletions();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _createOutbox();
      if (from < 3) await _createDailyCompletions();
    },
  );

  Future<void> _createOutbox() => customStatement(
    'CREATE TABLE sync_outbox (seq INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, entity_id TEXT NOT NULL, payload TEXT NOT NULL)',
  );
  Future<void> _createDailyCompletions() => customStatement(
    'CREATE TABLE daily_completions (event_id TEXT NOT NULL, day TEXT NOT NULL, completed_at INTEGER NOT NULL, PRIMARY KEY(event_id, day))',
  );
  Future<void> enqueue(String kind, String id, Map<String, dynamic> payload) =>
      customStatement(
        'INSERT INTO sync_outbox(kind, entity_id, payload) VALUES (?, ?, ?)',
        [kind, id, jsonEncode(payload)],
      );

  static final Map<String, Future<void>> _queues = {};
  static Future<T> use<T>(
    Future<Directory> Function()? directory,
    Future<T> Function(AppDatabase db) action,
  ) async {
    final base = await (directory ?? getApplicationDocumentsDirectory)();
    await base.create(recursive: true);
    final path = '${base.path}/saathi.sqlite';
    final previous = _queues[path] ?? Future<void>.value();
    final next = previous.then((_) async {
      final db = AppDatabase(File(path));
      try {
        await db._importLegacy(base);
        return await action(db);
      } finally {
        await db.close();
      }
    });
    _queues[path] = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<String?> setting(String key) async {
    final rows = await customSelect(
      'SELECT value FROM assistant_settings WHERE key = ?',
      variables: [Variable(key)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('value');
  }

  Future<void> setSetting(String key, String value) => customStatement(
    'INSERT OR REPLACE INTO assistant_settings VALUES (?, ?)',
    [key, value],
  );

  Future<void> _importLegacy(Directory base) async {
    if (await setting('legacyImported') == '1') return;
    // Decode every source before touching patient tables. Never discard corruption.
    final folder = '${base.path}/memory_passport';
    final passportFile = File('$folder/passport.json');
    final recordsFile = File('$folder/records.json');
    final marker = File('$folder/last_watched.txt');
    final passport = await passportFile.exists()
        ? Passport.fromJson(
            jsonDecode(await passportFile.readAsString())
                as Map<String, dynamic>,
          )
        : Passport.demo();
    final records = <CognitiveRecord>[];
    if (await recordsFile.exists()) {
      final data =
          jsonDecode(await recordsFile.readAsString()) as Map<String, dynamic>;
      if (data['schemaVersion'] != 1) {
        throw const FormatException('Unsupported records version');
      }
      records.addAll(
        (data['records'] as List).map(
          (e) => CognitiveRecord.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    }
    await transaction(() async {
      await savePassport(passport);
      for (final record in records) {
        await saveRecord(record);
      }
      if (await marker.exists()) {
        final id = (await marker.readAsString()).trim();
        final time = (await marker.lastModified()).millisecondsSinceEpoch;
        await customStatement(
          'INSERT OR IGNORE INTO video_sessions VALUES (?, ?, ?, 0)',
          [id, time, time + const Duration(minutes: 5).inMilliseconds],
        );
      }
      await setSetting('legacyImported', '1');
    });
  }

  Future<Passport> loadPassport() async {
    final row = await customSelect(
      'SELECT payload FROM patient_profiles WHERE id = 1',
    ).getSingle();
    final data =
        jsonDecode(row.read<String>('payload')) as Map<String, dynamic>;
    data['entries'] = (await customSelect(
      'SELECT payload FROM memory_entries ORDER BY rowid',
    ).get()).map((r) => jsonDecode(r.read<String>('payload'))).toList();
    return Passport.fromJson(data);
  }

  Future<void> savePassport(Passport passport, {bool enqueueSync = true}) =>
      transaction(() async {
        final data = passport.toJson()..remove('entries');
        await customStatement(
          'INSERT OR REPLACE INTO patient_profiles VALUES (1, ?)',
          [jsonEncode(data)],
        );
        await customStatement('DELETE FROM memory_entries');
        if (enqueueSync && await setting('syncConsent') == 'yes') {
          final cloud = passport.toJson();
          cloud['entries'] = passport.entries
              .map((e) => e.toJson()..remove('photo'))
              .toList();
          await enqueue('passport', 'current', cloud);
        }
        for (final entry in passport.entries) {
          await customStatement('INSERT INTO memory_entries VALUES (?, ?, ?)', [
            entry.id,
            entry.kind.name,
            jsonEncode(entry.toJson()),
          ]);
        }
      });
  Future<void> saveRecord(CognitiveRecord record) => transaction(() async {
    final payload = jsonEncode(record.toJson());
    final old = await customSelect(
      'SELECT payload FROM cognitive_records WHERE id = ?',
      variables: [Variable(record.id)],
    ).get();
    if (old.isNotEmpty) {
      if (old.first.read<String>('payload') != payload) {
        throw const FormatException('Duplicate record identifier');
      }
      return;
    }
    await customStatement('INSERT INTO cognitive_records VALUES (?, ?, ?)', [
      record.id,
      record.timestamp.toIso8601String(),
      payload,
    ]);
    if (await setting('syncConsent') == 'yes') {
      await enqueue('records', record.id, record.toJson());
    }
  });
  Future<List<CognitiveRecord>> records() async =>
      (await customSelect(
            'SELECT payload FROM cognitive_records ORDER BY timestamp, rowid',
          ).get())
          .map(
            (r) => CognitiveRecord.fromJson(
              jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
            ),
          )
          .toList();

  Future<Set<String>> completedEventIds(DateTime day) async {
    final rows = await customSelect(
      'SELECT event_id FROM daily_completions WHERE day = ?',
      variables: [Variable(_dayKey(day))],
    ).get();
    return rows.map((row) => row.read<String>('event_id')).toSet();
  }

  Future<List<Map<String, dynamic>>> dailyCompletionPayloads() async {
    final rows = await customSelect(
      'SELECT event_id, day, completed_at FROM daily_completions '
      'ORDER BY day, completed_at',
    ).get();
    return rows
        .map(
          (row) => <String, dynamic>{
            'schemaVersion': 1,
            'eventId': row.read<String>('event_id'),
            'day': row.read<String>('day'),
            'completedAt': row.read<int>('completed_at'),
            'source': 'patient',
          },
        )
        .toList();
  }

  /// Completion is local and idempotent. It never changes a medicine dose or
  /// suppresses a reminder; it only records that the patient or caregiver
  /// confirmed today's task.
  Future<void> markEventCompleted(String eventId, DateTime day) =>
      transaction(() async {
        final dayKey = _dayKey(day);
        final completedAt = DateTime.now().millisecondsSinceEpoch;
        await customStatement(
          'INSERT OR REPLACE INTO daily_completions VALUES (?, ?, ?)',
          [eventId, dayKey, completedAt],
        );
        if (await setting('syncConsent') == 'yes') {
          final documentId = '$dayKey--$eventId'.replaceAll('/', '_');
          await enqueue('dailyCompletions', documentId, {
            'schemaVersion': 1,
            'eventId': eventId,
            'day': dayKey,
            'completedAt': completedAt,
            'source': 'patient',
          });
        }
      });

  static String _dayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
