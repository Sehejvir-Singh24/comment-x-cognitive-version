import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../launcher/launcher_bridge.dart';
import 'passport.dart';
import 'passport_store.dart';

String sectionTitle(MemoryKind kind, AppLocalizations s) => switch (kind) {
  MemoryKind.family => s.family,
  MemoryKind.place => s.places,
  MemoryKind.memory => s.memories,
  MemoryKind.routine => s.routines,
  MemoryKind.medicine => s.medicines,
  MemoryKind.activity => s.activities,
};
Map<String, String> entryFields(MemoryKind kind, AppLocalizations s) => {
  'name': s.nameLabel,
  if (kind == MemoryKind.family) ...{
    'relationship': s.relationshipLabel,
    'visits': s.visitsLabel,
    'sharedActivity': s.sharedActivityLabel,
  },
  if (kind == MemoryKind.routine || kind == MemoryKind.medicine)
    'time': s.timeLabel,
  if (kind == MemoryKind.medicine) 'instructions': s.doseLabel,
  'notes': s.notesLabel,
};

class PassportScreen extends StatefulWidget {
  const PassportScreen({
    super.key,
    required this.store,
    required this.onChanged,
  });
  final PassportStore store;
  final ValueChanged<Passport> onChanged;
  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  Passport? passport;
  bool failed = false;
  bool editing = false;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => failed = false);
    try {
      final value = await widget.store.load();
      if (!mounted) return;
      setState(() => passport = value);
      widget.onChanged(value);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> edit(
    MemoryKind kind, [
    MemoryEntry? entry,
    String? recovered,
  ]) async {
    final updated = await Navigator.of(context).push<Passport>(
      MaterialPageRoute(
        builder: (_) => EntryEditor(
          passport: passport!,
          kind: kind,
          entry: entry,
          recovered: recovered,
          store: widget.store,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => passport = updated);
      widget.onChanged(updated);
    }
  }

  Future<void> enableEditing() async {
    setState(() => editing = !editing);
    if (!editing) return;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.files?.isNotEmpty ?? false) {
        final photo = await widget.store.importPhoto(
          response.files!.first.path,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recoveredPhoto)),
        );
        await edit(MemoryKind.memory, null, photo);
      } else if (response.exception != null) {
        throw response.exception!;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.photoFailed)),
        );
      }
    }
  }

  Future<void> remove(MemoryEntry entry) async {
    final s = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.removeQuestion),
        content: Text(entry.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.removeEntry),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final updated = passport!.withEntries(
        passport!.entries.where((e) => e.id != entry.id).toList(),
      );
      await widget.store.save(updated);
      if (!mounted) return;
      setState(() => passport = updated);
      widget.onChanged(updated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final p = passport;
    return Scaffold(
      appBar: AppBar(title: Text(s.passport)),
      body: SafeArea(
        child: failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.loadFailed),
                      ElevatedButton(onPressed: load, child: Text(s.retry)),
                    ],
                  ),
                ),
              )
            : p == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${s.ageLabel}: ${p.age} · ${p.region}'),
                      Text(p.isDemo ? s.demoPassport : s.savedPassport),
                      const SizedBox(height: 12),
                      Text(s.localOnly),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: busy ? null : enableEditing,
                        child: Text(
                          editing ? s.finishEditing : s.caregiverEdit,
                        ),
                      ),
                      if (editing)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final updated = await Navigator.of(context)
                                      .push<Passport>(
                                        MaterialPageRoute(
                                          builder: (_) => ProfileEditor(
                                            passport: p,
                                            store: widget.store,
                                          ),
                                        ),
                                      );
                                  if (updated != null && mounted) {
                                    setState(() => passport = updated);
                                    widget.onChanged(updated);
                                  }
                                },
                          child: Text(s.profile),
                        ),
                      for (final kind in MemoryKind.values) ...[
                        const SizedBox(height: 28),
                        Text(
                          sectionTitle(kind, s),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (kind == MemoryKind.medicine ||
                            kind == MemoryKind.routine)
                          Text(s.medicineNotice),
                        if (!p.entries.any((e) => e.kind == kind))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(s.emptySection),
                          ),
                        for (final entry in p.entries.where(
                          (e) => e.kind == kind,
                        ))
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (kind == MemoryKind.family ||
                                      entry.photo != null)
                                    PassportPhoto(
                                      store: widget.store,
                                      photo: entry.photo,
                                    ),
                                  Text(
                                    entry.name,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  for (final field in entryFields(
                                    kind,
                                    s,
                                  ).entries)
                                    if (field.key != 'name' &&
                                        (entry.values[field.key]?.isNotEmpty ??
                                            false))
                                      Text(
                                        '${field.value}: ${entry.values[field.key]}',
                                      ),
                                  if (editing)
                                    Wrap(
                                      spacing: 16,
                                      children: [
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => edit(kind, entry),
                                          child: Text(s.editEntry),
                                        ),
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => remove(entry),
                                          child: Text(s.removeEntry),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (editing)
                          OutlinedButton(
                            onPressed: busy ? null : () => edit(kind),
                            child: Text(
                              '${s.addEntry} · ${sectionTitle(kind, s)}',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class PassportPhoto extends StatelessWidget {
  const PassportPhoto({super.key, required this.store, required this.photo});
  final PassportStore store;
  final String? photo;
  @override
  Widget build(BuildContext context) {
    final placeholder = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.person_outline, size: 64),
          Text(AppLocalizations.of(context)!.noPhoto),
        ],
      ),
    );
    if (photo == null) return placeholder;
    return FutureBuilder<File>(
      future: store.photoFile(photo!),
      builder: (context, snapshot) => snapshot.hasData
          ? Image.file(
              snapshot.data!,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) => placeholder,
            )
          : placeholder,
    );
  }
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.passport,
    required this.kind,
    required this.store,
    this.entry,
    this.recovered,
  });
  final Passport passport;
  final MemoryKind kind;
  final PassportStore store;
  final MemoryEntry? entry;
  final String? recovered;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  bool busy = false;
  bool dirty = false;
  bool leaving = false;
  String? photo;
  String? error;
  @override
  void initState() {
    super.initState();
    photo = widget.entry?.photo ?? widget.recovered;
    dirty = widget.recovered != null;
    LauncherBridge.homeRequests.addListener(returnHome);
  }

  void returnHome() {
    if (mounted) setState(() => leaving = true);
  }

  @override
  void dispose() {
    LauncherBridge.homeRequests.removeListener(returnHome);
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    final s = AppLocalizations.of(context)!;
    final yes =
        !dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(s.discardQuestion),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(s.keepEditing),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(s.discard),
                  ),
                ],
              ),
            ) ==
            true;
    if (yes && mounted) {
      setState(() => leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> pickPhoto() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (selected == null) return;
      final name = await widget.store.importPhoto(selected.path);
      if (mounted) {
        setState(() {
          photo = name;
          dirty = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = AppLocalizations.of(context)!.photoFailed);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final entry = MemoryEntry(
        id:
            widget.entry?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        kind: widget.kind,
        values: controllers.map((key, c) => MapEntry(key, c.text.trim())),
        photo: photo,
      );
      final entries = [...widget.passport.entries];
      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index < 0) {
        entries.add(entry);
      } else {
        entries[index] = entry;
      }
      final updated = widget.passport.withEntries(entries);
      await widget.store.save(updated);
      if (!mounted) return;
      setState(() {
        busy = false;
        dirty = false;
        leaving = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, updated);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = AppLocalizations.of(context)!.saveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    final fields = entryFields(widget.kind, s);
    for (final key in fields.keys) {
      controllers.putIfAbsent(
        key,
        () => TextEditingController(text: widget.entry?.values[key] ?? ''),
      );
    }
    return PopScope(
      canPop: leaving || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(sectionTitle(widget.kind, s))),
        body: Form(
          key: form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: TextFormField(
                      controller: controllers[field.key],
                      enabled: !busy,
                      maxLength: field.key == 'notes' ? 1000 : 200,
                      decoration: InputDecoration(
                        labelText: field.value,
                        border: const OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: field.key == 'notes' ? 4 : 1,
                      onChanged: (_) => setState(() => dirty = true),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if ((field.key == 'name' ||
                                field.key == 'relationship') &&
                            text.isEmpty) {
                          return s.requiredField;
                        }
                        if (field.key == 'time' &&
                            (widget.kind == MemoryKind.routine ||
                                text.isNotEmpty) &&
                            !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                                .hasMatch(text)) {
                          return s.invalidTime;
                        }
                        return null;
                      },
                    ),
                  ),
                if (widget.kind == MemoryKind.family ||
                    widget.kind == MemoryKind.place ||
                    widget.kind == MemoryKind.memory) ...[
                  PassportPhoto(store: widget.store, photo: photo),
                  OutlinedButton(
                    onPressed: busy ? null : pickPhoto,
                    child: Text(s.choosePhoto),
                  ),
                  if (photo != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              photo = null;
                              dirty = true;
                            }),
                      child: Text(s.removePhoto),
                    ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ElevatedButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? s.saving : s.save),
                ),
                TextButton(
                  onPressed: busy ? null : leave,
                  child: Text(s.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.passport, required this.store});
  final Passport passport;
  final PassportStore store;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.passport.name);
  late final age = TextEditingController(text: widget.passport.age.toString());
  late final region = TextEditingController(text: widget.passport.region);
  late bool demo = widget.passport.isDemo;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    age.dispose();
    region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final field in [
                (name, s.nameLabel),
                (age, s.ageLabel),
                (region, s.regionLabel),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextFormField(
                    controller: field.$1,
                    enabled: !busy,
                    maxLength: 100,
                    keyboardType: field.$1 == age
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: field.$2,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return s.requiredField;
                      }
                      if (field.$1 == age) {
                        final number = int.tryParse(value.trim());
                        if (number == null || number < 1 || number > 120) {
                          return s.invalidAge;
                        }
                      }
                      return null;
                    },
                  ),
                ),
              SwitchListTile(
                title: Text(s.demoProfile),
                value: demo,
                onChanged: busy
                    ? null
                    : (value) => setState(() => demo = value),
              ),
              if (error != null) Text(error!),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        final updated = Passport(
                          name: name.text.trim(),
                          age: int.parse(age.text.trim()),
                          region: region.text.trim(),
                          entries: widget.passport.entries,
                          isDemo: demo,
                        );
                        try {
                          await widget.store.save(updated);
                          if (context.mounted) Navigator.pop(context, updated);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              busy = false;
                              error = s.saveFailed;
                            });
                          }
                        }
                      },
                child: Text(busy ? s.saving : s.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
