import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/ai/saathi_companion_service.dart';
import 'package:patient_app/memory_passport/passport.dart';

void main() {
  final passport = Passport.demo();
  test('general prompts contain no Passport data', () {
    expect(CompanionRouter.contextFor('Hello there', passport), '[]');
  });
  test(
    'family context excludes age, region, routine, visits and other facts',
    () {
      final context = CompanionRouter.contextFor(
        'Tell me about my family',
        passport,
      );
      expect(context, contains('Rahul'));
      for (final secret in ['72', 'Assam', 'Sunday', 'Breakfast', 'Cricket']) {
        expect(context, isNot(contains(secret)));
      }
    },
  );
  test('consent is required even with connectivity', () async {
    var calls = 0;
    final router = CompanionRouter(
      connected: () async => true,
      cloud: (_, _) async {
        calls++;
        return 'Hello';
      },
    );
    await router.reply('Hello', passport);
    expect(calls, 0);
  });
  test('online failure falls back to local facts', () async {
    final router = CompanionRouter(
      connected: () async => true,
      cloud: (_, _) async => throw StateError('secret'),
    )..consent = true;
    final reply = await router.reply('Tell me about my family', passport);
    expect(reply.text, contains('Rahul'));
    expect(reply.text, isNot(contains('secret')));
    expect(router.mode.value, CompanionMode.offline);
  });
  test('offline replies use saved place and memory notes', () async {
    const saved = Passport(
      name: 'Asha',
      age: 70,
      region: 'Assam',
      isDemo: false,
      entries: [
        MemoryEntry(
          id: 'temple',
          kind: MemoryKind.place,
          values: {
            'name': 'Kamakhya Temple',
            'notes': 'You enjoyed family visits here on festival days.',
          },
        ),
        MemoryEntry(
          id: 'picnic',
          kind: MemoryKind.memory,
          values: {
            'name': 'River picnic',
            'notes': 'Your family shared lunch by the river.',
          },
        ),
      ],
    );
    final router = CompanionRouter(
      connected: () async => false,
      cloud: (_, _) async => '',
    );
    expect(
      (await router.reply('Tell me about my favourite place', saved)).text,
      contains('Kamakhya Temple'),
    );
    expect(
      (await router.reply(
        'What memory do I have about the river?',
        saved,
      )).text,
      contains('shared lunch by the river'),
    );
  });
  test('cloud context includes requested place details only', () {
    const saved = Passport(
      name: 'Asha',
      age: 70,
      region: 'Assam',
      isDemo: false,
      entries: [
        MemoryEntry(
          id: 'temple',
          kind: MemoryKind.place,
          values: {
            'name': 'Kamakhya Temple',
            'notes': 'Family festival visits.',
          },
        ),
      ],
    );
    final context = CompanionRouter.contextFor('Tell me about my place', saved);
    expect(context, contains('Kamakhya Temple'));
    expect(context, contains('Family festival visits.'));
    expect(context, isNot(contains('Assam')));
  });
  test('medical requests and navigation never reach cloud', () async {
    var calls = 0;
    final router = CompanionRouter(
      connected: () async => true,
      cloud: (_, _) async {
        calls++;
        return 'Hello';
      },
    )..consent = true;
    expect(
      (await router.reply('change my medicine dose', passport)).text,
      CompanionRouter.medicalReply,
    );
    expect(
      (await router.reply('open family', passport)).action,
      CompanionAction.family,
    );
    expect(calls, 0);
  });
  test('online reply reports cloud processing; revoke disables it', () async {
    final router = CompanionRouter(
      connected: () async => true,
      cloud: (_, _) async => 'Hello, how are you?',
    )..consent = true;
    expect((await router.reply('hello', passport)).cloudProcessed, true);
    router.revoke();
    expect((await router.reply('hello', passport)).cloudProcessed, false);
  });
}
