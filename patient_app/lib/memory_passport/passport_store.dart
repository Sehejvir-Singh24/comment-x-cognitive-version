import '../storage/app_database.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'passport.dart';

/// Replace this snapshot adapter with Drift at the PRD's database milestone.
/// Only this adapter knows the on-disk format; UI and models do not.
class PassportStore {
  PassportStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;
  Future<void> _tail = Future.value();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<Directory> _folder() async {
    final base = await _directory();
    return Directory('${base.path}/memory_passport').create(recursive: true);
  }

  Future<Passport> load() =>
      AppDatabase.use(_directory, (db) => db.loadPassport());

  Future<void> save(Passport passport) => _exclusive(() => _write(passport));

  Future<void> _write(Passport passport) async {
    final previousPhotos = await AppDatabase.use(_directory, (db) async {
      final previous = await db.loadPassport();
      await db.savePassport(passport);
      return previous.entries.map((e) => e.photo).whereType<String>().toSet();
    });
    final kept = passport.entries
        .map((e) => e.photo)
        .whereType<String>()
        .toSet();
    for (final name in previousPhotos.difference(kept)) {
      // Delete only our own obsolete copies, never the user's gallery original.
      try {
        final photo = await photoFile(name);
        if (await photo.exists()) await photo.delete();
      } on FileSystemException {
        // The passport was committed; an orphan can be cleaned up later.
      }
    }
  }

  Future<String> importPhoto(String sourcePath) async {
    final folder = await _folder();
    final name = '${DateTime.now().microsecondsSinceEpoch}.photo';
    await File(sourcePath).copy('${folder.path}/$name');
    return name;
  }

  Future<File> photoFile(String name) async {
    if (!RegExp(r'^\d+\.photo$').hasMatch(name)) {
      throw const FormatException('Invalid photo reference');
    }
    return File('${(await _folder()).path}/$name');
  }
}
