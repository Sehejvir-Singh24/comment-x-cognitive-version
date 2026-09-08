import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/storage/app_database.dart';
import 'package:patient_app/memory_passport/passport.dart';

void main() {
  late Directory folder;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('saathi-migration-');
  });
  tearDown(() async {
    await folder.delete(recursive: true);
  });
  test(
    'bad legacy records preserve source and allow corrected import',
    () async {
      final legacy = Directory('${folder.path}/memory_passport');
      await legacy.create();
      final source = File('${legacy.path}/passport.json');
      await source.writeAsString(jsonEncode(Passport.demo().toJson()));
      final records = File('${legacy.path}/records.json');
      await records.writeAsString('broken');
      await expectLater(
        AppDatabase.use(() async => folder, (db) => db.loadPassport()),
        throwsA(anything),
      );
      expect(await source.exists(), isTrue);
      await records.writeAsString(
        jsonEncode({'schemaVersion': 1, 'records': []}),
      );
      final passport = await AppDatabase.use(
        () async => folder,
        (db) => db.loadPassport(),
      );
      expect(passport.name, Passport.demo().name);
      expect(await records.exists(), isTrue);
    },
  );
  test('outbox needs consent and omits photo paths', () async {
    await AppDatabase.use(() async => folder, (db) async {
      await db.savePassport(Passport.demo());
      expect(await db.customSelect('SELECT * FROM sync_outbox').get(), isEmpty);
      await db.setSetting('syncConsent', 'yes');
      await db.savePassport(Passport.demo());
      final rows = await db
          .customSelect('SELECT payload FROM sync_outbox')
          .get();
      expect(rows, hasLength(1));
      final payload = jsonDecode(rows.single.read<String>('payload')) as Map;
      for (final entry in payload['entries'] as List) {
        expect((entry as Map).containsKey('photo'), isFalse);
      }
    });
  });
  test(
    'failed passport transaction rolls back queued upload and local changes',
    () async {
      await AppDatabase.use(() async => folder, (db) async {
        await db.setSetting('syncConsent', 'yes');
        final before = await db.loadPassport();
        final duplicate = before.withEntries([
          before.entries.first,
          before.entries.first,
        ]);
        await expectLater(db.savePassport(duplicate), throwsA(anything));
        expect((await db.loadPassport()).entries.length, before.entries.length);
        expect(
          await db.customSelect('SELECT * FROM sync_outbox').get(),
          isEmpty,
        );
      });
    },
  );
  test('savePassport with enqueueSync false updates local SQLite without outbox bounce', () async {
    await AppDatabase.use(() async => folder, (db) async {
      await db.setSetting('syncConsent', 'yes');
      final cloud = Passport(
        name: 'Mr. Bora (Cloud)',
        age: 73,
        region: 'Guwahati, Assam',
        isDemo: false,
        entries: [
          const MemoryEntry(
            id: 'priya_cloud',
            kind: MemoryKind.family,
            values: {'name': 'Priya', 'relationship': 'Granddaughter'},
          ),
        ],
      );
      await db.savePassport(cloud, enqueueSync: false);
      final loaded = await db.loadPassport();
      expect(loaded.name, 'Mr. Bora (Cloud)');
      expect(loaded.age, 73);
      expect(loaded.entries, hasLength(1));
      expect(loaded.entries.first.name, 'Priya');
      // sync_outbox must remain empty so cloud downloads don't echo back!
      expect(await db.customSelect('SELECT * FROM sync_outbox').get(), isEmpty);
    });
  });
  test('Passport fromJson resiliently handles portal Firestore structures', () {
    final cloudJson = {
      'schemaVersion': 1,
      'name': 'Mr. Bora',
      'age': 72,
      'region': 'Assam',
      'isDemo': false,
      'revision': 2,
      'entries': [
        {
          'id': 'rahul_portal',
          'kind': 'family',
          'values': {
            'name': 'Rahul',
            'relationship': 'Son',
            'visits': 'Sunday',
          },
        },
        {
          'id': 'med_portal',
          'kind': 'medicine',
          'name': 'Donepezil',
          'values': {'time': '09:00', 'instructions': '5mg with water'},
        },
        {
          'id': 'place_portal',
          'kind': 'place',
          'values': {'name': 'Local Temple'},
        },
      ],
    };
    final parsed = Passport.fromJson(cloudJson);
    expect(parsed.name, 'Mr. Bora');
    expect(parsed.age, 72);
    expect(parsed.entries, hasLength(3));
    expect(parsed.entries[0].name, 'Rahul');
    expect(parsed.entries[0].kind, MemoryKind.family);
    expect(parsed.entries[1].name, 'Donepezil');
    expect(parsed.entries[1].kind, MemoryKind.medicine);
    expect(parsed.entries[2].name, 'Local Temple');
    expect(parsed.entries[2].kind, MemoryKind.place);
  });

  test(
    'daily routine completion is queued for cloud sync after consent',
    () async {
      await AppDatabase.use(() async => folder, (db) async {
        await db.setSetting('syncConsent', 'yes');
        await db.markEventCompleted('morning-medicine', DateTime(2026, 9, 8));
        final rows = await db
            .customSelect(
              "SELECT kind, entity_id, payload FROM sync_outbox WHERE kind = 'dailyCompletions'",
            )
            .get();
        expect(rows, hasLength(1));
        expect(
          rows.single.read<String>('entity_id'),
          '2026-09-08--morning-medicine',
        );
        final payload = jsonDecode(rows.single.read<String>('payload')) as Map;
        expect(payload['eventId'], 'morning-medicine');
        expect(payload['day'], '2026-09-08');
        expect(payload['source'], 'patient');
      });
    },
  );
}
