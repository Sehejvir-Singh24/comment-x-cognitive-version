import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/memory_passport/passport_store.dart';

void main() {
  late Directory folder;
  late PassportStore store;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('saathi-passport-test-');
    store = PassportStore(directory: () async => folder);
  });
  tearDown(() async => folder.delete(recursive: true));

  test('seeds once and preserves edits after reopening the store', () async {
    final demo = await store.load();
    expect(demo.entries.where((e) => e.kind == MemoryKind.family).length, 3);
    final edited = Passport(
      name: 'Test Person',
      age: 74,
      region: 'Assam',
      isDemo: false,
      entries: [
        ...demo.entries,
        const MemoryEntry(
          id: 'place-1',
          kind: MemoryKind.place,
          values: {'name': 'Garden'},
        ),
      ],
    );
    await store.save(edited);
    final reopened = await PassportStore(directory: () async => folder).load();
    expect(reopened.name, 'Test Person');
    expect(reopened.isDemo, false);
    expect(reopened.entries.last.name, 'Garden');
    await store.save(reopened.withEntries([]));
    expect((await store.load()).entries, isEmpty);
  });
  test(
    'corrupt storage raises an error and is never replaced by demo data',
    () async {
      await Directory('${folder.path}/memory_passport').create(recursive: true);
      final file = File('${folder.path}/memory_passport/passport.json');
      await file.writeAsString('broken');
      await expectLater(store.load(), throwsA(isA<FormatException>()));
      expect(await file.readAsString(), 'broken');
    },
  );
  test('imports a private copy that survives removal of the source', () async {
    final source = File('${folder.path}/selected-photo');
    await source.writeAsBytes([1, 2, 3, 4]);
    final name = await store.importPhoto(source.path);
    await source.delete();
    expect(await (await store.photoFile(name)).readAsBytes(), [1, 2, 3, 4]);
    await expectLater(
      store.photoFile('../outside'),
      throwsA(isA<FormatException>()),
    );
  });
  test('unknown versions do not overwrite saved data', () async {
    await Directory('${folder.path}/memory_passport').create(recursive: true);
    final file = File('${folder.path}/memory_passport/passport.json');
    final json = Passport.demo().toJson()..['schemaVersion'] = 2;
    await file.writeAsString(jsonEncode(json));
    await expectLater(store.load(), throwsA(isA<FormatException>()));
    expect(jsonDecode(await file.readAsString())['schemaVersion'], 2);
  });
  test(
    'concurrent initial reads seed safely, removed photo copies are deleted',
    () async {
      final initial = await Future.wait([store.load(), store.load()]);
      expect(initial.first.name, initial.last.name);
      final source = File('${folder.path}/gallery-photo');
      await source.writeAsBytes([1, 2]);
      final photo = await store.importPhoto(source.path);
      await store.save(
        initial.first.withEntries([
          MemoryEntry(
            id: 'photo-test',
            kind: MemoryKind.family,
            values: {'name': 'Test', 'relationship': 'Son'},
            photo: photo,
          ),
        ]),
      );
      await store.save(initial.first.withEntries([]));
      expect(await (await store.photoFile(photo)).exists(), false);
      expect(await source.exists(), true);
    },
  );
}
