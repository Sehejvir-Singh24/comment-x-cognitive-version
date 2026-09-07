import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/launcher/launcher_bridge.dart';
import 'package:patient_app/memory_passport/passport.dart';
import 'package:patient_app/talk/talk_screen.dart';
import 'package:patient_app/voice/speech_service.dart';

import 'talk_screen_test.dart' show FakeCompanionService;

class Voice extends SpeechService {
  Completer<String> heard = Completer<String>();
  Completer<void> spoken = Completer<void>();
  int starts = 0;
  @override
  Future<void> startListening() async {
    starts++;
    heard = Completer<String>();
  }

  @override
  Future<String> finalTranscript() => heard.future;
  @override
  Future<void> speak(String text) {
    spoken = Completer<void>();
    return spoken.future;
  }

  @override
  Future<void> stopSpeaking() async {
    if (!spoken.isCompleted) spoken.complete();
  }

  @override
  Future<void> cancelListening() async {
    if (!heard.isCompleted) heard.complete('');
  }
}

void main() {
  testWidgets(
    'Camera command reaches Android and never Gemini through Talk screen',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(LauncherBridge.channel, (call) async {
            calls.add(call);
            if (call.method == 'listApps') {
              return [
                {'label': 'Camera', 'packageName': 'com.oplus.camera'},
              ];
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(LauncherBridge.channel, null),
      );
      final service = FakeCompanionService();
      await tester.pumpWidget(
        MaterialApp(
          home: TalkScreen(passport: Passport.demo(), service: service),
        ),
      );
      await tester.enterText(find.byType(TextField), 'open the camera please');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'openApp').single.arguments, {
        'packageName': 'com.oplus.camera',
      });
      expect(service.lastPrompt, isNull);
    },
  );

  testWidgets(
    'voice submits final speech automatically and waits for audio before next turn',
    (tester) async {
      final voice = Voice();
      final service = FakeCompanionService();
      await tester.pumpWidget(
        MaterialApp(
          home: TalkScreen(
            passport: Passport.demo(),
            service: service,
            speech: voice,
            startListening: true,
          ),
        ),
      );
      await tester.pump();
      expect(voice.starts, 1);
      voice.heard.complete('I enjoy gardening');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.lastPrompt, 'I enjoy gardening');
      expect(voice.starts, 1);
      voice.spoken.complete();
      await tester.pump();
      expect(voice.starts, 2);
      await tester.tap(find.text('End voice conversation'));
      await tester.pump();
      expect(voice.starts, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
