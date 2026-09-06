import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../memory_passport/passport.dart';
import 'gemini_config.dart';

/// A single message in the Talk to Saathi conversation.
class CompanionMessage {
  const CompanionMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

/// Service handling the conversational AI companion with Google Gemini.
class SaathiCompanionService {
  SaathiCompanionService({
    this.model,
    this.apiKey = GeminiConfig.apiKey,
  });

  final String apiKey;
  GenerativeModel? model;
  ChatSession? _chatSession;

  /// Builds a grounded system instruction prompt from the patient's Memory Passport.
  static String buildSystemInstruction(Passport passport) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are "Saathi" (meaning companion), a gentle, caring, patient, and warm conversational assistant for an elderly person living with mild cognitive impairment or dementia.',
    );
    buffer.writeln(
      'Your tone is warm, polite, reassuring, short, and very easy to understand (grade 4 level vocabulary).',
    );
    buffer.writeln('STRICT RULES:');
    buffer.writeln(
      '1. NEVER hallucinate family members, events, or facts not mentioned in the patient memory profile below.',
    );
    buffer.writeln(
      '2. If asked about something not in your records, gently say: "I do not have notes on that, but I would love to hear about it if you want to share."',
    );
    buffer.writeln(
      '3. NEVER give medical advice, adjust medication schedules, or diagnose conditions. If asked about health or medicines, remind them: "Please check with your doctor or caregiver before taking any medicines."',
    );
    buffer.writeln(
      '4. Keep your responses concise (1 to 3 short sentences maximum). Elderly people get overwhelmed by long paragraphs.',
    );
    buffer.writeln(
      '5. Speak respectfully. You can address the patient by their name.',
    );
    buffer.writeln();
    buffer.writeln('--- PATIENT MEMORY PASSPORT ---');
    buffer.writeln('Name: ${passport.name}');
    buffer.writeln('Age: ${passport.age}');
    buffer.writeln('Region / Home: ${passport.region}');

    // Family
    final family = passport.entries
        .where((e) => e.kind == MemoryKind.family)
        .toList();
    if (family.isNotEmpty) {
      buffer.writeln('Family Members:');
      for (final f in family) {
        final rel = f.values['relationship'] ?? '';
        final visits = f.values['visits'] != null
            ? ' (visits: ${f.values['visits']})'
            : '';
        final activity = f.values['sharedActivity'] != null
            ? ' (shared activity: ${f.values['sharedActivity']})'
            : '';
        buffer.writeln('- ${f.name}: $rel$visits$activity');
      }
    }

    // Routines
    final routines = passport.entries
        .where((e) => e.kind == MemoryKind.routine)
        .toList();
    if (routines.isNotEmpty) {
      buffer.writeln('Daily Routines:');
      for (final r in routines) {
        buffer.writeln('- ${r.values['time'] ?? ''} : ${r.name}');
      }
    }

    // Favourite activities
    final activities = passport.entries
        .where((e) => e.kind == MemoryKind.activity)
        .toList();
    if (activities.isNotEmpty) {
      buffer.writeln('Favourite Activities:');
      for (final a in activities) {
        buffer.writeln('- ${a.name}');
      }
    }

    // Important places
    final places = passport.entries
        .where((e) => e.kind == MemoryKind.place)
        .toList();
    if (places.isNotEmpty) {
      buffer.writeln('Important Places:');
      for (final p in places) {
        buffer.writeln('- ${p.name}');
      }
    }

    // Memories
    final memories = passport.entries
        .where((e) => e.kind == MemoryKind.memory)
        .toList();
    if (memories.isNotEmpty) {
      buffer.writeln('Important Memories:');
      for (final m in memories) {
        buffer.writeln('- ${m.name}');
      }
    }

    buffer.writeln('--- END OF MEMORY PASSPORT ---');
    return buffer.toString();
  }

  /// Initializes the chat session using the given passport.
  void initChat(Passport passport) {
    final systemPrompt = buildSystemInstruction(passport);
    model = model ??
        GenerativeModel(
          model: GeminiConfig.modelName,
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt),
        );
    _chatSession = model!.startChat();
  }

  /// Sends a message and returns Saathi's reply.
  Future<String> sendMessage(String text) async {
    if (_chatSession == null) {
      throw StateError('Chat session not initialized. Call initChat first.');
    }
    try {
      final response = await _chatSession!.sendMessage(Content.text(text));
      final reply = response.text?.trim();
      if (reply == null || reply.isEmpty) {
        return "I am here with you. How can I help today?";
      }
      return reply;
    } catch (e, stack) {
      debugPrint('Gemini sendMessage error: $e\n$stack');
      return "Error: $e";
    }
  }
}
