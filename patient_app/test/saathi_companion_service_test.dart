import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/ai/saathi_companion_service.dart';
import 'package:patient_app/memory_passport/passport.dart';

void main() {
  group('SaathiCompanionService', () {
    test('buildSystemInstruction formats Memory Passport details without hallucination', () {
      final passport = Passport.demo();
      final instructions = SaathiCompanionService.buildSystemInstruction(passport);

      // Check grounding facts
      expect(instructions, contains('Mr. Bora'));
      expect(instructions, contains('72'));
      expect(instructions, contains('Assam'));
      expect(instructions, contains('Rahul: Son (visits: Sunday) (shared activity: Cricket)'));
      expect(instructions, contains('Ananya: Daughter'));
      expect(instructions, contains('Meera: Wife'));
      expect(instructions, contains('08:00 : Breakfast'));
      expect(instructions, contains('Gardening'));

      // Check anti-hallucination guardrails
      expect(instructions, contains('NEVER hallucinate'));
      expect(instructions, contains('NEVER give medical advice'));
      expect(instructions, contains('concise (1 to 3 short sentences maximum)'));
    });

    test('buildSystemInstruction handles custom passport entries', () {
      const customPassport = Passport(
        name: 'Mrs. Sarma',
        age: 68,
        region: 'Guwahati',
        entries: [
          MemoryEntry(
            id: 'place1',
            kind: MemoryKind.place,
            values: {'name': 'Brahmaputra Riverfront'},
          ),
          MemoryEntry(
            id: 'mem1',
            kind: MemoryKind.memory,
            values: {'name': 'Bihu Festival 1975'},
          ),
        ],
      );

      final instructions = SaathiCompanionService.buildSystemInstruction(customPassport);
      expect(instructions, contains('Mrs. Sarma'));
      expect(instructions, contains('Brahmaputra Riverfront'));
      expect(instructions, contains('Bihu Festival 1975'));
    });
  });
}
