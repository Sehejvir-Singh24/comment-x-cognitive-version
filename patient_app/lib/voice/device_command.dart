import '../launcher/launcher_bridge.dart';

/// A small local command parser for launcher controls. Commands stay on the
/// phone and are never shared with Gemini.
enum DeviceCommandType { home, phone, app }

class DeviceCommand {
  const DeviceCommand._(this.type, {this.app});

  const DeviceCommand.home() : this._(DeviceCommandType.home);
  const DeviceCommand.phone() : this._(DeviceCommandType.phone);
  const DeviceCommand.app(PhoneApp this.app) : type = DeviceCommandType.app;

  final DeviceCommandType type;
  final PhoneApp? app;
}

class DeviceCommandParser {
  static DeviceCommand? parse(String text, Iterable<PhoneApp> apps) {
    final command = _normalise(text);
    if (command.isEmpty) return null;

    if (RegExp(r'^(go )?home$|^(go )?back home$').hasMatch(command)) {
      return const DeviceCommand.home();
    }
    if (RegExp(r'^(open |start |launch )?(phone|dialer|call)$')
        .hasMatch(command)) {
      return const DeviceCommand.phone();
    }

    const prefixes = ['open ', 'start ', 'launch '];
    final requested = prefixes
        .where(command.startsWith)
        .map((prefix) => _cleanAppName(command.substring(prefix.length)))
        .firstOrNull;
    if (requested == null || requested.isEmpty) return null;

    final candidates = apps.where((app) {
      final label = _normalise(app.label);
      final package = _normalise(app.packageName.split('.').last);
      return label == requested || package == requested;
    }).toList();
    if (candidates.length == 1) return DeviceCommand.app(candidates.single);

    final partial = apps.where((app) {
      final label = _normalise(app.label);
      final package = _normalise(app.packageName.split('.').last);
      return label.contains(requested) || package.contains(requested);
    }).toList();
    return partial.length == 1 ? DeviceCommand.app(partial.single) : null;
  }

  static String _normalise(String value) {
    var normalised = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Common speech-recognition spellings. They are resolved locally against
    // installed apps, rather than being sent to Gemini.
    normalised = normalised
        .replaceAll('what s app', 'whatsapp')
        .replaceAll('whats app', 'whatsapp')
        .replaceAll('what app', 'whatsapp')
        .replaceAll('you tube', 'youtube');
    return normalised;
  }

  static String _cleanAppName(String value) {
    var app = _normalise(value);
    app = app.replaceFirst(RegExp(r'^(the|a|an|my)\s+'), '');
    app = app.replaceFirst(RegExp(r'\s+please$'), '');
    return app.trim();
  }
}
