import 'package:flutter/material.dart';

import 'action_context.dart';
import 'daily_narrative.dart';

class DailyNarrativeScreen extends StatefulWidget {
  const DailyNarrativeScreen({super.key});
  @override
  State<DailyNarrativeScreen> createState() => _DailyNarrativeScreenState();
}

class _DailyNarrativeScreenState extends State<DailyNarrativeScreen> {
  DailyNarrative? narrative;
  bool busy = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await ActionContext.today();
      if (mounted) {
        setState(() => narrative = DailyNarrative.fromEvents(events, DateTime.now()));
      }
    } catch (_) {
      if (mounted) setState(() => loadError = 'Could not read today’s local history.');
    }
  }

  Future<void> _share() async {
    final selected = narrative;
    if (selected == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share this summary?'),
        content: const Text(
          'Only the short lines shown here will go to the linked caretaker dashboard. Your detailed action history stays on this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep on phone'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Share summary'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      await selected.share();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Today’s summary shared with the caretaker dashboard.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not share summary: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Today with Saathi')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: loadError != null
          ? Center(child: Text(loadError!))
          : narrative == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'A short summary from actions saved on this phone.',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 20),
                for (final line in narrative!.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(line, style: const TextStyle(fontSize: 19)),
                      ),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy ? null : _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share with caretaker'),
                ),
              ],
            ),
    ),
  );
}
