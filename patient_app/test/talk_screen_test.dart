import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/ai/saathi_companion_service.dart';
import 'package:patient_app/l10n/app_localizations.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/talk/talk_screen.dart';

class FakeCompanionService extends SaathiCompanionService {
  FakeCompanionService({
    this.cannedReply = 'Hello! I remember Rahul visits on Sunday.',
  });

  final String cannedReply;
  String? lastPrompt;

  @override
  void initChat(Passport passport) {}

  @override
  Future<String> sendMessage(String text) async {
    lastPrompt = text;
    return cannedReply;
  }
}

Widget buildTestableTalkScreen({
  required Passport passport,
  required SaathiCompanionService service,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: TalkScreen(passport: passport, service: service),
  );
}

void main() {
  group('TalkScreen widget tests', () {
    testWidgets('renders initial greeting and quick chips', (tester) async {
      final service = FakeCompanionService();
      await tester.pumpWidget(
        buildTestableTalkScreen(passport: Passport.demo(), service: service),
      );
      await tester.pumpAndSettle();

      // Verify title & initial greeting
      expect(find.text('Talk to Saathi'), findsOneWidget);
      expect(find.textContaining('Hello Mr. Bora'), findsOneWidget);

      // Verify quick chips (may be scrolled slightly horizontally)
      expect(
        find.text('Tell me about my family', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('What is my routine today?', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text("Let's talk about gardening", skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets(
      'tapping quick chip sends message and displays companion reply',
      (tester) async {
        final service = FakeCompanionService(
          cannedReply: 'Rahul is your son. He loves playing cricket with you.',
        );
        await tester.pumpWidget(
          buildTestableTalkScreen(passport: Passport.demo(), service: service),
        );
        await tester.pumpAndSettle();

        // Tap the family quick chip
        await tester.tap(find.text('Tell me about my family'));
        await tester.pump(); // Start loading
        await tester.pumpAndSettle(); // Finish response

        // User prompt should be visible
        expect(
          find.text('Tell me about my family'),
          findsNWidgets(2),
        ); // in chip & in bubble
        // AI reply should be visible
        expect(
          find.text('Rahul is your son. He loves playing cricket with you.'),
          findsOneWidget,
        );
        expect(service.lastPrompt, 'Tell me about my family');
      },
    );

    testWidgets('typing and pressing send button delivers custom message', (
      tester,
    ) async {
      final service = FakeCompanionService(
        cannedReply: 'Gardening is wonderful! You love caring for your plants.',
      );
      await tester.pumpWidget(
        buildTestableTalkScreen(passport: Passport.demo(), service: service),
      );
      await tester.pumpAndSettle();

      // Enter text in field
      await tester.enterText(find.byType(TextField), 'Do you know my hobbies?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Do you know my hobbies?'), findsOneWidget);
      expect(
        find.text('Gardening is wonderful! You love caring for your plants.'),
        findsOneWidget,
      );
      expect(service.lastPrompt, 'Do you know my hobbies?');
    });
  });
}
