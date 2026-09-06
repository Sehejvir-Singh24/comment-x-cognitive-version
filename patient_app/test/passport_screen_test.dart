import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/memory_passport/passport_store.dart';
import 'package:patient_app/memory_passport/passport_screen.dart';
import 'package:patient_app/launcher/launcher_bridge.dart';

class FakeStore extends PassportStore {
  Passport value = Passport.demo();
  bool fail = false;
  @override
  Future<Passport> load() async => value;
  @override
  Future<void> save(Passport passport) async {
    if (fail) throw Exception('storage unavailable');
    value = passport;
  }
}

Widget testApp(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('HOME can exit a dirty editor without trapping the launcher', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final store = FakeStore();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('Home route')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => EntryEditor(
          passport: store.value,
          kind: MemoryKind.family,
          store: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved person');
    LauncherBridge.homeRequests.value++;
    await tester.pump();
    navigator.currentState!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
    expect(store.value.entries.any((e) => e.name == 'Unsaved person'), false);
  });
  testWidgets(
    'entry validates required details, preserves edits on failed save, then retries',
    (tester) async {
      final store = FakeStore()..fail = true;
      await tester.pumpWidget(
        testApp(
          EntryEditor(
            passport: store.value,
            kind: MemoryKind.family,
            store: store,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Save on this phone'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save on this phone'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextFormField).first,
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Please enter this.'), findsWidgets);
      await tester.enterText(find.byType(TextFormField).at(0), 'Nila');
      await tester.enterText(find.byType(TextFormField).at(1), 'Sister');
      await tester.scrollUntilVisible(
        find.text('Save on this phone'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save on this phone'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save. Your changes are still here. Please try again.',
        ),
        findsOneWidget,
      );
      expect(store.value.entries.any((e) => e.name == 'Nila'), false);
      store.fail = false;
      await tester.ensureVisible(find.text('Save on this phone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save on this phone'));
      await tester.pumpAndSettle();
      expect(store.value.entries.last.values['relationship'], 'Sister');
    },
  );
  testWidgets(
    'passport presents seeded family and routine sections at large text size',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        testApp(PassportScreen(store: FakeStore(), onChanged: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mr. Bora'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Rahul'), 300);
      expect(find.text('Relationship: Son'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Daily routines'), 400);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('demo Passport guides the caregiver through real-patient setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(PassportScreen(store: FakeStore(), onChanged: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Caregiver setup'), findsOneWidget);
    expect(find.text('0 of 3 important steps completed'), findsOneWidget);
    await tester.tap(find.text('Set up profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileEditor), findsOneWidget);
  });

  testWidgets('real-profile setup clears only the sample entries', (
    tester,
  ) async {
    final store = FakeStore();
    await tester.pumpWidget(
      testApp(
        ProfileEditor(passport: store.value, store: store, makeReal: true),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Devi');
    await tester.enterText(find.byType(TextFormField).at(1), '70');
    await tester.enterText(find.byType(TextFormField).at(2), 'Guwahati');
    final save = find.widgetWithText(
      ElevatedButton,
      'Save real profile and remove samples',
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(store.value.isDemo, isFalse);
    expect(store.value.name, 'Asha Devi');
    expect(store.value.entries, isEmpty);
  });
}
