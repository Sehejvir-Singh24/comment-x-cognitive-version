import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/storage/app_database.dart';
import 'package:patient_app/memory_passport/passport.dart';

void main() {
 late Directory folder;
 setUp(() async { folder = await Directory.systemTemp.createTemp('saathi-migration-'); });
 tearDown(() async { await folder.delete(recursive: true); });
 test('bad legacy records preserve source and allow corrected import', () async {
  final legacy = Directory('${folder.path}/memory_passport');
  await legacy.create();
  final source = File('${legacy.path}/passport.json');
  await source.writeAsString(jsonEncode(Passport.demo().toJson()));
  final records = File('${legacy.path}/records.json');
  await records.writeAsString('broken');
  await expectLater(AppDatabase.use(() async => folder, (db) => db.loadPassport()), throwsA(anything));
  expect(await source.exists(), isTrue);
  await records.writeAsString(jsonEncode({'schemaVersion':1, 'records':[]}));
  final passport = await AppDatabase.use(() async => folder, (db) => db.loadPassport());
  expect(passport.name, Passport.demo().name);
  expect(await records.exists(), isTrue);
 });
 test('outbox needs consent and omits photo paths', () async {
  await AppDatabase.use(() async => folder, (db) async {
   await db.savePassport(Passport.demo());
   expect(await db.customSelect('SELECT * FROM sync_outbox').get(), isEmpty);
   await db.setSetting('syncConsent', 'yes');
   await db.savePassport(Passport.demo());
   final rows = await db.customSelect('SELECT payload FROM sync_outbox').get();
   expect(rows, hasLength(1));
   final payload = jsonDecode(rows.single.read<String>('payload')) as Map;
   for (final entry in payload['entries'] as List) { expect((entry as Map).containsKey('photo'), isFalse); }
  });
 });
 test('failed passport transaction rolls back queued upload and local changes', () async {
  await AppDatabase.use(() async => folder, (db) async {
   await db.setSetting('syncConsent', 'yes');
   final before = await db.loadPassport();
   final duplicate = before.withEntries([before.entries.first, before.entries.first]);
   await expectLater(db.savePassport(duplicate), throwsA(anything));
   expect((await db.loadPassport()).entries.length, before.entries.length);
   expect(await db.customSelect('SELECT * FROM sync_outbox').get(), isEmpty);
  });
 });
}

