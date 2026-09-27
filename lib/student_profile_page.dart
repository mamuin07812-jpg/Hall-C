import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

const Color _primary = Color(0xFF6C4CF1);
const Color _primaryDark = Color(0xFF5132C8);
const Color _background = Color(0xFFF7F7FB);
const Color _textDark = Color(0xFF181625);
const Color _textMuted = Color(0xFF777487);
const Color _softPurple = Color(0xFFF1EDFF);
const Color _danger = Color(0xFFE5484D);

class StudentProfilePage extends StatelessWidget {
  const StudentProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Text(
            'User not found',
            style: TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .snapshots(),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
          final data = studentSnapshot.data!.data() ?? {};

          return _ProfileContent(
            user: user,
            profile: data,
            isTeacher: false,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('teachers')
              .doc(user.uid)
              .snapshots(),
          builder: (context, teacherSnapshot) {
            if (teacherSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (teacherSnapshot.hasData &&
                teacherSnapshot.data!.exists) {
              final data = teacherSnapshot.data!.data() ?? {};

              return _ProfileContent(
                user: user,
                profile: data,
                isTeacher: true,
              );
            }

            return const Scaffold(
              backgroundColor: _background,
              body: Center(
                child: Text(
                  'Profile not found',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _background,
      body: Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: _primary,
        ),
      ),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profile;
  final bool isTeacher;

  const _ProfileContent({
    required this.user,
    required this.profile,
    required this.isTeacher,
  });

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  final ImagePicker _picker = ImagePicker();

  bool _isArabic = true;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  late TextEditingController _stageController;
  late TextEditingController _groupController;
  late TextEditingController _departmentController;

  final List<String> _stages = const [
    'First Stage',
    'Second Stage',
    'Third Stage',
    'Fourth Stage',
  ];

  final List<String> _departments = const [
    'English Language Department',
    'Arabic Language Department',
    'Mathematics Department',
    'Science Department',
    'Computer Science Department',
    'Physical Education Department',
    'Other',
  ];

  final List<String> _groups = const [
    'A',
    'B',
    'C',
    'D',
  ];

  @override
  void initState() {
    super.initState();

    _stageController = TextEditingController(
      text: _readValue([
        'stage',
        'academicStage',
        'year',
      ]),
    );

    _groupController = TextEditingController(
      text: _normalizeGroup(
        _readValue([
          'group',
          'studentGroup',
          'section',
        ]),
      ),
    );

    _departmentController = TextEditingController(
      text: _getDepartment(),
    );
  }

  @override
  void dispose() {
    _stageController.dispose();
    _groupController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  String _readValue(List<String> keys) {
    for (final key in keys) {
      final value = widget.profile[key];

      if (value != null &&
          value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  String _normalizeGroup(String value) {
    final group = value.trim().toUpperCase();

    if (_groups.contains(group)) {
      return group;
    }

    return '';
  }

  String _getName() {
    return _readValue([
      'name',
      'fullName',
      'displayName',
      'studentName',
      'teacherName',
    ]);
  }

  String _getEmail() {
    final value = _readValue([
      'email',
      'emailAddress',
    ]);

    return value.isNotEmpty ? value : (widget.user.email ?? '');
  }

  String _getDepartment() {
    return _readValue([
      'department',
      'departmentName',
      'dept',
      'departmentTitle',
      'sectionName',
      'قسم',
      'القسم',
    ]);
  }

  String _getSpecialization() {
    return _readValue([
      'specialization',
      'specialisation',
      'major',
      'specialty',
      'speciality',
      'تخصص',
      'التخصص',
    ]);
  }

  String _getTeacherRole() {
    final role = _readValue([
      'role',
      'position',
      'jobTitle',
      'title',
      'academicTitle',
      'teacherRole',
      'userRole',
    ]);

    if (role.isNotEmpty) {
      final lower = role.toLowerCase();

      if (lower == 'teacher' ||
          lower == 'lecturer' ||
          lower == 'professor' ||
          lower == 'instructor') {
        return _isArabic ? 'تدريسي' : 'Teacher';
      }

      if (lower == 'admin') {
        return _isArabic ? 'مدير' : 'Administrator';
      }

      return role;
    }

    return _isArabic ? 'تدريسي' : 'Teacher';
  }

  String _getProfileImage() {
    return _readValue([
      'profileImage',
      'profileImageUrl',
      'photoURL',
      'photoUrl',
      'imageUrl',
      'image',
      'avatar',
    ]);
  }

  String _stageLabel(String stage) {
    final value = stage.trim().toLowerCase();

    if (value.contains('first') ||
        value.contains('الأولى') ||
        value.contains('اولى') ||
        value.contains('الأول')) {
      return _isArabic ? 'المرحلة الأولى' : 'First Stage';
    }

    if (value.contains('second') ||
        value.contains('الثانية') ||
        value.contains('ثانية') ||
        value.contains('الثاني')) {
      return _isArabic ? 'المرحلة الثانية' : 'Second Stage';
    }

    if (value.contains('third') ||
        value.contains('الثالثة') ||
        value.contains('ثالثة') ||
        value.contains('الثالث')) {
      return _isArabic ? 'المرحلة الثالثة' : 'Third Stage';
    }

    if (value.contains('fourth') ||
        value.contains('الرابعة') ||
        value.contains('رابعة') ||
        value.contains('الرابع')) {
      return _isArabic ? 'المرحلة الرابعة' : 'Fourth Stage';
    }

    return stage;
  }

  String _departmentLabel(String department) {
    if (department.trim().isEmpty) {
      return _isArabic ? 'غير محدد' : 'Not specified';
    }

    final value = department.trim().toLowerCase();

    if (value.contains('english') ||
        value.contains('إنكليزي') ||
        value.contains('انكليزي') ||
        value.contains('اللغة الإنكليزية') ||
        value.contains('لغة انكليزية')) {
      return _isArabic
          ? 'قسم اللغة الإنكليزية'
          : 'English Language Department';
    }

    if (value.contains('arabic') ||
        value.contains('العربية')) {
      return _isArabic
          ? 'قسم اللغة العربية'
          : 'Arabic Language Department';
    }

    if (value.contains('mathematics') ||
        value.contains('رياضيات')) {
      return _isArabic
          ? 'قسم الرياضيات'
          : 'Mathematics Department';
    }

    if (value.contains('computer') ||
        value.contains('حاسوب')) {
      return _isArabic
          ? 'قسم علوم الحاسوب'
          : 'Computer Science Department';
    }

    if (value.contains('science') ||
        value.contains('علوم')) {
      return _isArabic
          ? 'قسم العلوم'
          : 'Science Department';
    }

    if (value.contains('physical') ||
        value.contains('رياضة')) {
      return _isArabic
          ? 'قسم التربية البدنية'
          : 'Physical Education Department';
    }

    if (value.contains('education') ||
        value.contains('التربية') ||
        value.contains('كلية التربية')) {
      return _isArabic
          ? 'كلية التربية'
          : 'College of Education';
    }

    return department;
  }

  String _departmentOptionLabel(String department) {
    switch (department) {
      case 'English Language Department':
        return _isArabic
            ? 'قسم اللغة الإنكليزية'
            : 'English Language Department';

      case 'Arabic Language Department':
        return _isArabic
            ? 'قسم اللغة العربية'
            : 'Arabic Language Department';

      case 'Mathematics Department':
        return _isArabic
            ? 'قسم الرياضيات'
            : 'Mathematics Department';

      case 'Science Department':
        return _isArabic
            ? 'قسم العلوم'
            : 'Science Department';

      case 'Computer Science Department':
        return _isArabic
            ? 'قسم علوم الحاسوب'
            : 'Computer Science Department';

      case 'Physical Education Department':
        return _isArabic
            ? 'قسم التربية البدنية'
            : 'Physical Education Department';

      case 'Other':
        return _isArabic ? 'قسم آخر' : 'Other';

      default:
        return department;
    }
  }

  String _groupLabel(String group) {
    switch (group) {
      case 'A':
        return _isArabic ? 'القاعة A' : 'Hall A';

      case 'B':
        return _isArabic ? 'القاعة B' : 'Hall B';

      case 'C':
        return _isArabic ? 'القاعة C' : 'Hall C';

      case 'D':
        return _isArabic ? 'القاعة D' : 'Hall D';

      default:
        return group;
    }
  }

  String _safeValue(
      String value, {
        String? fallbackArabic,
        String? fallbackEnglish,
      }) {
    if (value.trim().isNotEmpty) {
      return value.trim();
    }

    return _isArabic
        ? (fallbackArabic ?? 'غير محدد')
        : (fallbackEnglish ?? 'Not specified');
  }

  Future<void> _pickAndUploadProfileImage() async {
    if (_isUploadingImage) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        _isUploadingImage = true;
      });

      final bytes = await image.readAsBytes();

      final collectionName =
      widget.isTeacher ? 'teachers' : 'students';

      final filePath =
          '$collectionName/${widget.user.uid}.jpg';

      final supabaseClient =
          supabase.Supabase.instance.client;

      await supabaseClient.storage
          .from('profile-images')
          .uploadBinary(
        filePath,
        bytes,
        fileOptions: const supabase.FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      final downloadUrl = supabaseClient.storage
          .from('profile-images')
          .getPublicUrl(filePath);

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.user.uid)
          .update({
        'profileImage': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.profile['profileImage'] = downloadUrl;

      if (!mounted) return;

      setState(() {
        _isUploadingImage = false;
      });

      _showMessage(
        _isArabic
            ? 'تم تحديث صورة الملف الشخصي'
            : 'Profile picture updated',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUploadingImage = false;
      });

      _showMessage(
        e.toString(),
        isError: true,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (widget.isTeacher || _isSaving) return;

    if (_departmentController.text.trim().isEmpty) {
      _showMessage(
        _isArabic
            ? 'يرجى اختيار القسم'
            : 'Please select a department',
        isError: true,
      );
      return;
    }

    if (_stageController.text.trim().isEmpty) {
      _showMessage(
        _isArabic
            ? 'يرجى اختيار المرحلة الدراسية'
            : 'Please select the academic stage',
        isError: true,
      );
      return;
    }

    final group =
    _normalizeGroup(_groupController.text);

    if (group.isEmpty) {
      _showMessage(
        _isArabic
            ? 'يرجى اختيار القاعة'
            : 'Please select a hall',
        isError: true,
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.user.uid)
          .update({
        'department': _departmentController.text.trim(),
        'stage': _stageController.text.trim(),
        'group': group,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _groupController.text = group;

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      _showMessage(
        _isArabic
            ? 'تم حفظ التغييرات بنجاح'
            : 'Changes saved successfully',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        _isArabic
            ? 'حدث خطأ أثناء الحفظ'
            : 'An error occurred while saving',
        isError: true,
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.of(context).popUntil(
          (route) => route.isFirst,
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection:
          _isArabic ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? _danger : _primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEDECF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: _softPurple,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              icon,
              color: iconColor ?? _primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value.isEmpty
                      ? (_isArabic
                      ? 'غير محدد'
                      : 'Not specified')
                      : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEDECF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        right: 4,
        bottom: 13,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _softPurple,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: _primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: _textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _textMuted,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(
        icon,
        color: _primary,
      ),
      filled: true,
      fillColor: const Color(0xFFF9F8FD),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.3,
        ),
      ),
    );
  }

  Widget _profileAvatar({
    required String profileImage,
  }) {
    return GestureDetector(
      onTap: _pickAndUploadProfileImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF2EEFF),
                  Color(0xFFE8E1FF),
                ],
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.13),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: profileImage.isNotEmpty
                ? Image.network(
              profileImage,
              width: 132,
              height: 132,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return Icon(
                  widget.isTeacher
                      ? Icons.school_rounded
                      : Icons.person_rounded,
                  color: _primary,
                  size: 60,
                );
              },
            )
                : Icon(
              widget.isTeacher
                  ? Icons.school_rounded
                  : Icons.person_rounded,
              color: _primary,
              size: 60,
            ),
          ),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _isUploadingImage
                ? const Padding(
              padding: EdgeInsets.all(9),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
                : const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _safeValue(
      _getName(),
      fallbackArabic:
      widget.isTeacher ? 'التدريسي' : 'الطالب',
      fallbackEnglish:
      widget.isTeacher ? 'Teacher' : 'Student',
    );

    final email = _safeValue(
      _getEmail(),
      fallbackArabic: 'لا يوجد بريد إلكتروني',
      fallbackEnglish: 'No email',
    );

    final department = _getDepartment();
    final specialization = _getSpecialization();
    final teacherRole = _getTeacherRole();

    final stage = _stageController.text.trim();
    final group = _normalizeGroup(
      _groupController.text,
    );
    final profileImage = _getProfileImage();

    final selectedDepartment =
    _departments.contains(_departmentController.text)
        ? _departmentController.text
        : null;

    final selectedStage =
    _stages.contains(_stageController.text)
        ? _stageController.text
        : null;

    final selectedGroup =
    _groups.contains(group)
        ? group
        : null;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(
            left: 12,
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            icon: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.04,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textDark,
              ),
            ),
          ),
        ),
        title: Text(
          _isArabic ? 'الملف الشخصي' : 'Profile',
          style: const TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _isArabic = !_isArabic;
                });
              },
              padding: EdgeInsets.zero,
              icon: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.04,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: _primary,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection:
        _isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            40,
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  28,
                  20,
                  24,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFBFAFF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: const Color(0xFFEDEAF9),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.035,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _profileAvatar(
                      profileImage: profileImage,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _softPurple,
                        borderRadius:
                        BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isTeacher
                                ? Icons.school_rounded
                                : Icons.person_rounded,
                            size: 16,
                            color: _primary,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            widget.isTeacher
                                ? teacherRole
                                : (_isArabic
                                ? 'طالب'
                                : 'Student'),
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 15,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isArabic
                              ? 'اضغط على الصورة لتغييرها'
                              : 'Tap the picture to change it',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (!widget.isTeacher)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                      if (_isEditing) {
                        _saveProfile();
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      _primary.withValues(alpha: 0.55),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 23,
                      height: 23,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditing
                              ? Icons
                              .check_circle_rounded
                              : Icons.edit_rounded,
                          size: 21,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          _isEditing
                              ? (_isArabic
                              ? 'حفظ التغييرات'
                              : 'Save Changes')
                              : (_isArabic
                              ? 'تعديل الملف'
                              : 'Edit Profile'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!widget.isTeacher)
                const SizedBox(height: 25),

              _sectionHeader(
                title: _isArabic
                    ? 'المعلومات الشخصية'
                    : 'Personal Information',
                icon: Icons.person_outline_rounded,
              ),

              _infoCard(
                icon: Icons.email_rounded,
                title: _isArabic
                    ? 'البريد الإلكتروني'
                    : 'Email',
                value: email,
              ),

              if (!widget.isTeacher && _isEditing)
                _editCard(
                  child:
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepartment,
                    isExpanded: true,
                    decoration: _fieldDecoration(
                      label: _isArabic
                          ? 'القسم'
                          : 'Department',
                      icon: Icons.apartment_rounded,
                    ),
                    hint: Text(
                      _isArabic
                          ? 'اختر القسم'
                          : 'Select department',
                    ),
                    items: _departments.map((department) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(
                          _departmentOptionLabel(
                            department,
                          ),
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _departmentController.text =
                            value;
                      });
                    },
                  ),
                )
              else
                _infoCard(
                  icon: Icons.apartment_rounded,
                  title: _isArabic
                      ? 'القسم'
                      : 'Department',
                  value: _departmentLabel(department),
                ),

              if (!widget.isTeacher) ...[
                if (_isEditing)
                  _editCard(
                    child:
                    DropdownButtonFormField<String>(
                      initialValue: selectedStage,
                      isExpanded: true,
                      decoration: _fieldDecoration(
                        label: _isArabic
                            ? 'المرحلة الدراسية'
                            : 'Academic Stage',
                        icon: Icons.school_rounded,
                      ),
                      hint: Text(
                        _isArabic
                            ? 'اختر المرحلة'
                            : 'Select stage',
                      ),
                      items: _stages.map((stage) {
                        return DropdownMenuItem<String>(
                          value: stage,
                          child: Text(
                            _stageLabel(stage),
                            style: const TextStyle(
                              color: _textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _stageController.text = value;
                        });
                      },
                    ),
                  )
                else
                  _infoCard(
                    icon: Icons.school_rounded,
                    title: _isArabic
                        ? 'المرحلة الدراسية'
                        : 'Academic Stage',
                    value: _safeValue(
                      _stageLabel(stage),
                    ),
                  ),

                if (_isEditing)
                  _editCard(
                    child:
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroup,
                      isExpanded: true,
                      decoration: _fieldDecoration(
                        label: _isArabic
                            ? 'تغيير القاعة'
                            : 'Change Hall',
                        icon: Icons.meeting_room_rounded,
                      ),
                      hint: Text(
                        _isArabic
                            ? 'اختر القاعة'
                            : 'Select hall',
                      ),
                      items: _groups.map((group) {
                        return DropdownMenuItem<String>(
                          value: group,
                          child: Text(
                            _groupLabel(group),
                            style: const TextStyle(
                              color: _textDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _groupController.text =
                              value;
                        });
                      },
                    ),
                  )
                else
                  _infoCard(
                    icon: Icons.meeting_room_rounded,
                    title: _isArabic
                        ? 'القاعة'
                        : 'Hall',
                    value: group.isEmpty
                        ? (_isArabic
                        ? 'غير محددة'
                        : 'Not specified')
                        : _groupLabel(group),
                  ),
              ],

              if (widget.isTeacher) ...[
                _infoCard(
                  icon: Icons.badge_rounded,
                  title: _isArabic
                      ? 'الصفة'
                      : 'Position',
                  value: teacherRole,
                ),
                _infoCard(
                  icon: Icons.workspace_premium_rounded,
                  title: _isArabic
                      ? 'التخصص'
                      : 'Specialization',
                  value: _safeValue(specialization),
                ),
              ],

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFFFFF7F7),
                    foregroundColor: _danger,
                    side: const BorderSide(
                      color: Color(0xFFFFDADA),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isArabic
                            ? 'تسجيل الخروج'
                            : 'Sign Out',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}