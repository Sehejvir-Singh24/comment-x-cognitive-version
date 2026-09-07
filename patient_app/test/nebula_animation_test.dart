import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/talk/nebula_animation.dart';

void main() {
  group('NebulaVisualizer Widget Tests', () {
    testWidgets('renders idle state with Start voice conversation and responds to tap', (
      tester,
    ) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NebulaVisualizer(
              isListening: false,
              isSpeaking: false,
              isLoading: false,
              isVoiceConversation: false,
              onToggleVoice: () => toggled = true,
            ),
          ),
        ),
      );

      // Verify idle button and icon
      expect(find.text('Start voice conversation'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Tap the action button
      await tester.tap(find.text('Start voice conversation'));
      expect(toggled, isTrue);
    });

    testWidgets('renders active listening state with End voice conversation', (
      tester,
    ) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NebulaVisualizer(
              isListening: true,
              isSpeaking: false,
              isLoading: false,
              isVoiceConversation: true,
              onToggleVoice: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify active listening status & button
      expect(find.text('Listening — speak naturally'), findsOneWidget);
      expect(find.text('End voice conversation'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);

      // Tap to end voice
      await tester.tap(find.text('End voice conversation'));
      expect(toggled, isTrue);
    });

    testWidgets('renders speaking state with volume icon and status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NebulaVisualizer(
              isListening: false,
              isSpeaking: true,
              isLoading: false,
              isVoiceConversation: true,
              onToggleVoice: () {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Saathi is speaking…'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.text('End voice conversation'), findsOneWidget);
    });

    testWidgets('disables tap when loading during conversation', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NebulaVisualizer(
              isListening: false,
              isSpeaking: false,
              isLoading: true,
              isVoiceConversation: true,
              onToggleVoice: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Saathi is thinking…'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);

      // Button should be disabled during loading
      await tester.tap(find.text('End voice conversation'));
      expect(toggled, isFalse);
    });
  });
}
