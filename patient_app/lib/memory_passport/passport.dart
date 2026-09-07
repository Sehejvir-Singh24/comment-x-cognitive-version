enum MemoryKind { family, place, memory, routine, medicine, activity }

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.kind,
    required this.values,
    this.photo,
  });
  final String id;
  final MemoryKind kind;
  final Map<String, String> values;
  final String? photo;
  String get name => values['name'] ?? '';
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'values': values,
    'photo': photo,
  };
  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    final rawValues =
        json['values'] is Map ? (json['values'] as Map) : <String, dynamic>{};
    final Map<String, String> values = {};
    rawValues.forEach((k, v) {
      if (v != null) values[k.toString()] = v.toString();
    });
    if (json['name'] != null && !values.containsKey('name')) {
      values['name'] = json['name'].toString();
    }
    final rawKind = json['kind'] as String?;
    final kind = MemoryKind.values.firstWhere(
      (k) => k.name == rawKind,
      orElse: () => MemoryKind.memory,
    );
    return MemoryEntry(
      id: (json['id'] as String?) ??
          'entry_${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      values: values,
      photo: json['photo'] as String?,
    );
  }
}

class Passport {
  const Passport({
    required this.name,
    required this.age,
    required this.region,
    required this.entries,
    this.isDemo = true,
  });
  final String name;
  final int age;
  final String region;
  final bool isDemo;
  final List<MemoryEntry> entries;

  Passport withEntries(List<MemoryEntry> next) => Passport(
    name: name,
    age: age,
    region: region,
    entries: next,
    isDemo: isDemo,
  );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'name': name,
    'age': age,
    'region': region,
    'isDemo': isDemo,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  factory Passport.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != null && json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported passport version');
    }
    final rawEntries = json['entries'];
    final entries = <MemoryEntry>[];
    if (rawEntries is List) {
      for (final e in rawEntries) {
        if (e is Map) {
          try {
            entries.add(MemoryEntry.fromJson(Map<String, dynamic>.from(e)));
          } catch (_) {}
        }
      }
    }
    return Passport(
      name: (json['name'] as String?) ?? 'Mr. Bora',
      age: (json['age'] is num) ? (json['age'] as num).toInt() : 72,
      region: (json['region'] as String?) ?? 'Assam',
      isDemo: json['isDemo'] == true,
      entries: rawEntries == null ? Passport.demo().entries : entries,
    );
  }
  factory Passport.demo() => const Passport(
    name: 'Mr. Bora',
    age: 72,
    region: 'Assam',
    entries: [
      MemoryEntry(
        id: 'rahul',
        kind: MemoryKind.family,
        values: {
          'name': 'Rahul',
          'relationship': 'Son',
          'visits': 'Sunday',
          'sharedActivity': 'Cricket',
        },
      ),
      MemoryEntry(
        id: 'ananya',
        kind: MemoryKind.family,
        values: {'name': 'Ananya', 'relationship': 'Daughter'},
      ),
      MemoryEntry(
        id: 'meera',
        kind: MemoryKind.family,
        values: {'name': 'Meera', 'relationship': 'Wife'},
      ),
      MemoryEntry(
        id: 'breakfast',
        kind: MemoryKind.routine,
        values: {'name': 'Breakfast', 'time': '08:00'},
      ),
      MemoryEntry(
        id: 'morning-medicine',
        kind: MemoryKind.routine,
        values: {'name': 'Medicine', 'time': '09:00'},
      ),
      MemoryEntry(
        id: 'walk',
        kind: MemoryKind.routine,
        values: {'name': 'Walk', 'time': '17:00'},
      ),
      MemoryEntry(
        id: 'evening-medicine',
        kind: MemoryKind.routine,
        values: {'name': 'Medicine', 'time': '20:00'},
      ),
      MemoryEntry(
        id: 'gardening',
        kind: MemoryKind.activity,
        values: {'name': 'Gardening'},
      ),
    ],
  );
}
