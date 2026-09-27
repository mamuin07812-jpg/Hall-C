import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'account_gate.dart';
import 'language_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _specializationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  String _accountType = 'student';

  LanguageController get _languageController =>
      LanguageScope.of(context);

  bool get _isArabic => _languageController.isArabic;

  String _t(String english, String arabic) {
    return _isArabic ? arabic : english;
  }

  bool get _isTeacher => _accountType == 'teacher';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _employeeIdController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _toggleLanguage() async {
    await _languageController.toggleLanguage();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('User creation failed');
      }

      final name = _nameController.text.trim();
      final email = _emailController.text.trim();

      await user.updateDisplayName(name);

      if (_isTeacher) {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'employeeId': _employeeIdController.text.trim(),
          'specialization': _specializationController.text.trim(),
          'department': 'English Language',
          'role': 'teacher',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'studentId': _studentIdController.text.trim(),
          'department': 'English Language',
          'profileCompleted': false,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // إرسال رابط توثيق البريد
      await user.sendEmailVerification();

      if (!mounted) return;

      // نذهب مباشرة إلى صفحة التحقق
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(
            isTeacher: _isTeacher,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = _t(
            'This email is already registered.',
            'هذا البريد الإلكتروني مسجل مسبقاً.',
          );
          break;

        case 'invalid-email':
          message = _t(
            'Please enter a valid email address.',
            'يرجى إدخال بريد إلكتروني صحيح.',
          );
          break;

        case 'weak-password':
          message = _t(
            'Password is too weak. Use at least 6 characters.',
            'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.',
          );
          break;

        case 'operation-not-allowed':
          message = _t(
            'Email registration is not enabled in Firebase.',
            'تسجيل البريد الإلكتروني غير مفعّل في Firebase.',
          );
          break;

        case 'network-request-failed':
          message = _t(
            'Check your internet connection and try again.',
            'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
          );
          break;

        default:
          message = e.message ??
              _t(
                'Something went wrong. Please try again.',
                'حدث خطأ ما. حاول مرة أخرى.',
              );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      String message;

      if (e.code == 'permission-denied') {
        message = _isTeacher
            ? _t(
          'Account created, but the teacher profile could not be saved. Check Firestore rules.',
          'تم إنشاء الحساب، لكن تعذر حفظ ملف الأستاذ. تحقق من قواعد Firestore.',
        )
            : _t(
          'Account created, but the student profile could not be saved. Check Firestore rules.',
          'تم إنشاء الحساب، لكن تعذر حفظ ملف الطالب. تحقق من قواعد Firestore.',
        );
      } else {
        message = _isTeacher
            ? _t(
          'Account created, but saving the teacher profile failed.',
          'تم إنشاء الحساب، لكن فشل حفظ بيانات الأستاذ.',
        )
            : _t(
          'Account created, but saving the student profile failed.',
          'تم إنشاء الحساب، لكن فشل حفظ بيانات الطالب.',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Something went wrong. Please try again.',
              'حدث خطأ ما. حاول مرة أخرى.',
            ),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _toggleLanguage,
              icon: const Icon(
                Icons.language_rounded,
                size: 18,
              ),
              label: Text(
                isArabic ? 'English' : 'العربية',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    _isTeacher
                        ? Icons.school_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _t(
                    'Create Account',
                    'إنشاء حساب',
                  ),
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    'Choose your account type to continue',
                    'اختر نوع الحساب للمتابعة',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                _accountTypeSelector(),
                const SizedBox(height: 24),
                _field(
                  controller: _nameController,
                  label: _t('Full Name', 'الاسم الكامل'),
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _t(
                        'Please enter your full name',
                        'يرجى إدخال الاسم الكامل',
                      );
                    }
                    if (value.trim().length < 3) {
                      return _t(
                        'Please enter your full name',
                        'يرجى إدخال الاسم الكامل',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _emailController,
                  label: _t(
                    'University Email',
                    'البريد الجامعي',
                  ),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return _t(
                        'Please enter your email',
                        'يرجى إدخال البريد الإلكتروني',
                      );
                    }
                    if (!value.contains('@')) {
                      return _t(
                        'Please enter a valid email',
                        'يرجى إدخال بريد إلكتروني صحيح',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                if (_isTeacher) ...[
                  _field(
                    controller: _employeeIdController,
                    label: _t(
                      'Employee ID',
                      'الرقم الوظيفي',
                    ),
                    icon: Icons.badge_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return _t(
                          'Please enter your employee ID',
                          'يرجى إدخال الرقم الوظيفي',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _specializationController,
                    label: _t(
                      'Specialization',
                      'التخصص',
                    ),
                    icon: Icons.menu_book_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return _t(
                          'Please enter your specialization',
                          'يرجى إدخال التخصص',
                        );
                      }
                      return null;
                    },
                  ),
                ] else
                  _field(
                    controller: _studentIdController,
                    label: _t(
                      'Student ID',
                      'الرقم الجامعي',
                    ),
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return _t(
                          'Please enter your student ID',
                          'يرجى إدخال الرقم الجامعي',
                        );
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 14),
                _field(
                  controller: _passwordController,
                  label: _t(
                    'Password',
                    'كلمة المرور',
                  ),
                  icon: Icons.lock_outline_rounded,
                  obscureText: _hidePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _hidePassword = !_hidePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _t(
                        'Please enter a password',
                        'يرجى إدخال كلمة المرور',
                      );
                    }
                    if (value.length < 6) {
                      return _t(
                        'Password must be at least 6 characters',
                        'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _confirmPasswordController,
                  label: _t(
                    'Confirm Password',
                    'تأكيد كلمة المرور',
                  ),
                  icon: Icons.lock_reset_rounded,
                  obscureText: _hideConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hideConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _hideConfirmPassword =
                        !_hideConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _t(
                        'Please confirm your password',
                        'يرجى تأكيد كلمة المرور',
                      );
                    }
                    if (value != _passwordController.text) {
                      return _t(
                        'Passwords do not match',
                        'كلمتا المرور غير متطابقتين',
                      );
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_isTeacher)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _t(
                              'Teacher accounts require administrator approval before accessing the system.',
                              'حسابات الأساتذة تحتاج إلى موافقة الإدارة قبل الدخول إلى النظام.',
                            ),
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isTeacher) const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C3CEB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      const Color(0xFFB9A8E8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      _isTeacher
                          ? _t(
                        'Register as Teacher',
                        'إنشاء حساب أستاذ',
                      )
                          : _t(
                        'Create Student Account',
                        'إنشاء حساب طالب',
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pop(context),
                  child: Text(
                    _t(
                      'Already have an account? Login',
                      'عندك حساب مسبقاً؟ تسجيل الدخول',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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

  Widget _accountTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _accountTypeButton(
              type: 'student',
              icon: Icons.person_rounded,
              title: _t('Student', 'طالب'),
              subtitle: _t(
                'Student account',
                'حساب طالب',
              ),
            ),
          ),
          Expanded(
            child: _accountTypeButton(
              type: 'teacher',
              icon: Icons.school_rounded,
              title: _t('Teacher', 'أستاذ'),
              subtitle: _t(
                'Teacher account',
                'حساب أستاذ',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountTypeButton({
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _accountType == type;

    return GestureDetector(
      onTap: _loading
          ? null
          : () {
        if (_accountType == type) return;

        setState(() {
          _accountType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C3CEB)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 27,
              color: selected
                  ? Colors.white
                  : const Color(0xFF6C3CEB),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: selected
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF6C3CEB),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}