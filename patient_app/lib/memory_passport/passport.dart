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
  factory MemoryEntry.fromJson(Map<String, dynamic> json) => MemoryEntry(
    id: json['id'] as String,
    kind: MemoryKind.values.byName(json['kind'] as String),
    values: Map<String, String>.from(json['values'] as Map),
    photo: json['photo'] as String?,
  );
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
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported passport version');
    }
    return Passport(
      name: json['name'] as String,
      age: json['age'] as int,
      region: json['region'] as String,
      isDemo: json['isDemo'] as bool,
      entries: (json['entries'] as List)
          .map((e) => MemoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
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
