import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'language_controller.dart';
import 'login_page.dart';

const Color primary = Color(0xFF6C4CF1);
const Color primaryDark = Color(0xFF5132C8);
const Color background = Color(0xFFF7F7FB);
const Color textDark = Color(0xFF181625);
const Color textMuted = Color(0xFF777487);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final settings = SettingsScope.of(context);
    final isArabic = language.isArabic;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            isArabic ? 'الإعدادات' : 'Settings',
            style: const TextStyle(
              color: textDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,

          // زر الرجوع ثابت أعلى اليمين
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: _AppBarButton(
                icon: isArabic
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ],
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),
          children: [
            _SettingsHeader(
              isArabic: isArabic,
              email: FirebaseAuth.instance.currentUser?.email ?? '',
            ),

            const SizedBox(height: 26),

            _sectionTitle(
              isArabic ? 'المظهر' : 'Appearance',
            ),

            _settingsCard(
              children: [
                _SettingTile(
                  icon: Icons.language_rounded,
                  title: isArabic ? 'اللغة' : 'Language',
                  subtitle: isArabic ? 'العربية' : 'English',
                  onTap: () => _showLanguageSheet(
                    context,
                    language,
                    isArabic,
                  ),
                ),
                _divider(),
                _SettingTile(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: isArabic ? 'المظهر' : 'Theme',
                  subtitle: _themeName(
                    settings.themeMode,
                    isArabic,
                  ),
                  onTap: () => _showThemeSheet(
                    context,
                    settings,
                    isArabic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _sectionTitle(
              isArabic
                  ? 'التنبيهات والتفاعل'
                  : 'Notifications & Interaction',
            ),

            _settingsCard(
              children: [
                _SwitchTile(
                  icon: Icons.notifications_none_rounded,
                  title: isArabic ? 'الإشعارات' : 'Notifications',
                  subtitle: isArabic
                      ? 'السماح بإشعارات التطبيق'
                      : 'Allow app notifications',
                  value: settings.notificationsEnabled,
                  onChanged: settings.setNotifications,
                ),
                _divider(),
                _SettingTile(
                  icon: Icons.music_note_rounded,
                  title: isArabic
                      ? 'صوت الإشعارات'
                      : 'Notification Sound',
                  subtitle: _soundName(
                    settings.notificationSound,
                    isArabic,
                  ),
                  enabled: settings.notificationsEnabled,
                  onTap: settings.notificationsEnabled
                      ? () => _showNotificationSoundSheet(
                    context,
                    settings,
                    isArabic,
                  )
                      : null,
                ),
                _divider(),
                _SwitchTile(
                  icon: Icons.volume_up_outlined,
                  title: isArabic
                      ? 'أصوات التطبيق'
                      : 'App Sounds',
                  subtitle: isArabic
                      ? 'تشغيل أصوات التفاعل'
                      : 'Play interaction sounds',
                  value: settings.soundsEnabled,
                  onChanged: settings.setSounds,
                ),
                _divider(),
                _SwitchTile(
                  icon: Icons.vibration_rounded,
                  title: isArabic
                      ? 'الاهتزاز'
                      : 'Haptic Feedback',
                  subtitle: isArabic
                      ? 'اهتزاز عند بعض التفاعلات'
                      : 'Vibrate during interactions',
                  value: settings.vibrationEnabled,
                  onChanged: settings.setVibration,
                ),
              ],
            ),

            const SizedBox(height: 24),

            _sectionTitle(
              isArabic ? 'الحساب' : 'Account',
            ),

            _settingsCard(
              children: [
                _SettingTile(
                  icon: Icons.lock_reset_rounded,
                  title: isArabic
                      ? 'تغيير كلمة المرور'
                      : 'Change Password',
                  subtitle: isArabic
                      ? 'إرسال رابط إعادة تعيين كلمة المرور'
                      : 'Send a password reset link',
                  onTap: () => _changePassword(
                    context,
                    isArabic,
                  ),
                ),
                _divider(),
                _AccountTile(
                  email:
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  isArabic: isArabic,
                ),
                _divider(),
                _LogoutTile(
                  isArabic: isArabic,
                  onTap: () => _signOut(
                    context,
                    isArabic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _sectionTitle(
              isArabic ? 'حول التطبيق' : 'About',
            ),

            _settingsCard(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  leading: _iconBox(
                    Icons.school_rounded,
                  ),
                  title: const Text(
                    'ClassroomHub',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isArabic
                          ? 'بواسطة مأمون الهذال'
                          : 'By Mamoun Al-Hathal',
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _divider(),
                _InfoTile(
                  icon: Icons.info_outline_rounded,
                  title: isArabic
                      ? 'إصدار التطبيق'
                      : 'App Version',
                  value: '1.0.0',
                ),
                _divider(),
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  title: isArabic ? 'المطور' : 'Developer',
                  value:
                  isArabic ? 'مأمون الهذال' : 'Mamoun Al-Hathal',
                ),
              ],
            ),

            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ClassroomHub',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic
                        ? '2026 • التعليم الجامعي بشكل أبسط'
                        : '2026 • University learning made simpler',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        right: 4,
        bottom: 10,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _settingsCard({
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 74, right: 74),
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: Color(0xFFEDEAF3),
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: primary,
        size: 21,
      ),
    );
  }

  String _themeName(
      ThemeMode mode,
      bool isArabic,
      ) {
    switch (mode) {
      case ThemeMode.light:
        return isArabic ? 'الوضع الفاتح' : 'Light';
      case ThemeMode.dark:
        return isArabic ? 'الوضع الداكن' : 'Dark';
      case ThemeMode.system:
        return isArabic
            ? 'حسب إعدادات الجهاز'
            : 'System default';
    }
  }

  String _soundName(
      String sound,
      bool isArabic,
      ) {
    switch (sound) {
      case 'Soft':
        return isArabic ? 'ناعم' : 'Soft';
      case 'Chime':
        return isArabic ? 'رنين' : 'Chime';
      case 'Alert':
        return isArabic ? 'تنبيه' : 'Alert';
      default:
        return isArabic ? 'الافتراضي' : 'Default';
    }
  }

  String _themeValue(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _showLanguageSheet(
      BuildContext context,
      LanguageController language,
      bool isArabic,
      ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ChoiceSheet(
          title: isArabic ? 'اختيار اللغة' : 'Choose Language',
          subtitle: isArabic
              ? 'اختر لغة التطبيق'
              : 'Choose the app language',
          icon: Icons.language_rounded,
          options: const [
            _ChoiceItem(
              value: 'en',
              title: 'English',
              subtitle: 'English language',
              icon: Icons.language_rounded,
            ),
            _ChoiceItem(
              value: 'ar',
              title: 'العربية',
              subtitle: 'اللغة العربية',
              icon: Icons.translate_rounded,
            ),
          ],
          selectedValue: language.locale.languageCode,
          onSelected: (value) async {
            await language.changeLanguage(value);

            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
        );
      },
    );
  }

  Future<void> _showThemeSheet(
      BuildContext context,
      AppSettingsController settings,
      bool isArabic,
      ) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ChoiceSheet(
          title: isArabic ? 'اختيار المظهر' : 'Choose Theme',
          subtitle: isArabic
              ? 'اختر طريقة عرض التطبيق'
              : 'Choose how the app looks',
          icon: Icons.palette_outlined,
          options: [
            _ChoiceItem(
              value: 'system',
              title: isArabic
                  ? 'حسب إعدادات الجهاز'
                  : 'System default',
              subtitle: isArabic
                  ? 'يتبع إعدادات جهازك'
                  : 'Follow device settings',
              icon: Icons.settings_suggest_rounded,
            ),
            _ChoiceItem(
              value: 'light',
              title: isArabic ? 'الوضع الفاتح' : 'Light',
              subtitle: isArabic
                  ? 'مظهر فاتح'
                  : 'Light appearance',
              icon: Icons.light_mode_rounded,
            ),
            _ChoiceItem(
              value: 'dark',
              title: isArabic ? 'الوضع الداكن' : 'Dark',
              subtitle: isArabic
                  ? 'مظهر داكن'
                  : 'Dark appearance',
              icon: Icons.dark_mode_rounded,
            ),
          ],
          selectedValue: _themeValue(settings.themeMode),
          onSelected: (value) async {
            final ThemeMode mode;

            if (value == 'light') {
              mode = ThemeMode.light;
            } else if (value == 'dark') {
              mode = ThemeMode.dark;
            } else {
              mode = ThemeMode.system;
            }

            await settings.setThemeMode(mode);

            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
        );
      },
    );
  }

  Future<void> _showNotificationSoundSheet(
      BuildContext context,
      AppSettingsController settings,
      bool isArabic,
      ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NotificationSoundSheet(
          settings: settings,
          isArabic: isArabic,
        );
      },
    );
  }

  Future<void> _changePassword(
      BuildContext context,
      bool isArabic,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      _showMessage(
        context,
        isArabic
            ? 'لا يوجد بريد إلكتروني مرتبط بالحساب.'
            : 'No email is linked to this account.',
        isError: true,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!context.mounted) return;

      _showMessage(
        context,
        isArabic
            ? 'تم إرسال رابط تغيير كلمة المرور إلى بريدك.'
            : 'A password reset link has been sent to your email.',
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ??
            (isArabic
                ? 'تعذر إرسال الرابط.'
                : 'Unable to send the reset link.'),
        isError: true,
      );
    }
  }

  Future<void> _signOut(
      BuildContext context,
      bool isArabic,
      ) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _SignOutSheet(
          isArabic: isArabic,
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        e.message ??
            (isArabic
                ? 'تعذر تسجيل الخروج.'
                : 'Unable to sign out.'),
        isError: true,
      );
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        isArabic
            ? 'حدث خطأ أثناء تسجيل الخروج.'
            : 'An error occurred while signing out.',
        isError: true,
      );
    }
  }

  void _showMessage(
      BuildContext context,
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }
}

class _SettingsHeader extends StatelessWidget {
  final bool isArabic;
  final String email;

  const _SettingsHeader({
    required this.isArabic,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C4CF1),
            Color(0xFF8C63F7),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C4CF1)
                .withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -42,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -65,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      isArabic ? 'التطبيق' : 'APP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isArabic
                    ? 'إعدادات التطبيق'
                    : 'App Settings',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                isArabic
                    ? 'خصص التطبيق بالطريقة التي تناسبك'
                    : 'Customize the app to your preference',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color:
                    Colors.white.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: primary,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: textDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: textMuted,
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF9994A3),
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: primary,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: textDark,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          subtitle,
          style: const TextStyle(
            color: textMuted,
            fontSize: 12,
          ),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: primary,
        onChanged: onChanged,
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String email;
  final bool isArabic;

  const _AccountTile({
    required this.email,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: primary,
          size: 21,
        ),
      ),
      title: Text(
        isArabic ? 'الحساب الحالي' : 'Current Account',
        style: const TextStyle(
          color: textDark,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          email.isEmpty
              ? (isArabic ? 'لا يوجد بريد' : 'No email')
              : email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: textMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onTap;

  const _LogoutTile({
    required this.isArabic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 7,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.logout_rounded,
          color: Colors.red,
          size: 21,
        ),
      ),
      title: Text(
        isArabic ? 'تسجيل الخروج' : 'Sign Out',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        isArabic
            ? 'الخروج من حسابك'
            : 'Sign out from your account',
        style: TextStyle(
          color: Colors.red.withValues(alpha: 0.55),
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.red,
      ),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: primary,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: textDark,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE8FF),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AppBarButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: const Color(0xFF252130),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _ChoiceItem {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ChoiceItem({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _ChoiceSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_ChoiceItem> options;
  final String selectedValue;
  final Future<void> Function(String value) onSelected;

  const _ChoiceSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isArabic =
    RegExp(r'[\u0600-\u06FF]').hasMatch(title);

    return Directionality(
      textDirection:
      isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color:
                  colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      icon,
                      color: primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...options.asMap().entries.map(
                    (entry) {
                  final option = entry.value;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == options.length - 1
                          ? 0
                          : 9,
                    ),
                    child: _ChoiceOption(
                      item: option,
                      selected:
                      option.value == selectedValue,
                      onTap: () =>
                          onSelected(option.value),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceOption extends StatelessWidget {
  final _ChoiceItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic =
    RegExp(r'[\u0600-\u06FF]').hasMatch(item.title);

    return Directionality(
      textDirection:
      isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.08)
                  : const Color(0xFFF8F7FB),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: selected
                    ? primary.withValues(alpha: 0.55)
                    : const Color(0xFFEDEAF3),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? primary
                        : primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.icon,
                    color:
                    selected ? Colors.white : primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color:
                      primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: primary,
                      size: 19,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationSoundSheet extends StatelessWidget {
  final AppSettingsController settings;
  final bool isArabic;

  const _NotificationSoundSheet({
    required this.settings,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection:
      isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color:
                  colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic
                              ? 'صوت الإشعارات'
                              : 'Notification Sound',
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isArabic
                              ? 'اختر النغمة التي تناسبك'
                              : 'Choose your preferred sound',
                          style: const TextStyle(
                            color: textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _soundOption(
                context,
                value: 'Default',
                icon: Icons.notifications_none_rounded,
                title:
                isArabic ? 'الافتراضي' : 'Default',
                subtitle: isArabic
                    ? 'صوت إشعارات النظام'
                    : 'System notification sound',
              ),
              const SizedBox(height: 9),
              _soundOption(
                context,
                value: 'Soft',
                icon: Icons.water_drop_outlined,
                title: isArabic ? 'ناعم' : 'Soft',
                subtitle: isArabic
                    ? 'نغمة هادئة وخفيفة'
                    : 'Soft and subtle tone',
              ),
              const SizedBox(height: 9),
              _soundOption(
                context,
                value: 'Chime',
                icon: Icons.auto_awesome_rounded,
                title: isArabic ? 'رنين' : 'Chime',
                subtitle: isArabic
                    ? 'نغمة واضحة وعصرية'
                    : 'Clear and modern tone',
              ),
              const SizedBox(height: 9),
              _soundOption(
                context,
                value: 'Alert',
                icon: Icons.bolt_rounded,
                title: isArabic ? 'تنبيه' : 'Alert',
                subtitle: isArabic
                    ? 'نغمة قصيرة وواضحة'
                    : 'Short and noticeable tone',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _soundOption(
      BuildContext context, {
        required String value,
        required IconData icon,
        required String title,
        required String subtitle,
      }) {
    final selected =
        settings.notificationSound == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () async {
          await settings.setNotificationSound(value);

          if (context.mounted) {
            Navigator.pop(context);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.08)
                : const Color(0xFFF8F7FB),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.55)
                  : const Color(0xFFEDEAF3),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? primary
                      : primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color:
                  selected ? Colors.white : primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                    primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: primary,
                    size: 19,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutSheet extends StatelessWidget {
  final bool isArabic;

  const _SignOutSheet({
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
      isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 29,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                isArabic
                    ? 'تسجيل الخروج'
                    : 'Sign Out',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                isArabic
                    ? 'هل أنت متأكد من تسجيل الخروج من حسابك؟'
                    : 'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize:
                        const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFE4E0EB),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'إلغاء' : 'Cancel',
                        style: const TextStyle(
                          color: textDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize:
                        const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isArabic ? 'خروج' : 'Sign Out',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}