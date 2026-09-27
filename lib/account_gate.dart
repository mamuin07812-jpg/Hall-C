import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'language_controller.dart';

class AccountGate extends StatelessWidget {
  const AccountGate({super.key});

  Future<Map<String, dynamic>?> _loadProfile(User user) async {
    final firestore = FirebaseFirestore.instance;

    final studentDoc =
    await firestore.collection('students').doc(user.uid).get();

    if (studentDoc.exists) {
      return {
        ...studentDoc.data()!,
        '_collection': 'students',
      };
    }

    final teacherDoc =
    await firestore.collection('teachers').doc(user.uid).get();

    if (teacherDoc.exists) {
      return {
        ...teacherDoc.data()!,
        '_collection': 'teachers',
      };
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadProfile(user),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return const AccountErrorPage();
        }

        final role = profile['role']?.toString().toLowerCase() ?? '';

        // ============================================================
        // EMAIL VERIFICATION
        // ============================================================

        if (!user.emailVerified) {
          return EmailVerificationPage(
            isTeacher: role == 'teacher',
          );
        }

        // ============================================================
        // TEACHER
        // ============================================================

        if (role == 'teacher') {
          final status =
              profile['status']?.toString().toLowerCase() ?? 'pending';

          if (status != 'approved') {
            return const TeacherPendingPage();
          }

          return const HomePage();
        }

        // ============================================================
        // ADMIN
        // ============================================================

        if (role == 'admin') {
          return const HomePage();
        }

        // ============================================================
        // STUDENT
        // ============================================================

        if (role == 'student') {
          final profileCompleted =
              profile['profileCompleted'] == true;

          if (!profileCompleted) {
            return const StudentSetupPage();
          }

          return const HomePage();
        }

        return const AccountErrorPage();
      },
    );
  }
}

// ============================================================
// EMAIL VERIFICATION PAGE
// ============================================================

class EmailVerificationPage extends StatefulWidget {
  final bool isTeacher;

  const EmailVerificationPage({
    super.key,
    this.isTeacher = false,
  });

  @override
  State<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends State<EmailVerificationPage> {
  bool _checking = false;
  bool _sending = false;

  Future<void> _checkVerification() async {
    setState(() {
      _checking = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        return;
      }

      if (refreshedUser.emailVerified) {
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const AccountGate(),
          ),
              (route) => false,
        );
      } else {
        if (!mounted) return;

        final language = LanguageScope.of(context);
        final isArabic = language.isArabic;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'لم يتم توثيق البريد بعد. افتح الرابط الموجود في بريدك الإلكتروني.'
                  : 'Your email is not verified yet. Open the verification link in your email.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      final language = LanguageScope.of(context);
      final isArabic = language.isArabic;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'حدث خطأ أثناء التحقق. حاول مرة أخرى.'
                : 'An error occurred while checking verification.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _resendVerification() async {
    if (_sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await user.sendEmailVerification();

      if (!mounted) return;

      final language = LanguageScope.of(context);
      final isArabic = language.isArabic;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم إرسال رابط التحقق إلى بريدك الإلكتروني.'
                : 'A new verification link has been sent to your email.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final language = LanguageScope.of(context);
      final isArabic = language.isArabic;

      String message;

      if (e.code == 'too-many-requests') {
        message = isArabic
            ? 'تم إرسال طلبات كثيرة. حاول بعد قليل.'
            : 'Too many requests. Please try again later.';
      } else {
        message = isArabic
            ? 'تعذر إرسال رابط التحقق.'
            : 'Unable to send the verification email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6C4CF1),
                          Color(0xFF8C63F7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C4CF1)
                              .withValues(alpha: .20),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isArabic
                        ? 'وثّق بريدك الإلكتروني'
                        : 'Verify Your Email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF181625),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isArabic
                        ? 'أرسلنا رابط توثيق إلى بريدك الإلكتروني. افتح الرابط حتى تقدر تكمل التسجيل.'
                        : 'We sent a verification link to your email. Open the link to continue your registration.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF777487),
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: .045),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.email_rounded,
                          color: Color(0xFF6C4CF1),
                          size: 34,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF181625),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed:
                      _checking ? null : _checkVerification,
                      icon: _checking
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.verified_rounded,
                      ),
                      label: Text(
                        isArabic
                            ? 'تم التوثيق، متابعة'
                            : 'I Verified My Email',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF6C4CF1),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                        const Color(0xFFB9A8E8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed:
                    _sending ? null : _resendVerification,
                    icon: _sending
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: Text(
                      isArabic
                          ? 'إعادة إرسال الرابط'
                          : 'Resend Verification Link',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 19,
                    ),
                    label: Text(
                      isArabic
                          ? 'تسجيل الخروج'
                          : 'Sign Out',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                      const Color(0xFF777487),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STUDENT SETUP PAGE
// ============================================================

class StudentSetupPage extends StatefulWidget {
  const StudentSetupPage({
    super.key,
  });

  @override
  State<StudentSetupPage> createState() =>
      _StudentSetupPageState();
}

class _StudentSetupPageState extends State<StudentSetupPage> {
  static const Color primary = Color(0xFF6C4CF1);
  static const Color primaryDark = Color(0xFF5132C8);
  static const Color background = Color(0xFFF7F7FB);
  static const Color textDark = Color(0xFF181625);
  static const Color textMuted = Color(0xFF777487);

  String? _selectedStage;
  String? _selectedGroup;

  bool _isSaving = false;

  final List<Map<String, String>> _stages = const [
    {
      'value': 'First Stage',
      'ar': 'المرحلة الأولى',
      'en': 'First Stage',
    },
    {
      'value': 'Second Stage',
      'ar': 'المرحلة الثانية',
      'en': 'Second Stage',
    },
    {
      'value': 'Third Stage',
      'ar': 'المرحلة الثالثة',
      'en': 'Third Stage',
    },
    {
      'value': 'Fourth Stage',
      'ar': 'المرحلة الرابعة',
      'en': 'Fourth Stage',
    },
  ];

  final List<String> _groups = const [
    'A',
    'B',
    'C',
    'D',
  ];

  Future<void> _saveStudentInfo() async {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    if (_selectedStage == null || _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يرجى اختيار المرحلة والمجموعة أولاً'
                : 'Please select your stage and group first.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE5484D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User not found');
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .set(
        {
          'stage': _selectedStage,
          'group': _selectedGroup,
          'profileCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'حدث خطأ أثناء حفظ المعلومات'
                : 'An error occurred while saving your information.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE5484D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  String _stageLabel(String value, bool isArabic) {
    for (final stage in _stages) {
      if (stage['value'] == value) {
        return isArabic ? stage['ar']! : stage['en']!;
      }
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          primary,
                          Color(0xFF8C63F7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: .20),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isArabic
                        ? 'أكمل معلوماتك الدراسية'
                        : 'Complete Your Academic Information',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isArabic
                        ? 'حتى نعرض لك الجدول والتحضيرات والمعلومات المناسبة لك، اختر مرحلتك ومجموعتك.'
                        : 'Choose your academic stage and group so we can show you the correct schedule and content.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: .045),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .06),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic
                              ? 'المرحلة الدراسية'
                              : 'Academic Stage',
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F7FC),
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                          child:
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStage,
                            isExpanded: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.school_rounded,
                                color: primary,
                              ),
                              hintText: isArabic
                                  ? 'اختر المرحلة'
                                  : 'Select your stage',
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: _stages.map((stage) {
                              final value = stage['value']!;

                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  _stageLabel(
                                    value,
                                    isArabic,
                                  ),
                                  style: const TextStyle(
                                    color: textDark,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                              setState(() {
                                _selectedStage = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          isArabic ? 'المجموعة' : 'Group',
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F7FC),
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                          child:
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGroup,
                            isExpanded: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.groups_rounded,
                                color: primary,
                              ),
                              hintText: isArabic
                                  ? 'اختر المجموعة'
                                  : 'Select your group',
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder:
                              OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: _groups.map((group) {
                              return DropdownMenuItem<String>(
                                value: group,
                                child: Text(
                                  '${isArabic ? 'المجموعة' : 'Group'} $group',
                                  style: const TextStyle(
                                    color: textDark,
                                    fontWeight:
                                    FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: _isSaving
                                ? null
                                : (value) {
                              setState(() {
                                _selectedGroup = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : _saveStudentInfo,
                            icon: _isSaving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(
                              Icons.check_circle_rounded,
                            ),
                            label: Text(
                              isArabic
                                  ? 'حفظ والمتابعة'
                                  : 'Save & Continue',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                              primary.withValues(
                                alpha: .55,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton.icon(
                    onPressed: _isSaving ? null : _signOut,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 19,
                    ),
                    label: Text(
                      isArabic
                          ? 'تسجيل الخروج'
                          : 'Sign Out',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TEACHER PENDING
// ============================================================

class TeacherPendingPage extends StatelessWidget {
  const TeacherPendingPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color:
                    theme.colorScheme.primaryContainer,
                    borderRadius:
                    BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  isArabic
                      ? 'الحساب بانتظار الموافقة'
                      : 'Account Pending Approval',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic
                      ? 'تم إنشاء حساب الأستاذ بنجاح، لكنه يحتاج إلى موافقة الإدارة قبل الدخول إلى النظام.'
                      : 'Your teacher account has been created successfully, but it needs administrator approval before you can access the system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      isArabic
                          ? 'تسجيل الخروج'
                          : 'Sign Out',
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                    ),
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

// ============================================================
// ACCOUNT ERROR
// ============================================================

class AccountErrorPage extends StatelessWidget {
  const AccountErrorPage({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic
                      ? 'تعذر تحميل بيانات الحساب'
                      : 'Unable to Load Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic
                      ? 'لم يتم العثور على ملف الحساب في النظام.'
                      : 'No account profile was found in the system.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _signOut,
                  child: Text(
                    isArabic ? 'تسجيل الخروج' : 'Sign Out',
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