import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class DeviceMaker {
  final String manufacturer;
  final int sdk;

  const DeviceMaker({required this.manufacturer, required this.sdk});
}

class SystemSettingsChannel {
  SystemSettingsChannel({MethodChannel? channel, Future<void> Function()? fallback})
      : _channel = channel ?? const MethodChannel(channelName),
        _fallback = fallback ?? _openAppSettings;

  static const String channelName = 'bakhli/system_settings';
  static const String _battery = 'openBatterySettings';
  static const String _ring = 'openRingChannelSettings';
  static const String _notifications = 'openNotificationSettings';
  static const String _info = 'deviceInfo';

  static final SystemSettingsChannel instance = SystemSettingsChannel();

  final MethodChannel _channel;
  final Future<void> Function() _fallback;

  static Future<void> _openAppSettings() async {
    await ph.openAppSettings();
  }

  Future<bool> openBatterySettings() => _open(_battery);

  Future<bool> openNotificationSettings() => _open(_notifications);

  Future<bool> openRingChannelSettings(String channelId) => _open(_ring, {'channelId': channelId});

  Future<DeviceMaker?> deviceInfo() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>(_info);
      if (r == null) return null;
      return DeviceMaker(manufacturer: (r['manufacturer'] as String?) ?? '', sdk: (r['sdk'] as num?)?.toInt() ?? 0);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  // True when the system page opened; false when the app settings page was opened instead.
  Future<bool> _open(String method, [Map<String, Object?>? args]) async {
    try {
      final opened = await _channel.invokeMethod<bool>(method, args);
      if (opened == true) return true;
    } on MissingPluginException {
      // No native side (other platform or old build): fall through to app settings.
    } on PlatformException {
      // The page is missing on this device: fall through to app settings.
    }
    await _fallback();
    return false;
  }
}
