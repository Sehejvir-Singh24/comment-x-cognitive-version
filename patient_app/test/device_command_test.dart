import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/launcher/launcher_bridge.dart';
import 'package:patient_app/voice/device_command.dart';

void main() {
  const apps = [
    PhoneApp('WhatsApp', 'com.whatsapp'),
    PhoneApp('YouTube', 'com.google.android.youtube'),
    PhoneApp('Camera', 'com.oplus.camera'),
  ];

  test('parses home and phone commands locally', () {
    expect(
      DeviceCommandParser.parse('go home', apps)?.type,
      DeviceCommandType.home,
    );
    expect(
      DeviceCommandParser.parse('open phone', apps)?.type,
      DeviceCommandType.phone,
    );
  });

  test('matches an installed app by its spoken label', () {
    final command = DeviceCommandParser.parse('open WhatsApp', apps);
    expect(command?.type, DeviceCommandType.app);
    expect(command?.app?.packageName, 'com.whatsapp');
  });

  test('understands common speech-recognition spellings of WhatsApp', () {
    final command = DeviceCommandParser.parse('open what\'s app', apps);
    expect(command?.type, DeviceCommandType.app);
    expect(command?.app?.packageName, 'com.whatsapp');
  });

  test('understands natural camera requests', () {
    final command = DeviceCommandParser.parse('open the camera please', apps);
    expect(command?.type, DeviceCommandType.app);
    expect(command?.app?.packageName, 'com.oplus.camera');
  });

  test('does not guess when an app is missing', () {
    expect(DeviceCommandParser.parse('open bank', apps), isNull);
  });
}
