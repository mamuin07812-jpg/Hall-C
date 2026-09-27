import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _soundsKey = 'sounds_enabled';
  static const String _vibrationKey = 'vibration_enabled';
  static const String _notificationSoundKey = 'notification_sound';

  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _soundsEnabled = true;
  bool _vibrationEnabled = true;

  String _notificationSound = 'Default';

  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get soundsEnabled => _soundsEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get notificationSound => _notificationSound;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_themeKey);

    switch (savedTheme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;

      case 'dark':
        _themeMode = ThemeMode.dark;
        break;

      default:
        _themeMode = ThemeMode.system;
    }

    _notificationsEnabled =
        prefs.getBool(_notificationsKey) ?? true;

    _soundsEnabled =
        prefs.getBool(_soundsKey) ?? true;

    _vibrationEnabled =
        prefs.getBool(_vibrationKey) ?? true;

    _notificationSound =
        prefs.getString(_notificationSoundKey) ?? 'Default';

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    final prefs = await SharedPreferences.getInstance();

    String value;

    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;

      case ThemeMode.dark:
        value = 'dark';
        break;

      case ThemeMode.system:
        value = 'system';
        break;
    }

    await prefs.setString(_themeKey, value);

    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);

    notifyListeners();
  }

  Future<void> setSounds(bool value) async {
    _soundsEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundsKey, value);

    notifyListeners();
  }

  Future<void> setVibration(bool value) async {
    _vibrationEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, value);

    notifyListeners();
  }

  Future<void> setNotificationSound(String sound) async {
    _notificationSound = sound;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationSoundKey,
      sound,
    );

    notifyListeners();
  }
}

class SettingsScope extends InheritedNotifier<AppSettingsController> {
  const SettingsScope({
    super.key,
    required AppSettingsController controller,
    required Widget child,
  }) : super(
    notifier: controller,
    child: child,
  );

  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<SettingsScope>();

    assert(
    scope != null,
    'SettingsScope not found in widget tree.',
    );

    return scope!.notifier!;
  }
}