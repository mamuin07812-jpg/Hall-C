import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLanguage = prefs.getString(_languageKey);

    if (savedLanguage == 'ar') {
      _locale = const Locale('ar');
    } else {
      _locale = const Locale('en');
    }

    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    _locale = Locale(languageCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);

    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    if (isArabic) {
      await changeLanguage('en');
    } else {
      await changeLanguage('ar');
    }
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required Widget child,
  }) : super(
    notifier: controller,
    child: child,
  );

  static LanguageController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<LanguageScope>();

    assert(
    scope != null,
    'LanguageScope not found in widget tree.',
    );

    return scope!.notifier!;
  }
}