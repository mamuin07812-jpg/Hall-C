import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

const Color _primary = Color(0xFF6C4CF1);
const Color _primaryDark = Color(0xFF5132C8);
const Color _background = Color(0xFFF7F7FB);
const Color _textDark = Color(0xFF181625);
const Color _textMuted = Color(0xFF777487);
const Color _softPurple = Color(0xFFF0ECFF);
const Color _danger = Color(0xFFE5484D);

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _background,
        foregroundColor: _textDark,
        title: const Text(
          'لوحة الإدارة',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          child: Column(
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: 18),
              _buildAdminOption(
                context,
                icon: Icons.calendar_month_rounded,
                title: 'الجدول الدراسي',
                subtitle: 'إضافة وتعديل وحذف المحاضرات',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScheduleAdminPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAdminOption(
                context,
                icon: Icons.menu_book_rounded,
                title: 'التحضيرات',
                subtitle: 'إدارة تحضيرات المواد الدراسية',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PreparationsAdminPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAdminOption(
                context,
                icon: Icons.system_update_rounded,
                title: 'تحديث التطبيق',
                subtitle: 'رفع نسخة جديدة للتطبيق',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AppUpdateAdminPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAdminOption(
                context,
                icon: Icons.campaign_rounded,
                title: 'الإعلانات',
                subtitle: 'إدارة الإعلانات والتنبيهات',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsAdminPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildAdminOption(
                context,
                icon: Icons.people_alt_rounded,
                title: 'الطلاب',
                subtitle: 'إدارة حسابات الطلاب',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentsAdminPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildAdminStatusCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(height: 18),
          Text(
            'مرحباً بك في لوحة الإدارة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'من هنا يمكنك إدارة محتوى التطبيق والجدول الدراسي والتحضيرات.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminOption(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        VoidCallback? onTap,
        bool comingSoon = false,
      }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: comingSoon ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEAE7F2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _softPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: _primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (comingSoon)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F0F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'قريباً',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: _textMuted,
                  size: 17,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE7F2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF35B66B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حالة الإدارة',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'وضع الإدارة فعال',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF35B66B),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ANNOUNCEMENTS ADMIN
// ============================================================

class AnnouncementsAdminPage extends StatefulWidget {
  const AnnouncementsAdminPage({super.key});

  @override
  State<AnnouncementsAdminPage> createState() =>
      _AnnouncementsAdminPageState();
}

class _AnnouncementsAdminPageState
    extends State<AnnouncementsAdminPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> _showAnnouncementDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data();

    final titleController = TextEditingController(
      text: data?['title']?.toString() ?? '',
    );

    final contentController = TextEditingController(
      text: data?['content']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    bool isActive = data?['isActive'] != false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text(
                document == null
                    ? 'إضافة إعلان'
                    : 'تعديل الإعلان',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        textDirection: TextDirection.rtl,
                        decoration: _inputDecoration(
                          'عنوان الإعلان',
                          Icons.title_rounded,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل عنوان الإعلان';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contentController,
                        textDirection: TextDirection.rtl,
                        minLines: 5,
                        maxLines: 10,
                        decoration: _inputDecoration(
                          'محتوى الإعلان',
                          Icons.description_rounded,
                        ).copyWith(
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل محتوى الإعلان';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        activeThumbColor: _primary,
                        onChanged: saving
                            ? null
                            : (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                        title: const Text(
                          'الإعلان فعال',
                          style: TextStyle(
                            color: _textDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          'يظهر الإعلان للمستخدمين عند تفعيله',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 12,
                          ),
                        ),
                        secondary: Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: _softPurple,
                            borderRadius:
                            BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    if (!formKey.currentState!
                        .validate()) {
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    try {
                      final payload = {
                        'title':
                        titleController.text.trim(),
                        'content':
                        contentController.text.trim(),
                        'isActive': isActive,
                        'updatedAt':
                        FieldValue.serverTimestamp(),
                      };

                      if (document == null) {
                        await _firestore
                            .collection('announcements')
                            .add({
                          ...payload,
                          'createdAt':
                          FieldValue.serverTimestamp(),
                        });
                      } else {
                        await document.reference
                            .update(payload);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (e) {
                      setDialogState(() {
                        saving = false;
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'حدث خطأ أثناء حفظ الإعلان: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    document == null ? 'إضافة' : 'حفظ',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> _deleteAnnouncement(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data();

    final title = data?['title']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'حذف الإعلان',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            title.isEmpty
                ? 'هل أنت متأكد من حذف هذا الإعلان؟'
                : 'هل تريد حذف الإعلان "$title"؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await document.reference.delete();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء حذف الإعلان: $e',
          ),
        ),
      );
    }
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      final day =
      date.day.toString().padLeft(2, '0');
      final month =
      date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour =
      date.hour.toString().padLeft(2, '0');
      final minute =
      date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year - $hour:$minute';
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text(
          'إدارة الإعلانات',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAnnouncementDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'إضافة إعلان',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('announcements')
            .orderBy(
          'createdAt',
          descending: true,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  'حدث خطأ في تحميل الإعلانات\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textMuted,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _primary,
              ),
            );
          }

          final documents =
              snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: _primary,
                      size: 55,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'لا توجد إعلانات حالياً',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'اضغط على زر إضافة إعلان لإنشاء أول إعلان.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            itemCount: documents.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data();

              final title =
                  data['title']?.toString() ?? '';
              final content =
                  data['content']?.toString() ?? '';
              final isActive =
                  data['isActive'] != false;

              final date =
              _formatDate(data['createdAt']);

              return Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFEAE7F2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _softPurple,
                        borderRadius:
                        BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: _primary,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style:
                                  const TextStyle(
                                    color: _textDark,
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: isActive
                                      ? const Color(
                                    0xFFEAF8F0,
                                  )
                                      : const Color(
                                    0xFFF1F0F5,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(
                                    8,
                                  ),
                                ),
                                child: Text(
                                  isActive
                                      ? 'فعال'
                                      : 'متوقف',
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(
                                      0xFF35B66B,
                                    )
                                        : _textMuted,
                                    fontSize: 10,
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            content,
                            maxLines: 4,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textMuted,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                          if (date.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .access_time_rounded,
                                  size: 14,
                                  color: _textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  date,
                                  style:
                                  const TextStyle(
                                    color: _textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAnnouncementDialog(
                            document: document,
                          );
                        } else if (value == 'delete') {
                          _deleteAnnouncement(
                            document,
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .delete_outline_rounded,
                                color: _danger,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('حذف'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// STUDENTS ADMIN
// ============================================================

class StudentsAdminPage extends StatefulWidget {
  const StudentsAdminPage({super.key});

  @override
  State<StudentsAdminPage> createState() =>
      _StudentsAdminPageState();
}

class _StudentsAdminPageState
    extends State<StudentsAdminPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _studentName(
      Map<String, dynamic> data,
      ) {
    final name =
        data['name']?.toString().trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    final displayName =
        data['displayName']?.toString().trim() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email =
        data['email']?.toString().trim() ?? '';

    if (email.isNotEmpty) {
      return email;
    }

    return 'طالب بدون اسم';
  }

  String _studentEmail(
      Map<String, dynamic> data,
      ) {
    return data['email']?.toString().trim() ?? '';
  }

  bool _matchesSearch(
      Map<String, dynamic> data,
      ) {
    if (_searchQuery.isEmpty) {
      return true;
    }

    final name =
    _studentName(data).toLowerCase();

    final email =
    _studentEmail(data).toLowerCase();

    final stage =
        data['stage']?.toString().toLowerCase() ?? '';

    final group =
        data['group']?.toString().toLowerCase() ?? '';

    return name.contains(_searchQuery) ||
        email.contains(_searchQuery) ||
        stage.contains(_searchQuery) ||
        group.contains(_searchQuery);
  }

  Future<void> _showStudentDialog(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data() ?? {};

    String selectedStage =
        data['stage']?.toString() ?? '';

    String selectedGroup =
        data['group']?.toString() ?? '';

    final stages = const [
      'المرحلة الأولى',
      'المرحلة الثانية',
      'المرحلة الثالثة',
      'المرحلة الرابعة',
    ];

    final groups = const [
      'A',
      'B',
      'C',
      'D',
    ];

    if (!stages.contains(selectedStage)) {
      selectedStage = '';
    }

    if (!groups.contains(selectedGroup)) {
      selectedGroup = '';
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'تعديل بيانات الطالب',
                style: TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _softPurple,
                        borderRadius:
                        BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _studentName(data),
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textDark,
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),
                                if (_studentEmail(data)
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _studentEmail(data),
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedStage.isEmpty
                          ? null
                          : selectedStage,
                      decoration: _inputDecoration(
                        'المرحلة',
                        Icons.school_rounded,
                      ),
                      items: stages
                          .map(
                            (stage) =>
                            DropdownMenuItem<String>(
                              value: stage,
                              child: Text(stage),
                            ),
                      )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                        setDialogState(() {
                          selectedStage =
                              value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGroup.isEmpty
                          ? null
                          : selectedGroup,
                      decoration: _inputDecoration(
                        'المجموعة',
                        Icons.groups_rounded,
                      ),
                      items: groups
                          .map(
                            (group) =>
                            DropdownMenuItem<String>(
                              value: group,
                              child: Text(
                                'المجموعة $group',
                              ),
                            ),
                      )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                        setDialogState(() {
                          selectedGroup =
                              value ?? '';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () =>
                      Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    if (selectedStage.isEmpty ||
                        selectedGroup.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'اختر المرحلة والمجموعة',
                          ),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    try {
                      await document.reference
                          .update({
                        'stage': selectedStage,
                        'group': selectedGroup,
                        'profileCompleted': true,
                        'updatedAt':
                        FieldValue.serverTimestamp(),
                      });

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (e) {
                      setDialogState(() {
                        saving = false;
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'حدث خطأ أثناء حفظ بيانات الطالب: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data() ?? {};

    final name = _studentName(data);
    final email = _studentEmail(data);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'حذف بيانات الطالب',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            email.isEmpty
                ? 'هل تريد حذف بيانات الطالب "$name" من قاعدة البيانات؟'
                : 'هل تريد حذف بيانات الطالب "$name"؟\n\n$email\n\nسيتم حذف سجل الطالب من Firestore فقط، ولن يتم حذف حساب تسجيل الدخول.',
            style: const TextStyle(
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await document.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF35B66B),
          content: Text(
            'تم حذف بيانات الطالب بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء حذف بيانات الطالب: $e',
          ),
        ),
      );
    }
  }

  Widget _buildStudentCard(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data() ?? {};

    final name = _studentName(data);
    final email = _studentEmail(data);

    final stage =
        data['stage']?.toString().trim() ?? '';

    final group =
        data['group']?.toString().trim() ?? '';

    final profileCompleted =
        data['profileCompleted'] == true;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEAE7F2),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _softPurple,
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: _primary,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (stage.isNotEmpty)
                      _buildStudentInfoChip(
                        Icons.school_rounded,
                        stage,
                      ),
                    if (group.isNotEmpty)
                      _buildStudentInfoChip(
                        Icons.groups_rounded,
                        'المجموعة $group',
                      ),
                    _buildStudentStatusChip(
                      profileCompleted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showStudentDialog(document);
              } else if (value == 'delete') {
                _deleteStudent(document);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_rounded,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: _danger,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('حذف البيانات'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: _primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentStatusChip(
      bool completed,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFFEAF8F0)
            : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            size: 13,
            color: completed
                ? const Color(0xFF35B66B)
                : const Color(0xFFE49A2F),
          ),
          const SizedBox(width: 4),
          Text(
            completed
                ? 'مكتمل'
                : 'غير مكتمل',
            style: TextStyle(
              color: completed
                  ? const Color(0xFF35B66B)
                  : const Color(0xFFE49A2F),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        4,
      ),
      child: TextField(
        controller: _searchController,
        textDirection: TextDirection.rtl,
        decoration: _inputDecoration(
          'البحث عن طالب',
          Icons.search_rounded,
        ).copyWith(
          hintText:
          'الاسم أو الإيميل أو المرحلة أو المجموعة',
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(
              Icons.clear_rounded,
              color: _textMuted,
            ),
          )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text(
          'إدارة الطلاب',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchField(),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('students')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(25),
                      child: Text(
                        'حدث خطأ في تحميل الطلاب\n${snapshot.error}',
                        textAlign:
                        TextAlign.center,
                        style: const TextStyle(
                          color: _textMuted,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _primary,
                    ),
                  );
                }

                final allDocuments =
                    snapshot.data?.docs ?? [];

                final documents =
                allDocuments.where((document) {
                  return _matchesSearch(
                    document.data(),
                  );
                }).toList();

                if (allDocuments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                      EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            color: _primary,
                            size: 58,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'لا توجد حسابات طلاب',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 16,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'ستظهر حسابات الطلاب هنا بعد تسجيلهم في التطبيق.',
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (documents.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding:
                      EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: _primary,
                            size: 55,
                          ),
                          SizedBox(height: 15),
                          Text(
                            'لا توجد نتائج',
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 16,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'جرّب البحث باسم أو إيميل مختلف.',
                            textAlign:
                            TextAlign.center,
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: _primary,
                  onRefresh: () async {
                    await _firestore
                        .collection('students')
                        .get();
                  },
                  child: ListView.separated(
                    padding:
                    const EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      30,
                    ),
                    itemCount:
                    documents.length,
                    separatorBuilder:
                        (_, __) =>
                    const SizedBox(
                      height: 10,
                    ),
                    itemBuilder:
                        (context, index) {
                      return _buildStudentCard(
                        documents[index],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// APP UPDATE ADMIN
// ============================================================

class AppUpdateAdminPage extends StatefulWidget {
  const AppUpdateAdminPage({super.key});

  @override
  State<AppUpdateAdminPage> createState() =>
      _AppUpdateAdminPageState();
}

class _AppUpdateAdminPageState
    extends State<AppUpdateAdminPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final _formKey = GlobalKey<FormState>();

  final _versionCodeController =
  TextEditingController();

  final _versionNameController =
  TextEditingController();

  final _notesController =
  TextEditingController();

  bool _forceUpdate = false;
  bool _loading = true;
  bool _uploading = false;

  String? _selectedFileName;
  String? _selectedFilePath;

  String _currentVersionName = 'لا توجد نسخة';
  int _currentVersionCode = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUpdate();
  }

  @override
  void dispose() {
    _versionCodeController.dispose();
    _versionNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUpdate() async {
    try {
      final document = await _firestore
          .collection('app_updates')
          .doc('current')
          .get();

      if (document.exists) {
        final data = document.data();

        if (data != null) {
          _currentVersionName =
              data['versionName']?.toString() ??
                  'لا توجد نسخة';

          _currentVersionCode =
              _readInt(data['versionCode']);

          _versionNameController.text =
              data['versionName']?.toString() ?? '';

          _versionCodeController.text =
          _currentVersionCode > 0
              ? _currentVersionCode.toString()
              : '';

          _notesController.text =
              data['notes']?.toString() ?? '';

          _forceUpdate =
              data['forceUpdate'] == true;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تحميل معلومات التحديث: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickApk() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk'],
      );

      if (files.isEmpty) return;

      final file = files.first;

      final path = file.path;

      if (path == null || path.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر الوصول إلى ملف APK',
            ),
          ),
        );

        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _selectedFilePath = path;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء اختيار الملف: $e',
          ),
        ),
      );
    }
  }

  Future<void> _uploadUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFilePath == null ||
        _selectedFilePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اختر ملف APK أولاً',
          ),
        ),
      );

      return;
    }

    final versionCode =
    int.tryParse(
      _versionCodeController.text.trim(),
    );

    if (versionCode == null || versionCode <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'رقم الإصدار غير صحيح',
          ),
        ),
      );

      return;
    }

    if (versionCode <= _currentVersionCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'رقم الإصدار الجديد يجب أن يكون أكبر من الإصدار الحالي ($_currentVersionCode)',
          ),
        ),
      );

      return;
    }

    final apkFile = File(_selectedFilePath!);

    if (!await apkFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ملف APK غير موجود في المسار المحدد',
          ),
        ),
      );

      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final storagePath =
          'app_updates/app-release-$versionCode.apk';

      final storageReference =
      _storage.ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType:
        'application/vnd.android.package-archive',
      );

      await storageReference.putFile(
        apkFile,
        metadata,
      );

      final apkUrl =
      await storageReference.getDownloadURL();

      await _firestore
          .collection('app_updates')
          .doc('current')
          .set(
        {
          'versionCode': versionCode,
          'versionName':
          _versionNameController.text.trim(),
          'apkUrl': apkUrl,
          'forceUpdate': _forceUpdate,
          'notes': _notesController.text.trim(),
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _currentVersionCode = versionCode;
        _currentVersionName =
            _versionNameController.text.trim();
        _selectedFileName = null;
        _selectedFilePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF35B66B),
          content: Text(
            'تم رفع التحديث ونشره بنجاح',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء رفع التحديث:\n$e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text(
          'تحديث التطبيق',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: _primary,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          30,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCurrentVersionCard(),
              const SizedBox(height: 16),
              _buildVersionFields(),
              const SizedBox(height: 14),
              _buildNotesField(),
              const SizedBox(height: 14),
              _buildForceUpdateCard(),
              const SizedBox(height: 14),
              _buildApkPicker(),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                  _uploading
                      ? null
                      : _uploadUpdate,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor:
                    Colors.white,
                    disabledBackgroundColor:
                    _primary.withValues(
                      alpha: 0.45,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  icon: _uploading
                      ? const SizedBox(
                    width: 21,
                    height: 21,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .cloud_upload_rounded,
                  ),
                  label: Text(
                    _uploading
                        ? 'جاري رفع التحديث...'
                        : 'رفع ونشر التحديث',
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentVersionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
              BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'الإصدار المنشور حالياً',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentVersionName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version Code: $_currentVersionCode',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFields() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          TextFormField(
            controller: _versionCodeController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration(
              'رقم الإصدار',
              Icons.numbers_rounded,
            ).copyWith(
              hintText: 'مثال: 2',
            ),
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'أدخل رقم الإصدار';
              }

              final number =
              int.tryParse(value.trim());

              if (number == null ||
                  number <= 0) {
                return 'أدخل رقم صحيح';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _versionNameController,
            decoration: _inputDecoration(
              'اسم الإصدار',
              Icons.sell_rounded,
            ).copyWith(
              hintText: 'مثال: 1.0.1',
            ),
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'أدخل اسم الإصدار';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _cardDecoration(),
      child: TextFormField(
        controller: _notesController,
        minLines: 4,
        maxLines: 8,
        textDirection: TextDirection.rtl,
        decoration: _inputDecoration(
          'ملاحظات التحديث',
          Icons.notes_rounded,
        ).copyWith(
          hintText:
          'مثال: تحسين الأداء وإصلاح بعض المشاكل...',
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildForceUpdateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 13,
      ),
      decoration: _cardDecoration(),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _forceUpdate,
        activeThumbColor: _primary,
        onChanged: _uploading
            ? null
            : (value) {
          setState(() {
            _forceUpdate = value;
          });
        },
        title: const Text(
          'تحديث إجباري',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'يطلب من الطالب تحديث التطبيق قبل المتابعة',
          style: TextStyle(
            color: _textMuted,
            fontSize: 12,
          ),
        ),
        secondary: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: _softPurple,
            borderRadius:
            BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            color: _primary,
          ),
        ),
      ),
    );
  }

  Widget _buildApkPicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _uploading ? null : _pickApk,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          border: Border.all(
            color: _selectedFilePath != null
                ? _primary
                : const Color(0xFFEAE7F2),
            width:
            _selectedFilePath != null
                ? 1.5
                : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _softPurple,
                borderRadius:
                BorderRadius.circular(19),
              ),
              child: Icon(
                _selectedFilePath != null
                    ? Icons.check_circle_rounded
                    : Icons.android_rounded,
                color: _primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              _selectedFileName ??
                  'اختيار ملف APK',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _selectedFilePath != null
                  ? 'تم اختيار الملف، اضغط رفع ونشر التحديث'
                  : 'اختر ملف app-release.apk من جهازك',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFFEAE7F2),
      ),
    );
  }

  int _readInt(dynamic value) {
    if (value is int) return value;

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }
}

// ============================================================
// PREPARATIONS ADMIN
// ============================================================

class PreparationsAdminPage extends StatefulWidget {
  const PreparationsAdminPage({super.key});

  @override
  State<PreparationsAdminPage> createState() =>
      _PreparationsAdminPageState();
}

class _PreparationsAdminPageState
    extends State<PreparationsAdminPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> _showPreparationDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final data = document?.data();

    final subjectController =
    TextEditingController(
      text: data?['subject']?.toString() ?? '',
    );

    final professorController =
    TextEditingController(
      text: data?['professor']?.toString() ?? '',
    );

    final contentController =
    TextEditingController(
      text: data?['content']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(22),
              ),
              title: Text(
                document == null
                    ? 'إضافة تحضير'
                    : 'تعديل التحضير',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller:
                        subjectController,
                        decoration:
                        _inputDecoration(
                          'اسم المادة',
                          Icons.book_rounded,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل اسم المادة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                        professorController,
                        decoration:
                        _inputDecoration(
                          'اسم الأستاذ',
                          Icons.person_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller:
                        contentController,
                        minLines: 5,
                        maxLines: 10,
                        decoration:
                        _inputDecoration(
                          'محتوى التحضير',
                          Icons.description_rounded,
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل محتوى التحضير';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () =>
                      Navigator.pop(
                        dialogContext,
                      ),
                  child:
                  const Text('إلغاء'),
                ),
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor:
                    Colors.white,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    if (!formKey
                        .currentState!
                        .validate()) {
                      return;
                    }

                    setDialogState(() {
                      saving = true;
                    });

                    final subject =
                    subjectController
                        .text
                        .trim();

                    final payload = {
                      'subject':
                      subject,
                      'professor':
                      professorController
                          .text
                          .trim(),
                      'content':
                      contentController
                          .text
                          .trim(),
                      'updatedAt':
                      FieldValue
                          .serverTimestamp(),
                    };

                    try {
                      if (document == null) {
                        await _firestore
                            .collection(
                          'preparations',
                        )
                            .add(
                          payload,
                        );

                        // إشعار عند إضافة تحضير جديد فقط.
                        await _firestore
                            .collection(
                          'notifications',
                        )
                            .add({
                          'title':
                          'تحضير جديد 📚',
                          'body':
                          'تمت إضافة تحضير جديد لمادة $subject',
                          'type':
                          'preparation',
                          'target':
                          'all',
                          'subject':
                          subject,
                          'createdAt':
                          FieldValue
                              .serverTimestamp(),
                        });
                      } else {
                        await document
                            .reference
                            .update(
                          payload,
                        );
                      }

                      if (dialogContext
                          .mounted) {
                        Navigator.pop(
                          dialogContext,
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        saving = false;
                      });

                      if (context.mounted) {
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'حدث خطأ: $e',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    document == null
                        ? 'إضافة'
                        : 'حفظ',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePreparation(
      DocumentSnapshot<Map<String, dynamic>>
      document,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          title: const Text(
            'حذف التحضير',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'هل أنت متأكد من حذف هذا التحضير؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child:
              const Text('إلغاء'),
            ),
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor:
                Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await document.reference.delete();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء الحذف: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textDark,
        elevation: 0,
        title: const Text(
          'إدارة التحضيرات',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton:
      FloatingActionButton(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        onPressed:
            () => _showPreparationDialog(),
        child: const Icon(
          Icons.add_rounded,
        ),
      ),
      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream: _firestore
            .collection('preparations')
            .orderBy('subject')
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ في تحميل التحضيرات\n${snapshot.error}',
                textAlign:
                TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(
                color: _primary,
              ),
            );
          }

          final documents =
              snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد تحضيرات حالياً',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 15,
                ),
              ),
            );
          }

          return ListView.separated(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              90,
            ),
            itemCount:
            documents.length,
            separatorBuilder:
                (_, __) =>
            const SizedBox(
              height: 10,
            ),
            itemBuilder:
                (context, index) {
              final document =
              documents[index];
              final data =
              document.data();

              final subject =
                  data['subject']
                      ?.toString() ??
                      '';
              final professor =
                  data['professor']
                      ?.toString() ??
                      '';
              final content =
                  data['content']
                      ?.toString() ??
                      '';

              return Container(
                padding:
                const EdgeInsets.all(
                  17,
                ),
                decoration:
                BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                  BorderRadius
                      .circular(
                    20,
                  ),
                  border:
                  Border.all(
                    color:
                    const Color(
                      0xFFEAE7F2,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                      BoxDecoration(
                        color:
                        _softPurple,
                        borderRadius:
                        BorderRadius
                            .circular(
                          15,
                        ),
                      ),
                      child:
                      const Icon(
                        Icons
                            .menu_book_rounded,
                        color:
                        _primary,
                      ),
                    ),
                    const SizedBox(
                      width: 13,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            subject,
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight
                                  .w800,
                              color:
                              _textDark,
                              fontSize:
                              16,
                            ),
                          ),
                          if (professor
                              .isNotEmpty) ...[
                            const SizedBox(
                                height: 4),
                            Text(
                              professor,
                              style:
                              const TextStyle(
                                color:
                                _textMuted,
                                fontSize:
                                12,
                              ),
                            ),
                          ],
                          const SizedBox(
                              height: 7),
                          Text(
                            content,
                            maxLines: 3,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              color:
                              _textMuted,
                              height:
                              1.4,
                              fontSize:
                              13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<
                        String>(
                      onSelected:
                          (value) {
                        if (value ==
                            'edit') {
                          _showPreparationDialog(
                            document:
                            document,
                          );
                        } else if (value ==
                            'delete') {
                          _deletePreparation(
                            document,
                          );
                        }
                      },
                      itemBuilder:
                          (_) =>
                      const [
                        PopupMenuItem(
                          value:
                          'edit',
                          child:
                          Text(
                            'تعديل',
                          ),
                        ),
                        PopupMenuItem(
                          value:
                          'delete',
                          child:
                          Text(
                            'حذف',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// SCHEDULE ADMIN
// ============================================================

class ScheduleAdminPage extends StatefulWidget {
  final bool teacherMode;
  final String? teacherId;
  final String? teacherName;
  final String? department;
  final String? stage;
  final String? teacherSubject;

  const ScheduleAdminPage({
    super.key,
    this.teacherMode = false,
    this.teacherId,
    this.teacherName,
    this.department,
    this.stage,
    this.teacherSubject,
  });

  @override
  State<ScheduleAdminPage> createState() =>
      _ScheduleAdminPageState();
}

class _ScheduleAdminPageState
    extends State<ScheduleAdminPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final List<String> _days = const [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
  ];

  final Map<String, String> _dayEnglish =
  const {
    'الأحد': 'Sunday',
    'الاثنين': 'Monday',
    'الثلاثاء': 'Tuesday',
    'الأربعاء': 'Wednesday',
  };

  String _selectedDay = 'الأحد';

  List<_AdminLecture> _lectures = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _loading = true;
    });

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('schedules')
          .where('dayAr', isEqualTo: _selectedDay);
      if (widget.teacherMode) {
        query = query.where('teacherId', isEqualTo: widget.teacherId);
      }
      final snapshot = await query.get();

      final newDocuments = <
          DocumentSnapshot<
              Map<String, dynamic>>>[];

      final legacyDocuments = <
          DocumentSnapshot<
              Map<String, dynamic>>>[];

      for (final document
      in snapshot.docs) {
        final data =
        document.data();

        if (data['lectures']
        is List) {
          legacyDocuments
              .add(document);
        } else {
          newDocuments
              .add(document);
        }
      }

      if (newDocuments.isEmpty &&
          legacyDocuments
              .isNotEmpty) {
        await _migrateLegacyDay(
          legacyDocuments.first,
        );

        final refreshed =
        await _firestore
            .collection(
          'schedules',
        )
            .where(
          'dayAr',
          isEqualTo:
          _selectedDay,
        )
            .get();

        _lectures =
            refreshed.docs
                .where(
                  (doc) =>
              doc.data()[
              'lectures'] is!
              List,
            )
                .map(
                  (doc) =>
                  _AdminLecture
                      .fromDocument(
                    doc,
                  ),
            )
                .toList();
      } else {
        _lectures =
            newDocuments
                .map(
                  (doc) =>
                  _AdminLecture
                      .fromDocument(
                    doc,
                  ),
            )
                .toList();
      }

      _lectures.sort(
            (a, b) => _timeToMinutes(
          a.start,
        ).compareTo(
          _timeToMinutes(
            b.start,
          ),
        ),
      );

      _normalizeLocalOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء تحميل الجدول: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _migrateLegacyDay(
      DocumentSnapshot<
          Map<String, dynamic>>
      legacyDocument,
      ) async {
    final data =
    legacyDocument.data();

    if (data == null) return;

    final lectures =
    data['lectures'];

    if (lectures is! List) return;

    final batch =
    _firestore.batch();

    int order = 0;

    for (final item in lectures) {
      if (item is! Map) continue;

      final lecture =
      Map<String, dynamic>.from(
        item,
      );

      final subject =
          lecture['subject']
              ?.toString() ??
              '';

      final professor =
          lecture['professor']
              ?.toString() ??
              lecture['teacher']
                  ?.toString() ??
              '';

      final start =
          lecture['start']
              ?.toString() ??
              lecture['startTime']
                  ?.toString() ??
              '';

      final end =
          lecture['end']
              ?.toString() ??
              lecture['endTime']
                  ?.toString() ??
              '';

      if (subject.trim().isEmpty) {
        continue;
      }

      final reference =
      _firestore
          .collection(
        'schedules',
      )
          .doc();

      batch.set(
        reference,
        {
          'dayAr':
          _selectedDay,
          'day':
          _dayEnglish[
          _selectedDay],
          'subject':
          subject.trim(),
          'teacher':
          professor.trim(),
          'professor':
          professor.trim(),
          'startTime':
          start.trim(),
          'endTime':
          end.trim(),
          'start':
          start.trim(),
          'end':
          end.trim(),
          'order':
          order,
        },
      );

      order++;
    }

    batch.delete(
      legacyDocument.reference,
    );

    await batch.commit();
  }

  Future<void> _addLecture() async {
    final result =
    await _showLectureDialog();

    if (result == null) return;

    try {
      final reference =
      await _firestore
          .collection(
        'schedules',
      )
          .add(
        {
          'dayAr':
          _selectedDay,
          'day':
          _dayEnglish[
          _selectedDay],
          'subject':
          result.subject,
          'teacher':
          result.professor,
          'professor':
          result.professor,
          'startTime':
          result.start,
          'endTime':
          result.end,
          'start':
          result.start,
          'end':
          result.end,
          'order': _lectures.length,
          if (widget.teacherMode) ...{
            'teacherId': widget.teacherId,
            'teacher': widget.teacherName ?? '',
            'professor': result.professor,
            'department': widget.department,
            'stage': widget.stage,
            'group': result.group,
            'audienceHalls': result.audienceHalls,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          },
        },
      );

      _lectures.add(
        _AdminLecture(
          documentId:
          reference.id,
          subject:
          result.subject,
          professor:
          result.professor,
          start:
          result.start,
          end:
          result.end,
          order:
          _lectures.length,
        ),
      );

      _sortLectures();

      await _updateOrders();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء إضافة المحاضرة: $e',
          ),
        ),
      );
    }
  }

  Future<void> _editLecture(
      _AdminLecture lecture,
      ) async {
    final result =
    await _showLectureDialog(
      lecture: lecture,
    );

    if (result == null) return;

    try {
      await _firestore
          .collection('schedules')
          .doc(lecture.documentId)
          .update(
        {
          'dayAr':
          _selectedDay,
          'day':
          _dayEnglish[
          _selectedDay],
          'subject':
          result.subject,
          'teacher':
          result.professor,
          'professor':
          result.professor,
          'startTime':
          result.start,
          'endTime':
          result.end,
          'start':
          result.start,
          'end': result.end,
          if (widget.teacherMode) ...{
            'teacherId': widget.teacherId,
            'teacher': widget.teacherName ?? '',
            'professor': result.professor,
            'department': widget.department,
            'stage': widget.stage,
            'group': result.group,
            'audienceHalls': result.audienceHalls,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      );

      lecture.subject =
          result.subject;
      lecture.professor =
          result.professor;
      lecture.start =
          result.start;
      lecture.end =
          result.end;

      _sortLectures();

      await _updateOrders();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تعديل المحاضرة: $e',
          ),
        ),
      );
    }
  }

  Future<void> _deleteLecture(
      _AdminLecture lecture,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(
              20,
            ),
          ),
          title: const Text(
            'حذف المحاضرة',
            style: TextStyle(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          content: Text(
            'هل تريد حذف محاضرة "${lecture.subject}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child:
              const Text('إلغاء'),
            ),
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                _danger,
                foregroundColor:
                Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              child:
              const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('schedules')
          .doc(
        lecture.documentId,
      )
          .delete();

      _lectures.removeWhere(
            (item) =>
        item.documentId ==
            lecture.documentId,
      );

      _sortLectures();

      await _updateOrders();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء حذف المحاضرة: $e',
          ),
        ),
      );
    }
  }

  Future<void> _updateOrders() async {
    if (_lectures.isEmpty) return;

    final batch =
    _firestore.batch();

    for (int i = 0;
    i < _lectures.length;
    i++) {
      _lectures[i].order = i;

      batch.update(
        _firestore
            .collection(
          'schedules',
        )
            .doc(
          _lectures[i]
              .documentId,
        ),
        {
          'order': i,
        },
      );
    }

    await batch.commit();
  }

  void _sortLectures() {
    _lectures.sort(
          (a, b) =>
          _timeToMinutes(
            a.start,
          ).compareTo(
            _timeToMinutes(
              b.start,
            ),
          ),
    );
  }

  void _normalizeLocalOrders() {
    for (int i = 0;
    i < _lectures.length;
    i++) {
      _lectures[i].order = i;
    }
  }

  Future<_LectureFormResult?>
  _showLectureDialog({
    _AdminLecture? lecture,
  }) async {
    final subjectController =
    TextEditingController(
      text: lecture?.subject ?? '',
    );

    final professorController =
    TextEditingController(
      text: lecture?.professor ?? '',
    );

    final startController =
    TextEditingController(
      text: lecture?.start ?? '',
    );

    final endController =
    TextEditingController(
      text: lecture?.end ?? '',
    );

    final formKey =
    GlobalKey<FormState>();

    return showDialog<
        _LectureFormResult>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
              Colors.white,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  24,
                ),
              ),
              title: Text(
                lecture == null
                    ? 'إضافة محاضرة'
                    : 'تعديل المحاضرة',
                style:
                const TextStyle(
                  color: _textDark,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              content:
              SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller:
                        subjectController,
                        textDirection:
                        TextDirection
                            .rtl,
                        decoration:
                        _inputDecoration(
                          'اسم المادة',
                          Icons.book_rounded,
                        ),
                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'أدخل اسم المادة';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                          height: 12),
                      TextFormField(
                        controller:
                        professorController,
                        textDirection:
                        TextDirection
                            .rtl,
                        decoration:
                        _inputDecoration(
                          'اسم الأستاذ',
                          Icons.person_rounded,
                        ),
                      ),
                      const SizedBox(
                          height: 12),
                      TextFormField(
                        controller:
                        startController,
                        decoration:
                        _inputDecoration(
                          'وقت البداية',
                          Icons
                              .schedule_rounded,
                        ).copyWith(
                          hintText:
                          'مثال: 08:30 AM',
                        ),
                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'أدخل وقت البداية';
                          }

                          if (_timeToMinutes(
                            value.trim(),
                          ) ==
                              -1) {
                            return 'صيغة الوقت غير صحيحة';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(
                          height: 12),
                      TextFormField(
                        controller:
                        endController,
                        decoration:
                        _inputDecoration(
                          'وقت النهاية',
                          Icons
                              .access_time_rounded,
                        ).copyWith(
                          hintText:
                          'مثال: 10:00 AM',
                        ),
                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'أدخل وقت النهاية';
                          }

                          if (_timeToMinutes(
                            value.trim(),
                          ) ==
                              -1) {
                            return 'صيغة الوقت غير صحيحة';
                          }

                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () =>
                      Navigator.pop(
                        dialogContext,
                      ),
                  child:
                  const Text(
                    'إلغاء',
                  ),
                ),
                ElevatedButton(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    _primary,
                    foregroundColor:
                    Colors.white,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () {
                    if (!formKey
                        .currentState!
                        .validate()) {
                      return;
                    }

                    final start =
                    startController
                        .text
                        .trim();

                    final end =
                    endController
                        .text
                        .trim();

                    if (_timeToMinutes(
                      start,
                    ) >=
                        _timeToMinutes(
                          end,
                        )) {
                      ScaffoldMessenger
                          .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'وقت النهاية يجب أن يكون بعد وقت البداية',
                          ),
                        ),
                      );
                      return;
                    }

                    setDialogState(
                          () {
                        saving = true;
                      },
                    );

                    Navigator.pop(
                      dialogContext,
                      _LectureFormResult(
                        subject:
                        subjectController
                            .text
                            .trim(),
                        professor:
                        professorController
                            .text
                            .trim(),
                        start:
                        start,
                        end:
                        end,
                      ),
                    );
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors.white,
                    ),
                  )
                      : Text(
                    lecture == null
                        ? 'إضافة'
                        : 'حفظ',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      _background,
      appBar: AppBar(
        backgroundColor:
        _background,
        foregroundColor:
        _textDark,
        elevation: 0,
        title: Text(
          widget.teacherMode ? 'إدارة محاضراتي' : 'إدارة الجدول الدراسي',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton:
      FloatingActionButton
          .extended(
        backgroundColor:
        _primary,
        foregroundColor:
        Colors.white,
        onPressed:
        _loading
            ? null
            : _addLecture,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'إضافة محاضرة',
          style: TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildDaySelector(),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(
              child:
              CircularProgressIndicator(
                color: _primary,
              ),
            )
                : _lectures.isEmpty
                ? _buildEmptySchedule()
                : RefreshIndicator(
              color:
              _primary,
              onRefresh:
              _loadSchedule,
              child:
              ListView
                  .separated(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  16,
                  8,
                  16,
                  100,
                ),
                itemCount:
                _lectures
                    .length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  height: 12,
                ),
                itemBuilder:
                    (context,
                    index) {
                  return _buildLectureCard(
                    _lectures[
                    index],
                    index,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 52,
      child:
      ListView.separated(
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 16,
        ),
        scrollDirection:
        Axis.horizontal,
        itemCount:
        _days.length,
        separatorBuilder:
            (_, __) =>
        const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (context, index) {
          final day =
          _days[index];
          final selected =
              day == _selectedDay;

          return ChoiceChip(
            label: Text(day),
            selected:
            selected,
            onSelected:
                (_) {
              if (_selectedDay ==
                  day) {
                return;
              }

              setState(() {
                _selectedDay =
                    day;
              });

              _loadSchedule();
            },
            selectedColor:
            _primary,
            backgroundColor:
            Colors.white,
            labelStyle:
            TextStyle(
              color: selected
                  ? Colors.white
                  : _textDark,
              fontWeight:
              FontWeight.w700,
            ),
            side:
            BorderSide(
              color: selected
                  ? _primary
                  : const Color(
                0xFFE4E1EB,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLectureCard(
      _AdminLecture lecture,
      int index,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(
        17,
      ),
      decoration:
      BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(
          22,
        ),
        border:
        Border.all(
          color: const Color(
            0xFFEAE7F2,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
            BoxDecoration(
              color:
              _softPurple,
              borderRadius:
              BorderRadius.circular(
                16,
              ),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style:
                const TextStyle(
                  color:
                  _primary,
                  fontSize:
                  18,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(
              width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  lecture.subject,
                  style:
                  const TextStyle(
                    color:
                    _textDark,
                    fontSize:
                    16,
                    fontWeight:
                    FontWeight
                        .w900,
                  ),
                ),
                if (lecture
                    .professor
                    .isNotEmpty) ...[
                  const SizedBox(
                      height: 5),
                  Text(
                    lecture
                        .professor,
                    style:
                    const TextStyle(
                      color:
                      _textMuted,
                      fontSize:
                      12.5,
                    ),
                  ),
                ],
                const SizedBox(
                    height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons
                          .access_time_rounded,
                      size: 16,
                      color:
                      _primary,
                    ),
                    const SizedBox(
                        width: 5),
                    Text(
                      '${lecture.start} - ${lecture.end}',
                      style:
                      const TextStyle(
                        color:
                        _textDark,
                        fontSize:
                        12.5,
                        fontWeight:
                        FontWeight
                            .w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<
              String>(
            onSelected:
                (value) {
              if (value ==
                  'edit') {
                _editLecture(
                    lecture);
              } else if (value ==
                  'delete') {
                _deleteLecture(
                    lecture);
              }
            },
            itemBuilder:
                (_) =>
            const [
              PopupMenuItem(
                value:
                'edit',
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .edit_rounded,
                      size: 20,
                    ),
                    SizedBox(
                        width: 8),
                    Text(
                        'تعديل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value:
                'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .delete_outline_rounded,
                      color:
                      _danger,
                      size: 20,
                    ),
                    SizedBox(
                        width: 8),
                    Text(
                        'حذف'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySchedule() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets
            .all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
              BoxDecoration(
                color:
                _softPurple,
                borderRadius:
                BorderRadius
                    .circular(
                  25,
                ),
              ),
              child:
              const Icon(
                Icons
                    .calendar_month_rounded,
                color:
                _primary,
                size: 40,
              ),
            ),
            const SizedBox(
                height: 18),
            Text(
              'لا توجد محاضرات يوم $_selectedDay',
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                _textDark,
                fontSize:
                17,
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),
            const SizedBox(
                height: 7),
            const Text(
              'اضغط على زر إضافة محاضرة لإضافة أول محاضرة.',
              textAlign:
              TextAlign.center,
              style:
              TextStyle(
                color:
                _textMuted,
                fontSize:
                13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MODELS
// ============================================================

class _AdminLecture {
  String documentId;
  String subject;
  String professor;
  String start;
  String end;
  int order;
  String group;
  List<String> audienceHalls;

  _AdminLecture({
    required this.documentId,
    required this.subject,
    required this.professor,
    required this.start,
    required this.end,
    required this.order,
    this.group = 'A',
    this.audienceHalls = const ['A'],
  });

  factory _AdminLecture.fromDocument(
      DocumentSnapshot<
          Map<String, dynamic>>
      document,
      ) {
    final data =
        document.data() ?? {};

    return _AdminLecture(
      documentId:
      document.id,
      subject:
      data['subject']
          ?.toString() ??
          '',
      professor:
      data['teacher']
          ?.toString() ??
          data['professor']
              ?.toString() ??
          '',
      start:
      data['startTime']
          ?.toString() ??
          data['start']
              ?.toString() ??
          '',
      end:
      data['endTime']
          ?.toString() ??
          data['end']
              ?.toString() ??
          '',
      order: _readOrder(data['order']),
      group: data['group']?.toString() ?? 'A',
      audienceHalls: (data['audienceHalls'] is List)
          ? (data['audienceHalls'] as List).map((value) => value.toString()).toList()
          : [data['group']?.toString() ?? 'A'],
    );
  }

  static int _readOrder(
      dynamic value,
      ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ??
          '',
    ) ??
        0;
  }
}

class _LectureFormResult {
  final String subject;
  final String professor;
  final String start;
  final String end;
  final String group;
  final List<String> audienceHalls;

  const _LectureFormResult({
    required this.subject,
    required this.professor,
    required this.start,
    required this.end,
    this.group = 'A',
    this.audienceHalls = const ['A'],
  });
}

// ============================================================
// HELPERS
// ============================================================

InputDecoration _inputDecoration(
    String label,
    IconData icon,
    ) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(
      icon,
      color: _primary,
    ),
    filled: true,
    fillColor:
    const Color(0xFFF9F8FC),
    border:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      borderSide:
      BorderSide.none,
    ),
    enabledBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      borderSide:
      const BorderSide(
        color:
        Color(0xFFE8E5EF),
      ),
    ),
    focusedBorder:
    OutlineInputBorder(
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      borderSide:
      const BorderSide(
        color: _primary,
        width: 1.4,
      ),
    ),
  );
}

int _timeToMinutes(
    String value,
    ) {
  final text =
  value.trim().toUpperCase();

  if (text.isEmpty) return -1;

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
  ).firstMatch(text);

  if (match == null) return -1;

  int hour =
      int.tryParse(
        match.group(1)!,
      ) ??
          -1;

  final minute =
      int.tryParse(
        match.group(2)!,
      ) ??
          -1;

  final period =
  match.group(3);

  if (hour < 0 ||
      minute < 0 ||
      minute > 59) {
    return -1;
  }

  if (period != null) {
    if (hour < 1 ||
        hour > 12) {
      return -1;
    }

    if (period == 'AM') {
      if (hour == 12) {
        hour = 0;
      }
    } else {
      if (hour != 12) {
        hour += 12;
      }
    }
  } else {
    if (hour > 23) {
      return -1;
    }
  }

  return hour * 60 + minute;
}