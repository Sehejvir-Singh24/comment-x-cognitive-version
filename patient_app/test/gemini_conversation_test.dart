import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/ai/saathi_companion_service.dart';

GenerateContentResponse response(String text, FinishReason reason) =>
    GenerateContentResponse([
      Candidate(Content.model([TextPart(text)]), null, null, reason, null),
    ], null);

void main() {
  test(
    'retries truncated output and retains complete conversation turns',
    () async {
      final requests = <List<Content>>[];
      final limits = <int?>[];
      final session = GeminiConversation(
        generate: (contents, config) async {
          requests.add(List.of(contents));
          limits.add(config.maxOutputTokens);
          expect(config.thinkingConfig?.thinkingLevel, ThinkingLevel.minimal);
          if (requests.length == 1) {
            return response('I am', FinishReason.maxTokens);
          }
          return response(
            'That sounds lovely. Tell me more about your garden.',
            FinishReason.stop,
          );
        },
      );
      expect(
        await session.reply('I enjoy gardening.', '[]'),
        contains('garden.'),
      );
      expect(limits, [2048, 4096]);
      await session.reply('What did I just tell you?', '[]');
      expect(requests.last.length, 3);
      expect(
        (requests.last[0].parts.first as TextPart).text,
        contains('gardening'),
      );
      session.clear();
      await session.reply('Hello', '[]');
      expect(requests.last.length, 1);
    },
  );

  test(
    'never returns a fragment after retry also runs out of tokens',
    () async {
      final session = GeminiConversation(
        generate: (_, _) async => response('Based', FinishReason.maxTokens),
      );
      await expectLater(session.reply('Hello', '[]'), throwsStateError);
    },
  );

  test(
    'clearing session during a pending response prevents history restoration',
    () async {
      final requests = <List<Content>>[];
      late GeminiConversation session;
      session = GeminiConversation(
        generate: (contents, _) async {
          requests.add(contents);
          session.clear();
          return response('Hello there.', FinishReason.stop);
        },
      );
      await session.reply('First', '[]');
      await session.reply('Second', '[]');
      expect(requests.last.length, 1);
    },
  );
}
