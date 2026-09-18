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
      // The greeting is spoken first; complete it so the listen loop starts.
      voice.spoken.complete();
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

  test('SpeechService retains partial transcript when recognition receives error', () async {
    const channel = MethodChannel('org.saathi/speech');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'availability') return true;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final speech = SpeechService();
    await speech.startListening();

    // Simulate Android sending partial result
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'org.saathi/speech',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('partial', 'What is my routine today?'),
      ),
      (data) {},
    );

    // Simulate Android sending an error (e.g. timeout / no match at end of speech)
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'org.saathi/speech',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('error', {'code': 7}),
      ),
      (data) {},
    );

    final transcript = await speech.finalTranscript();
    expect(transcript, 'What is my routine today?');
    await speech.dispose();
  });

  testWidgets(
    'voice submits text field candidate when final speech transcript is empty',
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
      voice.spoken.complete();
      await tester.pump();

      // Emit partial transcript to speech service stream
      voice.transcripts.add('Good morning Saathi');
      await tester.pump();

      // Final transcript completes with empty string (e.g. due to Android error/silence)
      voice.heard.complete('');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Candidate text from controller was submitted
      expect(service.lastPrompt, 'Good morning Saathi');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
