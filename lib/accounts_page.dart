import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_gate.dart';
import 'account_manager.dart';
import 'login_page.dart';
import 'language_controller.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final Color primary = const Color(0xFF6C4CF1);

  List<SavedAccount> _accounts = [];
  bool _loading = true;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AccountManager.instance.getAccounts();

    if (!mounted) return;

    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _switchAccount(
      SavedAccount account,
      ) async {
    if (_switching) return;

    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    setState(() {
      _switching = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: account.email,
        password: account.password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AccountGate(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = isArabic
              ? 'كلمة المرور المحفوظة غير صحيحة.'
              : 'The saved password is incorrect.';
          break;

        case 'user-disabled':
          message = isArabic
              ? 'هذا الحساب تم تعطيله.'
              : 'This account has been disabled.';
          break;

        case 'network-request-failed':
          message = isArabic
              ? 'تحقق من اتصال الإنترنت.'
              : 'Check your internet connection.';
          break;

        default:
          message = isArabic
              ? 'تعذر تبديل الحساب.'
              : 'Could not switch account.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'حدث خطأ أثناء تبديل الحساب.'
                : 'An error occurred while switching accounts.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _switching = false;
        });
      }
    }
  }

  Future<void> _addAccount() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
          (route) => false,
    );
  }

  Future<void> _removeAccount(
      SavedAccount account,
      ) async {
    // حماية إضافية: حساب الأدمن لا يمكن حذفه.
    if (account.role == 'admin') {
      return;
    }

    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            isArabic
                ? 'حذف الحساب'
                : 'Remove Account',
          ),
          content: Text(
            isArabic
                ? 'سيتم حذف بيانات الدخول المحفوظة من هذا الجهاز فقط.'
                : 'The saved login information will be removed from this device only.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: Text(
                isArabic ? 'إلغاء' : 'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                isArabic ? 'حذف' : 'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await AccountManager.instance.removeAccount(
      account.email,
    );

    await _loadAccounts();
  }

  String _roleLabel(
      String role,
      bool isArabic,
      ) {
    switch (role) {
      case 'admin':
        return isArabic
            ? 'مسؤول النظام'
            : 'Administrator';

      case 'teacher':
        return isArabic
            ? 'تدريسي'
            : 'Teacher';

      default:
        return isArabic
            ? 'طالب'
            : 'Student';
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;

      case 'teacher':
        return Icons.school_rounded;

      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isArabic ? 'الحسابات' : 'Accounts',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadAccounts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            30,
          ),
          children: [
            _buildHeader(isArabic),
            const SizedBox(height: 20),
            if (_accounts.isEmpty)
              _buildEmptyState(
                isArabic,
                theme,
              )
            else
              ..._accounts.map(
                    (account) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _buildAccountCard(
                    account,
                    isArabic,
                    theme,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            _buildAddAccountButton(isArabic),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isArabic) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            const Color(0xFF8B6CFF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.switch_account_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic
                      ? 'إدارة حساباتك'
                      : 'Manage your accounts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isArabic
                      ? 'بدّل بين حساباتك بسهولة'
                      : 'Switch between your accounts easily',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
      SavedAccount account,
      bool isArabic,
      ThemeData theme,
      ) {
    final isAdmin = account.role == 'admin';

    return InkWell(
      onTap: _switching
          ? null
          : () => _switchAccount(account),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(
              alpha: 0.06,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness ==
                    Brightness.dark
                    ? 0.12
                    : 0.035,
              ),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primary.withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                _roleIcon(account.role),
                color: primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name.isEmpty
                        ? account.email
                        : account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    account.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.50),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _roleLabel(
                      account.role,
                      isArabic,
                    ),
                    style: TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!isAdmin)
              IconButton(
                tooltip: isArabic
                    ? 'حذف من الجهاز'
                    : 'Remove from device',
                onPressed: _switching
                    ? null
                    : () => _removeAccount(account),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAccountButton(bool isArabic) {
    return OutlinedButton.icon(
      onPressed: _switching
          ? null
          : _addAccount,
      icon: const Icon(
        Icons.person_add_alt_1_rounded,
      ),
      label: Text(
        isArabic
            ? 'إضافة حساب آخر'
            : 'Add another account',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(
          color: primary.withValues(alpha: 0.35),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        foregroundColor: primary,
      ),
    );
  }

  Widget _buildEmptyState(
      bool isArabic,
      ThemeData theme,
      ) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 55,
            color: primary.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 14),
          Text(
            isArabic
                ? 'لا توجد حسابات محفوظة'
                : 'No saved accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}