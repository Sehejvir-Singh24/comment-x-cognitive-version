import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../storage/app_database.dart';

/// Stores only the daily acknowledgement of a reminder. Medicine names,
/// times, and caregiver instructions remain in the Memory Passport.
class MedicineStore {
  MedicineStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<Set<String>> completedToday([DateTime? now]) => AppDatabase.use(
    _directory,
    (db) => db.completedEventIds(now ?? DateTime.now()),
  );

  Future<void> markCompleted(String eventId, [DateTime? now]) =>
      AppDatabase.use(
        _directory,
        (db) => db.markEventCompleted(eventId, now ?? DateTime.now()),
      );
}
