import 'dart:io';

import '../storage/app_database.dart';
import 'cognitive_record.dart';

class RecordStore {
  // ignore: prefer_initializing_formals
  RecordStore({this._directory});
  final Future<Directory> Function()? _directory;
  Future<List<CognitiveRecord>> loadAll() =>
      AppDatabase.use(_directory, (db) => db.records());
  Future<void> save(CognitiveRecord record) =>
      AppDatabase.use(_directory, (db) => db.saveRecord(record));
  Future<List<CognitiveRecord>> recent(int count) async {
    final records = await loadAll();
    return records.length <= count
        ? records
        : records.sublist(records.length - count);
  }
}
