import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';

import '../storage/app_database.dart';
import 'cloud_setup.dart';

@pragma('vm:entry-point')
void syncCallback() {
  Workmanager().executeTask((task, data) async {
    try {
      await SyncService.flush();
      return true;
    } catch (_) {
      return false;
    }
  });
}

class SyncService {
  static Future<void> initialize() async {
    if (!CloudSetup.configured) return;
    await Workmanager().initialize(syncCallback);
    if (await enabled()) await schedule();
  }

  static Future<bool> enabled() => AppDatabase.use(
    null,
    (db) async => await db.setting('syncConsent') == 'yes',
  );
  static Future<void> setEnabled(bool value) async {
    if (value) {
      await CloudSetup.ensureReady();
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      await AppDatabase.use(
        null,
        (db) => db.transaction(() async {
          await db.setSetting('syncConsent', 'yes');
          await db.setSetting(
            'syncUid',
            FirebaseAuth.instance.currentUser!.uid,
          );
          final passport = await db.loadPassport();
          final data = passport.toJson();
          data['entries'] = passport.entries
              .map((e) => e.toJson()..remove('photo'))
              .toList();
          await db.enqueue('passport', 'current', data);
          for (final record in await db.records()) {
            await db.enqueue('records', record.id, record.toJson());
          }
        }),
      );
      await Workmanager().initialize(syncCallback);
      await schedule();
    } else {
      await AppDatabase.use(
        null,
        (db) => db.transaction(() async {
          await db.setSetting('syncConsent', 'no');
          await db.customStatement('DELETE FROM sync_outbox');
        }),
      );
      if (CloudSetup.configured) await Workmanager().cancelAll();
    }
  }

  static Future<void> schedule() => Workmanager().registerPeriodicTask(
    'saathi-sync',
    'saathi-sync',
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
  );

  static Future<String?> getSyncUid() => AppDatabase.use(
    null,
    (db) async => await db.setting('syncUid'),
  );

  static Future<int> getPendingCount() => AppDatabase.use(
    null,
    (db) async {
      final rows = await db
          .customSelect('SELECT COUNT(*) as c FROM sync_outbox')
          .get();
      return rows.isEmpty ? 0 : rows.first.read<int>('c');
    },
  );

  static Future<int> syncNow() => flush();

  static Future<int> flush() async {
    if (!await enabled()) return 0;
    await CloudSetup.ensureReady();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final expected = await AppDatabase.use(null, (db) => db.setting('syncUid'));
    if (expected == null) {
      await AppDatabase.use(null, (db) => db.setSetting('syncUid', uid));
    } else if (expected != uid) {
      throw StateError('Account changed; caregiver must enable sync again');
    }
    final rows = await AppDatabase.use(
      null,
      (db) => db
          .customSelect('SELECT * FROM sync_outbox ORDER BY seq LIMIT 50')
          .get(),
    );
    int count = 0;
    for (final row in rows) {
      if (!await enabled()) return count;
      final seq = row.read<int>('seq');
      final kind = row.read<String>('kind');
      final id = row.read<String>('entity_id');
      final ref = FirebaseFirestore.instance
          .collection('patients')
          .doc(uid)
          .collection(kind)
          .doc(id);
      final payload =
          jsonDecode(row.read<String>('payload')) as Map<String, dynamic>;
      await FirebaseFirestore.instance
          .runTransaction((tx) async {
            final old = await tx.get(ref);
            if (kind == 'records') {
              if (!old.exists) tx.set(ref, payload);
            } else if (!old.exists ||
                ((old.data()?['revision'] as int?) ?? -1) < seq) {
              tx.set(ref, {...payload, 'revision': seq});
            }
          })
          .timeout(const Duration(seconds: 15));
      await AppDatabase.use(
        null,
        (db) =>
            db.customStatement('DELETE FROM sync_outbox WHERE seq = ?', [seq]),
      );
      count++;
    }
    return count;
  }
}
