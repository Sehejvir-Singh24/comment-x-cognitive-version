import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'cognitive_record.dart';

/// Persistent storage adapter for [CognitiveRecord] objects.
///
/// Writes a versioned JSON list to `memory_passport/records.json` in the
/// app-private documents directory — the same folder used by [PassportStore].
///
/// Replace this snapshot adapter with Drift at the PRD's database milestone.
/// Only this adapter knows the on-disk format; the engine and screens do not.
class RecordStore {
  RecordStore({Future<Directory> Function()? directory})
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

  File _file(Directory folder) => File('${folder.path}/records.json');

  /// Loads all records from disk.
  ///
  /// Returns an empty list if no file exists.
  /// Throws [FormatException] if the file is corrupt or has an unknown version,
  /// preserving the raw file rather than silently resetting patient data.
  Future<List<CognitiveRecord>> loadAll() => _exclusive(() async {
        final folder = await _folder();
        final file = _file(folder);
        if (!await file.exists()) return [];
        final decoded =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (decoded['schemaVersion'] != 1) {
          throw const FormatException('Unsupported records version');
        }
        return (decoded['records'] as List)
            .map((e) =>
                CognitiveRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  /// Returns the [count] most-recent records across all [RecordKind]s.
  Future<List<CognitiveRecord>> recent(int count) async {
    final all = await loadAll();
    if (all.length <= count) return all;
    return all.sublist(all.length - count);
  }

  /// Appends [record] to the stored list and writes atomically.
  Future<void> save(CognitiveRecord record) => _exclusive(() async {
        final folder = await _folder();
        final file = _file(folder);

        List<CognitiveRecord> existing;
        if (await file.exists()) {
          try {
            final decoded =
                jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            if (decoded['schemaVersion'] != 1) {
              throw const FormatException('Unsupported records version');
            }
            existing = (decoded['records'] as List)
                .map((e) => CognitiveRecord.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList();
          } catch (_) {
            // If the existing file is unreadable, start fresh rather than
            // silently losing the new record.  The corrupt file will be
            // replaced by the atomic rename below.
            existing = [];
          }
        } else {
          existing = [];
        }

        existing.add(record);

        final payload = jsonEncode({
          'schemaVersion': 1,
          'records': existing.map((r) => r.toJson()).toList(),
        });
        final temp = File('${folder.path}/records.pending');
        await temp.writeAsString(payload, flush: true);
        await temp.rename(file.path);
      });
}
