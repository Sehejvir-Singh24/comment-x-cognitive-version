import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PhoneApp {
  const PhoneApp(this.label, this.packageName);
  final String label;
  final String packageName;
}

class LauncherBridge {
  static const channel = MethodChannel('org.saathi/launcher');
  static final homeRequests = ValueNotifier<int>(0);

  Future<bool> isDefaultHome() async =>
      await channel.invokeMethod<bool>('isDefaultHome') ?? false;

  Future<void> requestHome() => channel.invokeMethod<void>('requestHome');

  Future<List<PhoneApp>> apps() async {
    final values = await channel.invokeListMethod<dynamic>('listApps') ?? [];
    return values.map((value) {
      final map = Map<String, dynamic>.from(value as Map);
      return PhoneApp(map['label'] as String, map['packageName'] as String);
    }).toList();
  }

  Future<void> openApp(String packageName) =>
      channel.invokeMethod<void>('openApp', {'packageName': packageName});
  Future<void> openDialer() => channel.invokeMethod<void>('openDialer');
  Future<void> dialNumber(String number) =>
      channel.invokeMethod<void>('dialNumber', {'number': number});
  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
  Future<void> openMaps() => channel.invokeMethod<void>('openMaps');
  Future<void> openCalendar() => channel.invokeMethod<void>('openCalendar');
  Future<void> openContacts() => channel.invokeMethod<void>('openContacts');

  Future<bool> usageAccessGranted() async =>
      await channel.invokeMethod<bool>('usageAccessGranted') ?? false;
  Future<void> openUsageAccessSettings() =>
      channel.invokeMethod<void>('openUsageAccessSettings');
  Future<List<Map<String, dynamic>>> recentUsage() async =>
      (await channel.invokeListMethod<dynamic>('recentUsage') ?? [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
  Future<bool> notificationAccessGranted() async =>
      await channel.invokeMethod<bool>('notificationAccessGranted') ?? false;
  Future<void> openNotificationAccessSettings() =>
      channel.invokeMethod<void>('openNotificationAccessSettings');
  Future<void> setNotificationCapture(bool value) =>
      channel.invokeMethod<void>('setNotificationCapture', {'enabled': value});
  Future<List<Map<String, dynamic>>> notificationPreviews() async =>
      (await channel.invokeListMethod<dynamic>('notificationPreviews') ?? [])
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
  Future<String?> consumeShare() =>
      channel.invokeMethod<String>('consumeShare');
  Future<void> openWebLink(String url) =>
      channel.invokeMethod<void>('openWebLink', {'url': url});
}
