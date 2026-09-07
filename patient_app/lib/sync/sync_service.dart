import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../medicine/reminder_bridge.dart';
import '../memory_passport/passport.dart';
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
  static const String defaultPatientUid = 'demo_patient_bora';
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _activePassportSubscription;

  static Future<void> initialize() async {
    if (!CloudSetup.configured) return;
    await Workmanager().initialize(syncCallback);
    if (await enabled()) await schedule();
  }

  static Future<bool> enabled() => AppDatabase.use(
    null,
    (db) async => await db.setting('syncConsent') == 'yes',
  );

  static Future<String> getEffectivePatientUid() async {
    final configured = await AppDatabase.use(
      null,
      (db) async => await db.setting('syncUid'),
    );
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return defaultPatientUid;
  }

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
          final existing = await db.setting('syncUid');
          if (existing == null || existing.isEmpty) {
            await db.setSetting('syncUid', defaultPatientUid);
          }
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
      _activePassportSubscription?.cancel();
      _activePassportSubscription = null;
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

  static Future<String?> getSyncUid() async {
    final uid = await AppDatabase.use(
      null,
      (db) async => await db.setting('syncUid'),
    );
    return uid ?? defaultPatientUid;
  }

  static Future<int> getPendingCount() => AppDatabase.use(
    null,
    (db) async {
      final rows = await db
          .customSelect('SELECT COUNT(*) as c FROM sync_outbox')
          .get();
      return rows.isEmpty ? 0 : rows.first.read<int>('c');
    },
  );

  static Future<int> syncNow() async {
    final flushed = await flush();
    await pullPassport();
    return flushed;
  }

  /// Listens to live updates on the Firestore passport document.
  /// When updated on the caretaker portal, immediately updates local SQLite,
  /// reschedules reminders, and invokes [onPassportUpdated].
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      startPassportListener({
    required void Function(Passport) onPassportUpdated,
  }) {
    if (!CloudSetup.configured) return null;
    try {
      CloudSetup.ensureReady().then((_) async {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }
        final patientId = await getEffectivePatientUid();
        final stream = FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .collection('passport')
            .doc('current')
            .snapshots();

        _activePassportSubscription?.cancel();
        _activePassportSubscription = stream.listen((snapshot) async {
          if (snapshot.exists && snapshot.data() != null) {
            try {
              final passport = Passport.fromJson(snapshot.data()!);
              await AppDatabase.use(
                null,
                (db) => db.savePassport(passport, enqueueSync: false),
              );
              await ReminderBridge.schedule(passport);
              onPassportUpdated(passport);
            } catch (err) {
              debugPrint('Error parsing cloud passport snapshot: $err');
            }
          }
        }, onError: (Object err) {
          debugPrint('Passport Firestore listener error: $err');
        });
      }).catchError((Object err) {
        debugPrint('Could not initialize passport listener: $err');
      });
    } catch (e) {
      debugPrint('Exception starting passport listener: $e');
    }
    return _activePassportSubscription;
  }

  /// Pulls the latest passport document from Firestore.
  static Future<Passport?> pullPassport({
    void Function(Passport)? onPassportUpdated,
  }) async {
    try {
      if (!CloudSetup.configured) return null;
      await CloudSetup.ensureReady();
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      final patientId = await getEffectivePatientUid();
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('passport')
          .doc('current')
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        final passport = Passport.fromJson(doc.data()!);
        await AppDatabase.use(
          null,
          (db) => db.savePassport(passport, enqueueSync: false),
        );
        await ReminderBridge.schedule(passport);
        onPassportUpdated?.call(passport);
        return passport;
      }
    } catch (e) {
      debugPrint('Pull passport error: $e');
    }
    return null;
  }

  static Future<int> flush() async {
    if (!await enabled()) return 0;
    await CloudSetup.ensureReady();
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    final patientId = await getEffectivePatientUid();
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
          .doc(patientId)
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
