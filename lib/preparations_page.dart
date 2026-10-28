import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'language_controller.dart';
import 'admin_page.dart';

class PreparationsPage extends StatelessWidget {
  const PreparationsPage({
    super.key,
  });

  static const Color primary = Color(0xFF6C4CF1);
  static const Color primaryDark = Color(0xFF5132C8);
  static const Color background = Color(0xFFF7F7FB);
  static const Color textDark = Color(0xFF181625);
  static const Color textMuted = Color(0xFF777487);

  IconData _getIcon(String subject) {
    switch (subject) {
      case 'الشعر':
        return Icons.menu_book_rounded;
      case 'المحادثة':
        return Icons.record_voice_over_rounded;
      case 'الإرشاد':
        return Icons.psychology_rounded;
      case 'عقائد':
        return Icons.auto_stories_rounded;
      case 'طرائق التدريس':
        return Icons.school_rounded;
      case 'المسرحية':
        return Icons.theater_comedy_rounded;
      case 'علم اللغة':
        return Icons.language_rounded;
      case 'النحو':
        return Icons.spellcheck_rounded;
      case 'الكتابة الأكاديمية':
        return Icons.edit_note_rounded;
      case 'الرواية':
        return Icons.auto_stories_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Future<Map<String, dynamic>?> _getCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

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
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getCurrentProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: background,
            body: Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            ),
          );
        }

        final profile = profileSnapshot.data;

        if (profile == null) {
          return Scaffold(
            backgroundColor: background,
            body: Center(
              child: _EmptyState(
                icon: Icons.person_off_rounded,
                title: isArabic
                    ? 'معلومات الحساب غير متوفرة'
                    : 'Account information unavailable',
                subtitle: isArabic
                    ? 'يرجى التحقق من حسابك والمحاولة مرة أخرى.'
                    : 'Please check your account and try again.',
              ),
            ),
          );
        }

        final role = profile['role']?.toString() ?? '';
        final user = FirebaseAuth.instance.currentUser;

        final isTeacher = role == 'teacher';
        final teacherId = isTeacher ? user?.uid : null;

        final teacherName =
        isTeacher ? profile['name']?.toString() ?? '' : '';

        final teacherSubject = isTeacher
            ? profile['subject']?.toString() ??
            profile['specialization']?.toString() ??
            ''
            : '';

        return Scaffold(
          backgroundColor: background,

          appBar: AppBar(
            backgroundColor: background,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              isTeacher
                  ? (isArabic ? 'تحضيراتي' : 'My Preparations')
                  : (isArabic ? 'التحضيرات' : 'Preparations'),
              style: const TextStyle(
                color: textDark,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            centerTitle: true,
            actions: isTeacher
                ? [
                    IconButton(
                      tooltip: isArabic ? 'إدارة محاضراتي' : 'Manage my lectures',
                      icon: const Icon(Icons.edit_calendar_rounded, color: primary),
                      onPressed: () {
                        final department = profile['department']?.toString().trim() ?? '';
                        final stage = profile['stage']?.toString().trim() ?? '';
                        if (department.isEmpty || stage.isEmpty || teacherId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? 'بيانات القسم والمرحلة غير مكتملة في حساب التدريسي.'
                                    : 'Your teacher profile is missing department or stage.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScheduleAdminPage(
                              teacherMode: true,
                              teacherId: teacherId,
                              teacherName: teacherName,
                              department: department,
                              stage: stage,
                              teacherSubject: teacherSubject,
                            ),
                          ),
                        );
                      },
                    ),
                  ]
                : null,
          ),

          floatingActionButton: isTeacher
              ? Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.extended(
              backgroundColor: primary,
              elevation: 8,
              onPressed: () {
                _showAddPreparation(
                  context,
                  teacherId: teacherId!,
                  teacherName: teacherName,
                  teacherSubject: teacherSubject,
                  department: profile['department']?.toString().trim() ?? '',
                  stage: profile['stage']?.toString().trim() ?? '',
                );
              },
              icon: const Icon(
                Icons.add_rounded,
                color: Colors.white,
              ),
              label: Text(
                isArabic
                    ? 'إضافة تحضير'
                    : 'Add Preparation',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
              : null,

          body: StreamBuilder<QuerySnapshot>(
            stream: isTeacher && teacherId != null
                ? FirebaseFirestore.instance
                .collection('preparations')
                .where(
              'teacherId',
              isEqualTo: teacherId,
            )
                .snapshots()
                : FirebaseFirestore.instance
                .collection('preparations')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: primary,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: isTeacher
                      ? (isArabic
                      ? 'تعذر تحميل تحضيراتك'
                      : 'Unable to load your preparations')
                      : (isArabic
                      ? 'تعذر تحميل التحضيرات'
                      : 'Unable to load preparations'),
                  subtitle: isArabic
                      ? 'يرجى التحقق من اتصالك والمحاولة مرة أخرى.'
                      : 'Please check your connection and try again.',
                );
              }

              final documents = [...(snapshot.data?.docs ?? [])];

              documents.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aSubject =
                    aData['subject']?.toString() ?? '';
                final bSubject =
                    bData['subject']?.toString() ?? '';

                return aSubject.compareTo(bSubject);
              });

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  110,
                ),
                children: [
                  _HeroHeader(
                    isTeacher: isTeacher,
                    teacherSubject: teacherSubject,
                    preparationCount: documents.length,
                  ),

                  const SizedBox(height: 26),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTeacher
                              ? (isArabic
                              ? 'تحضيراتك'
                              : 'Your Preparations')
                              : (isArabic
                              ? 'المواد المتاحة'
                              : 'Available Subjects'),
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (documents.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE8FF),
                            borderRadius:
                            BorderRadius.circular(30),
                          ),
                          child: Text(
                            '${documents.length}',
                            style: const TextStyle(
                              color: primaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 13),

                  if (documents.isEmpty)
                    _EmptyPreparations(
                      isTeacher: isTeacher,
                    ),

                  ...documents.map((doc) {
                    final data =
                    doc.data() as Map<String, dynamic>;

                    final subject =
                        data['subject']?.toString() ?? '';

                    final professor =
                        data['professor']?.toString() ?? '';

                    final content =
                        data['content']?.toString() ?? '';

                    final documentTeacherId =
                        data['teacherId']?.toString() ?? '';

                    final canManage =
                        isTeacher &&
                            documentTeacherId == teacherId;

                    return _SubjectCard(
                      documentId: doc.id,
                      subject: subject,
                      professor: professor,
                      content: content,
                      icon: _getIcon(subject),
                      canManage: canManage,
                    );
                  }),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAddPreparation(
      BuildContext context, {
        required String teacherId,
        required String teacherName,
        required String teacherSubject,
        required String department,
        required String stage,
      }) async {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final subjectController =
    TextEditingController(text: teacherSubject);

    final contentController = TextEditingController();
    String selectedGroup = 'B';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom:
                MediaQuery.of(context).viewInsets.bottom +
                    20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      isArabic
                          ? 'تحضير جديد'
                          : 'New Preparation',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      isArabic
                          ? 'أنشئ تحضيراً جديداً لطلابك.'
                          : 'Create a new preparation for your students.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 24),

                    _ModernTextField(
                      controller: subjectController,
                      label: isArabic ? 'المادة' : 'Subject',
                      icon: Icons.menu_book_rounded,
                      readOnly: teacherSubject.isNotEmpty,
                    ),

                    const SizedBox(height: 14),

                    _ModernTextField(
                      controller: contentController,
                      label: isArabic
                          ? 'محتوى التحضير'
                          : 'Preparation Content',
                      icon: Icons.edit_note_rounded,
                      maxLines: 8,
                    ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: selectedGroup,
                      decoration: InputDecoration(
                        labelText: isArabic ? 'القاعة المستهدفة' : 'Target hall',
                        prefixIcon: const Icon(Icons.groups_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(value: 'A', child: Text(isArabic ? 'المجموعة A' : 'Group A')),
                        DropdownMenuItem(value: 'B', child: Text(isArabic ? 'المجموعة B' : 'Group B')),
                        DropdownMenuItem(value: 'C', child: Text(isArabic ? 'المجموعة C' : 'Group C')),
                        DropdownMenuItem(value: 'D', child: Text(isArabic ? 'المجموعة D' : 'Group D')),
                        DropdownMenuItem(value: 'ALL', child: Text(isArabic ? 'جميع المجموعات' : 'All groups')),
                      ],
                      onChanged: saving ? null : (value) {
                        if (value != null) setState(() => selectedGroup = value);
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                          final subject =
                          subjectController.text
                              .trim();

                          final content =
                          contentController.text
                              .trim();

                          if (subject.isEmpty ||
                              content.isEmpty ||
                              department.isEmpty ||
                              stage.isEmpty) {
                            ScaffoldMessenger.of(
                                context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabic
                                      ? 'يرجى إكمال جميع الحقول وبيانات القسم والمرحلة.'
                                      : 'Complete all fields and your teacher profile scope.',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            saving = true;
                          });

                          try {
                            await FirebaseFirestore
                                .instance
                                .collection(
                                'preparations')
                                .add({
                              'subject': subject,
                              'professor':
                              teacherName,
                              'content': content,
                              'teacherId':
                              teacherId,
                              'department': department,
                              'stage': stage,
                              'group': selectedGroup,
                              'audienceHalls': selectedGroup == 'ALL'
                                  ? ['A', 'B', 'C', 'D']
                                  : [selectedGroup],
                              'visibleToHalls': selectedGroup == 'ALL'
                                  ? ['A', 'B', 'C', 'D']
                                  : [selectedGroup],
                              'updatedAt':
                              FieldValue
                                  .serverTimestamp(),
                              'createdAt':
                              FieldValue
                                  .serverTimestamp(),
                            });

                            if (sheetContext.mounted) {
                              Navigator.pop(
                                  sheetContext);
                            }
                          } catch (e) {
                            setState(() {
                              saving = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                  context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArabic
                                        ? 'تعذر إضافة التحضير: $e'
                                        : 'Unable to add preparation: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: saving
                            ? const SizedBox(
                          width: 22,
                          height: 22,
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
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isArabic
                                  ? 'حفظ التحضير'
                                  : 'Save Preparation',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    subjectController.dispose();
    contentController.dispose();
  }
}

class _HeroHeader extends StatelessWidget {
  final bool isTeacher;
  final String teacherSubject;
  final int preparationCount;

  const _HeroHeader({
    required this.isTeacher,
    required this.teacherSubject,
    required this.preparationCount,
  });

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

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
            right: -25,
            top: -35,
            child: Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                color:
                Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 35,
            bottom: -55,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color:
                Colors.white.withValues(alpha: 0.06),
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withValues(alpha: 0.17),
                      borderRadius:
                      BorderRadius.circular(17),
                    ),
                    child: Icon(
                      isTeacher
                          ? Icons.edit_note_rounded
                          : Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withValues(alpha: 0.15),
                      borderRadius:
                      BorderRadius.circular(30),
                    ),
                    child: Text(
                      '$preparationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text(
                isTeacher
                    ? (isArabic
                    ? 'تحضيراتي'
                    : 'My Preparations')
                    : (isArabic
                    ? 'التحضيرات اليومية'
                    : 'Daily Preparations'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                isTeacher
                    ? teacherSubject.isEmpty
                    ? (isArabic
                    ? 'أدر تحضيراتك بسهولة'
                    : 'Manage your preparations easily')
                    : (isArabic
                    ? 'المادة: $teacherSubject'
                    : 'Subject: $teacherSubject')
                    : (isArabic
                    ? 'كل ما تحتاجه لدراستك اليومية'
                    : 'Everything you need for your daily study'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String documentId;
  final String subject;
  final String professor;
  final String content;
  final IconData icon;
  final bool canManage;

  const _SubjectCard({
    required this.documentId,
    required this.subject,
    required this.professor,
    required this.content,
    required this.icon,
    required this.canManage,
  });

  static const Color primary = Color(0xFF6C4CF1);

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PreparationDetailsPage(
                  subject: subject,
                  professor: professor,
                  content: content,
                  canManage: canManage,
                  documentId: documentId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFECE6FF),
                        Color(0xFFF4F1FF),
                      ],
                    ),
                    borderRadius:
                    BorderRadius.circular(18),
                  ),
                  child: Icon(
                    icon,
                    color: primary,
                    size: 27,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.isEmpty
                            ? (isArabic
                            ? 'مادة بدون عنوان'
                            : 'Untitled Subject')
                            : subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF181625),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: Color(0xFF8A8595),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              professor.isEmpty
                                  ? (isArabic
                                  ? 'الأستاذ'
                                  : 'Professor')
                                  : professor,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF85808F),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                if (canManage)
                  _CardMenu(
                    onEdit: () =>
                        _editPreparation(context),
                    onDelete: () =>
                        _deletePreparation(context),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FA),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF777280),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editPreparation(
      BuildContext context) async {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final controller =
    TextEditingController(text: content);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom:
                MediaQuery.of(context).viewInsets.bottom +
                    20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      isArabic
                          ? 'تعديل التحضير'
                          : 'Edit Preparation',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF181625),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ModernTextField(
                      controller: controller,
                      label: isArabic
                          ? 'محتوى التحضير'
                          : 'Preparation Content',
                      icon: Icons.edit_note_rounded,
                      maxLines: 10,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF6C4CF1),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                          final newContent =
                          controller.text.trim();

                          if (newContent.isEmpty) {
                            return;
                          }

                          setState(() {
                            saving = true;
                          });

                          try {
                            await FirebaseFirestore
                                .instance
                                .collection(
                                'preparations')
                                .doc(documentId)
                                .update({
                              'content': newContent,
                              'updatedAt':
                              FieldValue
                                  .serverTimestamp(),
                            });

                            if (sheetContext.mounted) {
                              Navigator.pop(
                                  sheetContext);
                            }
                          } catch (e) {
                            setState(() {
                              saving = false;
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                  context)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isArabic
                                        ? 'تعذر تحديث التحضير: $e'
                                        : 'Unable to update preparation: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: saving
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : Text(
                          isArabic
                              ? 'حفظ التغييرات'
                              : 'Save Changes',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _deletePreparation(
      BuildContext context) async {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _ConfirmDialog(
          title: isArabic
              ? 'حذف التحضير'
              : 'Delete Preparation',
          message: isArabic
              ? 'هل أنت متأكد من أنك تريد حذف هذا التحضير؟'
              : 'Are you sure you want to delete this preparation?',
          confirmText: isArabic ? 'حذف' : 'Delete',
          isDestructive: true,
          onConfirm: () {
            Navigator.pop(dialogContext, true);
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('preparations')
          .doc(documentId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تم حذف التحضير.'
                  : 'Preparation deleted.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تعذر حذف التحضير: $e'
                  : 'Unable to delete preparation: $e',
            ),
          ),
        );
      }
    }
  }
}

class _PreparationDetailsPage extends StatelessWidget {
  final String subject;
  final String professor;
  final String content;
  final bool canManage;
  final String documentId;

  const _PreparationDetailsPage({
    required this.subject,
    required this.professor,
    required this.content,
    required this.canManage,
    required this.documentId,
  });

  static const Color primary = Color(0xFF6C4CF1);

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _AppBarIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF181625),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _CardMenu(
                onEdit: () => _editContent(context),
                onDelete: () => _deleteContent(context),
              ),
            ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          30,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
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
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color:
                    Colors.white.withValues(alpha: 0.15),
                    borderRadius:
                    BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  subject,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Colors.white70,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        professor.isEmpty
                            ? (isArabic
                            ? 'الأستاذ'
                            : 'Professor')
                            : professor,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE8FF),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isArabic ? 'التحضير' : 'Preparation',
                style: const TextStyle(
                  color: Color(0xFF181625),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black.withValues(alpha: 0.045),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Text(
              content.isEmpty
                  ? (isArabic
                  ? 'لم تتم إضافة التحضير بعد.'
                  : 'The preparation has not been added yet.')
                  : content,
              style: const TextStyle(
                color: Color(0xFF3E3A48),
                fontSize: 16,
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editContent(
      BuildContext context) async {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final controller =
    TextEditingController(text: content);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom:
            MediaQuery.of(context).viewInsets.bottom +
                20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  isArabic
                      ? 'تعديل التحضير'
                      : 'Edit Preparation',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF181625),
                  ),
                ),
                const SizedBox(height: 20),
                _ModernTextField(
                  controller: controller,
                  label: isArabic
                      ? 'محتوى التحضير'
                      : 'Preparation Content',
                  icon: Icons.edit_note_rounded,
                  maxLines: 10,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF6C4CF1),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () async {
                      final newContent =
                      controller.text.trim();

                      if (newContent.isEmpty) return;

                      try {
                        await FirebaseFirestore.instance
                            .collection('preparations')
                            .doc(documentId)
                            .update({
                          'content': newContent,
                          'updatedAt':
                          FieldValue.serverTimestamp(),
                        });

                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic
                                    ? 'تعذر تحديث التحضير: $e'
                                    : 'Unable to update preparation: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      isArabic
                          ? 'حفظ التغييرات'
                          : 'Save Changes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                        FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    controller.dispose();
  }

  Future<void> _deleteContent(
      BuildContext context) async {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _ConfirmDialog(
          title: isArabic
              ? 'حذف التحضير'
              : 'Delete Preparation',
          message: isArabic
              ? 'هل أنت متأكد من أنك تريد حذف هذا التحضير؟'
              : 'Are you sure you want to delete this preparation?',
          confirmText: isArabic ? 'حذف' : 'Delete',
          isDestructive: true,
          onConfirm: () {
            Navigator.pop(dialogContext, true);
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('preparations')
          .doc(documentId)
          .delete();

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'تعذر حذف التحضير: $e'
                  : 'Unable to delete preparation: $e',
            ),
          ),
        );
      }
    }
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final bool readOnly;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF181625),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF85808F),
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            bottom: maxLines > 1 ? 110 : 0,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF6C4CF1),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF7F6FA),
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
            color: Color(0xFF6C4CF1),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CardMenu({
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF6D6878),
        ),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(
                Icons.edit_rounded,
                color: Color(0xFF6C4CF1),
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'تعديل' : 'Edit',
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
              ),
              const SizedBox(width: 10),
              Text(
                isArabic ? 'حذف' : 'Delete',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AppBarIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF252130),
          ),
        ),
      ),
    );
  }
}

class _EmptyPreparations extends StatelessWidget {
  final bool isTeacher;

  const _EmptyPreparations({
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 45,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE8FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isTeacher
                  ? Icons.note_add_rounded
                  : Icons.menu_book_rounded,
              size: 36,
              color: const Color(0xFF6C4CF1),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isTeacher
                ? (isArabic
                ? 'لا توجد تحضيرات بعد'
                : 'No preparations yet')
                : (isArabic
                ? 'لا توجد تحضيرات متاحة'
                : 'No preparations available'),
            style: const TextStyle(
              color: Color(0xFF181625),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isTeacher
                ? (isArabic
                ? 'اضغط على زر + لإنشاء أول تحضير لك.'
                : 'Tap the + button to create your first preparation.')
                : (isArabic
                ? 'ستظهر التحضيرات هنا عند إضافتها.'
                : 'Preparations will appear here when they are added.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF85808F),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE8FF),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                size: 38,
                color: const Color(0xFF6C4CF1),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF181625),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF85808F),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.isDestructive,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF181625),
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF777280),
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: const TextStyle(
              color: Color(0xFF777280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive
                ? Colors.red
                : const Color(0xFF6C4CF1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          onPressed: onConfirm,
          child: Text(confirmText),
        ),
      ],
    );
  }
}