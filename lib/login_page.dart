import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_gate.dart';
import 'account_manager.dart';
import 'forgot_password_page.dart';
import 'language_controller.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _rememberAccount = true;

  List<SavedAccount> _savedAccounts = [];
  bool _loadingSavedAccounts = true;

  static const Color primaryColor =
  Color(0xFF6C4CF1);

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts =
    await AccountManager.instance.getAccounts();

    if (!mounted) return;

    setState(() {
      _savedAccounts = accounts;
      _loadingSavedAccounts = false;
    });
  }

  Future<SavedAccount> _getAccountData(
      User user,
      ) async {
    try {
      final studentDoc =
      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data() ?? {};

        return SavedAccount(
          email: user.email ?? '',
          password: _passwordController.text,
          name: data['name']?.toString() ??
              user.displayName ??
              '',
          role: data['role']?.toString() ??
              'student',
          uid: user.uid,
        );
      }

      final teacherDoc =
      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .get();

      if (teacherDoc.exists) {
        final data = teacherDoc.data() ?? {};

        return SavedAccount(
          email: user.email ?? '',
          password: _passwordController.text,
          name: data['name']?.toString() ??
              user.displayName ??
              '',
          role: data['role']?.toString() ??
              'teacher',
          uid: user.uid,
        );
      }
    } catch (_) {}

    return SavedAccount(
      email: user.email ?? '',
      password: _passwordController.text,
      name: user.displayName ?? '',
      role: 'student',
      uid: user.uid,
    );
  }

  Future<void> _login() async {
    final language =
    LanguageScope.of(context);
    final isArabic = language.isArabic;

    final email =
    _emailController.text.trim();
    final password =
        _passwordController.text;

    if (email.isEmpty) {
      _showMessage(
        isArabic
            ? 'يرجى إدخال البريد الجامعي.'
            : 'Please enter your university email.',
      );
      return;
    }

    if (!email.contains('@')) {
      _showMessage(
        isArabic
            ? 'يرجى إدخال بريد إلكتروني صحيح.'
            : 'Please enter a valid email address.',
      );
      return;
    }

    if (password.isEmpty) {
      _showMessage(
        isArabic
            ? 'يرجى إدخال كلمة المرور.'
            : 'Please enter your password.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential =
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user != null && _rememberAccount) {
        final account =
        await _getAccountData(user);

        await AccountManager.instance
            .saveAccount(account);
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const AccountGate(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = isArabic
              ? 'يرجى إدخال بريد إلكتروني صحيح.'
              : 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = isArabic
              ? 'لا يوجد حساب بهذا البريد الإلكتروني.'
              : 'No account was found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = isArabic
              ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة.'
              : 'Incorrect email or password.';
          break;

        case 'user-disabled':
          message = isArabic
              ? 'تم تعطيل هذا الحساب.'
              : 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = isArabic
              ? 'محاولات كثيرة. حاول لاحقاً.'
              : 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = isArabic
              ? 'تحقق من اتصال الإنترنت وحاول مرة أخرى.'
              : 'Check your internet connection and try again.';
          break;

        default:
          message = e.message ??
              (isArabic
                  ? 'فشل تسجيل الدخول. حاول مرة أخرى.'
                  : 'Login failed. Please try again.');
      }

      _showMessage(
        message,
        color: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        isArabic
            ? 'حدث خطأ ما. حاول مرة أخرى.'
            : 'Something went wrong. Please try again.',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loginSavedAccount(
      SavedAccount account,
      ) async {
    final language =
    LanguageScope.of(context);
    final isArabic = language.isArabic;

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: account.email,
        password: account.password,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const AccountGate(),
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
              ? 'كلمة المرور المحفوظة غير صحيحة. سجّل الدخول يدوياً لتحديثها.'
              : 'The saved password is incorrect. Sign in manually to update it.';
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
              ? 'تعذر تسجيل الدخول بهذا الحساب.'
              : 'Could not sign in with this account.';
      }

      _showMessage(
        message,
        color: Colors.red,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        isArabic
            ? 'حدث خطأ أثناء تسجيل الدخول.'
            : 'An error occurred while signing in.',
        color: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _useSavedAccount(
      SavedAccount account,
      ) {
    _loginSavedAccount(account);
  }

  void _showMessage(
      String message, {
        Color color = Colors.black87,
      }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language =
    LanguageScope.of(context);
    final isArabic = language.isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment:
                AlignmentDirectional.topEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    tooltip: isArabic
                        ? 'تبديل اللغة'
                        : 'Change language',
                    onPressed: _loading
                        ? null
                        : () => language
                        .toggleLanguage(),
                    icon: Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isArabic ? 'EN' : 'ع',
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient:
                  const LinearGradient(
                    colors: [
                      Color(0xFF6C3CEB),
                      Color(0xFF8B5CF6),
                    ],
                  ),
                  borderRadius:
                  BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple
                          .withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 20,
                      offset:
                      const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),

              const SizedBox(height: 25),

              Text(
                isArabic
                    ? 'مرحباً بعودتك'
                    : 'Welcome Back',
                style:
                const TextStyle(
                  fontSize: 30,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isArabic
                    ? 'سجّل الدخول إلى ClassroomHub'
                    : 'Sign in to ClassroomHub',
                style: TextStyle(
                  color: theme
                      .colorScheme
                      .onSurface
                      .withValues(
                    alpha: 0.60,
                  ),
                  fontSize: 15,
                ),
              ),

              if (!_loadingSavedAccounts &&
                  _savedAccounts.isNotEmpty) ...[
                const SizedBox(height: 28),

                Align(
                  alignment:
                  AlignmentDirectional
                      .centerStart,
                  child: Text(
                    isArabic
                        ? 'حساباتك المحفوظة'
                        : 'Your saved accounts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.w800,
                      color: theme
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                ..._savedAccounts.map(
                      (account) => Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 9,
                    ),
                    child:
                    _buildSavedAccountCard(
                      account,
                      isArabic,
                      theme,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: theme
                            .colorScheme
                            .onSurface
                            .withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 12,
                      ),
                      child: Text(
                        isArabic
                            ? 'أو'
                            : 'OR',
                        style: TextStyle(
                          color: theme
                              .colorScheme
                              .onSurface
                              .withValues(
                            alpha: 0.40,
                          ),
                          fontSize: 11,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: theme
                            .colorScheme
                            .onSurface
                            .withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                const SizedBox(height: 35),

              const SizedBox(height: 12),

              TextField(
                controller:
                _emailController,
                keyboardType:
                TextInputType
                    .emailAddress,
                textInputAction:
                TextInputAction.next,
                enabled: !_loading,
                decoration:
                InputDecoration(
                  labelText: isArabic
                      ? 'البريد الجامعي'
                      : 'University Email',
                  prefixIcon:
                  const Icon(
                    Icons.email_outlined,
                  ),
                  filled: true,
                  fillColor: theme
                      .colorScheme.surface,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      Color(0xFF6C3CEB),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller:
                _passwordController,
                obscureText:
                _hidePassword,
                textInputAction:
                TextInputAction.done,
                enabled: !_loading,
                onSubmitted:
                    (_) => _login(),
                decoration:
                InputDecoration(
                  labelText: isArabic
                      ? 'كلمة المرور'
                      : 'Password',
                  prefixIcon:
                  const Icon(
                    Icons
                        .lock_outline_rounded,
                  ),
                  suffixIcon:
                  IconButton(
                    icon: Icon(
                      _hidePassword
                          ? Icons
                          .visibility_off_outlined
                          : Icons
                          .visibility_outlined,
                    ),
                    onPressed: _loading
                        ? null
                        : () {
                      setState(() {
                        _hidePassword =
                        !_hidePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: theme
                      .colorScheme.surface,
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    BorderSide.none,
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      Color(0xFF6C3CEB),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              CheckboxListTile(
                value: _rememberAccount,
                onChanged: _loading
                    ? null
                    : (value) {
                  setState(() {
                    _rememberAccount =
                        value ?? true;
                  });
                },
                contentPadding:
                EdgeInsets.zero,
                controlAffinity:
                ListTileControlAffinity
                    .leading,
                title: Text(
                  isArabic
                      ? 'حفظ الحساب على هذا الجهاز'
                      : 'Remember this account',
                  style:
                  const TextStyle(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),

              Align(
                alignment:
                AlignmentDirectional
                    .centerEnd,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                        const ForgotPasswordPage(),
                      ),
                    );
                  },
                  child: Text(
                    isArabic
                        ? 'نسيت كلمة المرور؟'
                        : 'Forgot Password?',
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                  _loading ? null : _login,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    primaryColor,
                    foregroundColor:
                    Colors.white,
                    disabledBackgroundColor:
                    const Color(
                      0xFFB9A8E8,
                    ),
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    isArabic
                        ? 'تسجيل الدخول'
                        : 'Login',
                    style:
                    const TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      isArabic
                          ? 'ليس لديك حساب؟'
                          : "Don't have an account?",
                      style: TextStyle(
                        color: theme
                            .colorScheme
                            .onSurface
                            .withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                          const RegisterPage(),
                        ),
                      );
                    },
                    child: Text(
                      isArabic
                          ? 'إنشاء حساب'
                          : 'Register',
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
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

  Widget _buildSavedAccountCard(
      SavedAccount account,
      bool isArabic,
      ThemeData theme,
      ) {
    IconData icon;

    switch (account.role) {
      case 'admin':
        icon =
            Icons.admin_panel_settings_rounded;
        break;

      case 'teacher':
        icon =
            Icons.school_rounded;
        break;

      default:
        icon =
            Icons.person_rounded;
    }

    String role;

    switch (account.role) {
      case 'admin':
        role = isArabic
            ? 'مسؤول النظام'
            : 'Administrator';
        break;

      case 'teacher':
        role = isArabic
            ? 'تدريسي'
            : 'Teacher';
        break;

      default:
        role = isArabic
            ? 'طالب'
            : 'Student';
    }

    return InkWell(
      onTap: _loading
          ? null
          : () => _useSavedAccount(
        account,
      ),
      borderRadius:
      BorderRadius.circular(18),
      child: Container(
        padding:
        const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: theme
              .colorScheme.surface,
          borderRadius:
          BorderRadius.circular(18),
          border: Border.all(
            color: primaryColor
                .withValues(
              alpha: 0.10,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
              BoxDecoration(
                color: primaryColor
                    .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                icon,
                color: primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    account.name.isEmpty
                        ? account.email
                        : account.name,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontSize: 14,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    account.email,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme
                          .colorScheme
                          .onSurface
                          .withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    role,
                    style:
                    const TextStyle(
                      color:
                      primaryColor,
                      fontSize: 10,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons
                  .arrow_forward_ios_rounded,
              size: 15,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}