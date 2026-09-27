import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'preparations_page.dart';
import 'schedule_page.dart';
import 'student_profile_page.dart';
import 'admin_page.dart';
import 'settings_page.dart';
import 'accounts_page.dart';
import 'language_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  bool _isAdmin = false;
  bool _isLoadingProfile = true;

  String _accountRole = 'student';
  String _studentName = 'Student';
  String _stage = '';
  String _group = '';
  String _specialization = '';
  String _department = '';

  final Color primary = const Color(0xFF6C4CF1);
  final Color dark = const Color(0xFF171525);
  final Color background = const Color(0xFFF7F7FB);

  late AnimationController _animationController;

  Timer? _scheduleTimer;

  List<_HomeLecture> _homeSchedule = [];
  _HomeLecture? _displayedLecture;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loadAccountData();
    _loadHomeSchedule();

    _scheduleTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _updateDisplayedLecture(),
    );
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoadingProfile = false;
          });
        }
        return;
      }

      final firestore = FirebaseFirestore.instance;

      DocumentSnapshot<Map<String, dynamic>>? document;

      final studentDoc =
      await firestore.collection('students').doc(user.uid).get();

      if (studentDoc.exists) {
        document = studentDoc;
      } else {
        final teacherDoc =
        await firestore.collection('teachers').doc(user.uid).get();

        if (teacherDoc.exists) {
          document = teacherDoc;
        }
      }

      String role = 'student';
      String name = _getAuthFirstName(user.displayName);

      String stage = '';
      String group = '';
      String specialization = '';
      String department = '';

      if (document != null && document.exists) {
        final data = document.data() ?? {};

        role = data['role']?.toString() ?? 'student';

        final firestoreName = data['name']?.toString();

        if (firestoreName != null && firestoreName.trim().isNotEmpty) {
          name = _getFirstName(firestoreName);
        }

        stage = data['stage']?.toString() ?? '';
        group = data['group']?.toString() ?? '';
        specialization = data['specialization']?.toString() ?? '';
        department = data['department']?.toString() ?? '';
      }

      if (!mounted) return;

      setState(() {
        _accountRole = role;
        _studentName = name;
        _stage = stage;
        _group = group;
        _specialization = specialization;
        _department = department;
        _isAdmin = role.toLowerCase() == 'admin';
        _isLoadingProfile = false;
      });

      _animationController.forward(from: 0);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });

      _animationController.forward(from: 0);
    }
  }

  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return 'Student';
    }

    final cleaned = fullName.trim();

    if (cleaned.isEmpty) {
      return 'Student';
    }

    return cleaned.split(RegExp(r'\s+')).first;
  }

  String _getAuthFirstName(String? fullName) {
    return _getFirstName(fullName);
  }

  bool get _isTeacher {
    return _accountRole.trim().toLowerCase() == 'teacher';
  }

  String _greeting(bool isArabic) {
    final hour = DateTime.now().hour;

    if (isArabic) {
      if (hour < 12) return 'صباح الخير';
      return 'مساء الخير';
    }

    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _academicInfo(bool isArabic) {
    if (_isTeacher) {
      final specialization = _specialization.isNotEmpty
          ? _translateSpecialization(_specialization, isArabic)
          : (isArabic ? 'التدريس' : 'Teaching');

      final department = _department.isNotEmpty
          ? _translateDepartment(_department, isArabic)
          : (isArabic ? 'قسم اللغة الإنكليزية' : 'English Department');

      return '$specialization • $department';
    }

    final stage = _stage.isNotEmpty
        ? _translateStage(_stage, isArabic)
        : (isArabic ? 'المرحلة الدراسية' : 'Academic Stage');

    final department = _department.isNotEmpty
        ? _translateDepartment(_department, isArabic)
        : (isArabic ? 'قسم اللغة الإنكليزية' : 'English Department');

    final group = _group.isNotEmpty ? ' • ${_group.toUpperCase()}' : '';

    return '$stage • $department$group';
  }

  String _translateStage(String value, bool isArabic) {
    final lower = value.trim().toLowerCase();

    if (lower.contains('first') ||
        lower.contains('1st') ||
        lower == '1' ||
        lower.contains('الأولى') ||
        lower.contains('الاولى') ||
        lower.contains('اولى') ||
        lower.contains('أولى')) {
      return isArabic ? 'المرحلة الأولى' : 'First Stage';
    }

    if (lower.contains('second') ||
        lower.contains('2nd') ||
        lower == '2' ||
        lower.contains('الثانية') ||
        lower.contains('الثانيه') ||
        lower.contains('ثانية') ||
        lower.contains('ثانيه')) {
      return isArabic ? 'المرحلة الثانية' : 'Second Stage';
    }

    if (lower.contains('third') ||
        lower.contains('3rd') ||
        lower == '3' ||
        lower.contains('الثالثة') ||
        lower.contains('الثالثه') ||
        lower.contains('ثالثة') ||
        lower.contains('ثالثه')) {
      return isArabic ? 'المرحلة الثالثة' : 'Third Stage';
    }

    if (lower.contains('fourth') ||
        lower.contains('4th') ||
        lower == '4' ||
        lower.contains('الرابعة') ||
        lower.contains('الرابعه') ||
        lower.contains('رابعة') ||
        lower.contains('رابعه')) {
      return isArabic ? 'المرحلة الرابعة' : 'Fourth Stage';
    }

    return value;
  }

  String _translateDepartment(String value, bool isArabic) {
    final lower = value.trim().toLowerCase();

    if (lower.contains('english') ||
        lower.contains('english language') ||
        lower.contains('لغة إنكليزية') ||
        lower.contains('لغة انجليزية')) {
      return isArabic
          ? 'قسم اللغة الإنكليزية'
          : 'English Language Department';
    }

    if (lower.contains('education') || lower.contains('تربية')) {
      return isArabic ? 'كلية التربية' : 'College of Education';
    }

    return value;
  }

  String _translateSpecialization(String value, bool isArabic) {
    return value;
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );

    if (mounted) {
      await _loadAccountData();
    }
  }

  // ============================================================
  // HOME SCHEDULE
  // ============================================================

  Future<void> _loadHomeSchedule() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('schedules').get();

      final List<_HomeLecture> lectures = [];

      for (final document in snapshot.docs) {
        final data = document.data();

        final nestedLectures = data['lectures'];

        if (nestedLectures is List) {
          for (final item in nestedLectures) {
            if (item is Map) {
              final lecture = _lectureFromMap(
                Map<String, dynamic>.from(item),
                documentDay: data['dayAr']?.toString(),
              );

              if (lecture != null) {
                lectures.add(lecture);
              }
            }
          }
        } else {
          final lecture = _lectureFromMap(
            data,
            documentDay: data['dayAr']?.toString(),
          );

          if (lecture != null) {
            lectures.add(lecture);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _homeSchedule = lectures;
      });

      _updateDisplayedLecture();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _homeSchedule = [];
        _displayedLecture = null;
      });
    }
  }

  _HomeLecture? _lectureFromMap(
      Map<String, dynamic> data, {
        String? documentDay,
      }) {
    final dayValue = data['dayAr'] ??
        data['dayName'] ??
        data['day'] ??
        documentDay;

    final subjectValue =
        data['subject'] ?? data['course'] ?? data['title'] ?? data['name'];

    final professorValue = data['professor'] ??
        data['teacher'] ??
        data['instructor'] ??
        data['lecturer'];

    final startValue =
        data['startTime'] ?? data['start'] ?? data['from'];

    final endValue =
        data['endTime'] ?? data['end'] ?? data['to'];

    if (dayValue == null ||
        subjectValue == null ||
        startValue == null ||
        endValue == null) {
      return null;
    }

    final day = _normalizeDay(dayValue.toString());

    if (day == null) {
      return null;
    }

    final start = startValue.toString().trim();
    final end = endValue.toString().trim();

    if (start.isEmpty || end.isEmpty) {
      return null;
    }

    return _HomeLecture(
      day: day,
      subject: subjectValue.toString().trim(),
      professor: professorValue?.toString().trim() ?? '',
      startTime: start,
      endTime: end,
      order: _parseOrder(data['order']),
    );
  }

  int _parseOrder(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _normalizeDay(String value) {
    final day = value.trim().toLowerCase();

    if (day == 'الأحد' ||
        day == 'الاحد' ||
        day == 'sunday' ||
        day == 'sun') {
      return 'الأحد';
    }

    if (day == 'الاثنين' ||
        day == 'الإثنين' ||
        day == 'monday' ||
        day == 'mon') {
      return 'الاثنين';
    }

    if (day == 'الثلاثاء' ||
        day == 'tuesday' ||
        day == 'tue') {
      return 'الثلاثاء';
    }

    if (day == 'الأربعاء' ||
        day == 'الاربعاء' ||
        day == 'wednesday' ||
        day == 'wed') {
      return 'الأربعاء';
    }

    return null;
  }

  int? _timeToMinutes(String value) {
    final text = value.trim();

    if (text.isEmpty) return null;

    final upper = text.toUpperCase();

    final match12 = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    ).firstMatch(upper);

    if (match12 != null) {
      var hour = int.tryParse(match12.group(1)!) ?? 0;
      final minute = int.tryParse(match12.group(2)!) ?? 0;
      final period = match12.group(3)!;

      if (hour == 12) {
        hour = 0;
      }

      if (period == 'PM') {
        hour += 12;
      }

      if (hour > 23 || minute > 59) {
        return null;
      }

      return hour * 60 + minute;
    }

    final match24 = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(text);

    if (match24 != null) {
      final hour = int.tryParse(match24.group(1)!) ?? 0;
      final minute = int.tryParse(match24.group(2)!) ?? 0;

      if (hour > 23 || minute > 59) {
        return null;
      }

      return hour * 60 + minute;
    }

    return null;
  }

  bool _isRestDay(DateTime date) {
    return date.weekday == DateTime.thursday ||
        date.weekday == DateTime.friday ||
        date.weekday == DateTime.saturday;
  }

  String? _todayDayName() {
    return _dayNameForWeekday(DateTime.now().weekday);
  }

  void _updateDisplayedLecture() {
    final now = DateTime.now();

    if (_isRestDay(now)) {
      if (!mounted) return;

      if (_displayedLecture != null) {
        setState(() {
          _displayedLecture = null;
        });
      }

      return;
    }

    if (_homeSchedule.isEmpty) {
      if (mounted && _displayedLecture != null) {
        setState(() {
          _displayedLecture = null;
        });
      }
      return;
    }

    final result = _findTodayLecture(now);

    if (!mounted) return;

    final old = _displayedLecture;

    if (old?.uniqueKey != result?.uniqueKey) {
      setState(() {
        _displayedLecture = result;
      });
    }
  }

  _HomeLecture? _findTodayLecture(DateTime now) {
    final todayDay = _dayNameForWeekday(now.weekday);

    if (todayDay == null) {
      return null;
    }

    final todayLectures = _lecturesForDay(todayDay);

    if (todayLectures.isEmpty) {
      return null;
    }

    final nowMinutes = now.hour * 60 + now.minute;

    for (final lecture in todayLectures) {
      final start = _timeToMinutes(lecture.startTime);
      final end = _timeToMinutes(lecture.endTime);

      if (start == null || end == null) {
        continue;
      }

      if (nowMinutes < start) {
        return lecture;
      }

      if (nowMinutes >= start && nowMinutes < end) {
        return lecture;
      }
    }

    return null;
  }

  List<_HomeLecture> _lecturesForDay(String day) {
    final lectures = _homeSchedule
        .where((lecture) => lecture.day == day)
        .toList();

    lectures.sort((a, b) {
      final aStart = _timeToMinutes(a.startTime) ?? 9999;
      final bStart = _timeToMinutes(b.startTime) ?? 9999;

      if (aStart != bStart) {
        return aStart.compareTo(bStart);
      }

      return a.order.compareTo(b.order);
    });

    return lectures;
  }

  String? _dayNameForWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.sunday:
        return 'الأحد';
      default:
        return null;
    }
  }

  String _englishDay(String day) {
    switch (day) {
      case 'الأحد':
        return 'Sunday';
      case 'الاثنين':
        return 'Monday';
      case 'الثلاثاء':
        return 'Tuesday';
      case 'الأربعاء':
        return 'Wednesday';
      case 'الخميس':
        return 'Thursday';
      case 'الجمعة':
        return 'Friday';
      case 'السبت':
        return 'Saturday';
      default:
        return day;
    }
  }

  String _formatLectureTime(_HomeLecture lecture) {
    return '${lecture.startTime} — ${lecture.endTime}';
  }

  String _displayDate(bool isArabic) {
    final date = DateTime.now();

    const arabicMonths = [
      'كانون الثاني',
      'شباط',
      'آذار',
      'نيسان',
      'أيار',
      'حزيران',
      'تموز',
      'آب',
      'أيلول',
      'تشرين الأول',
      'تشرين الثاني',
      'كانون الأول',
    ];

    const englishMonths = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (isArabic) {
      return '${date.day} ${arabicMonths[date.month - 1]}';
    }

    return '${englishMonths[date.month - 1]} ${date.day}';
  }

  String _todayLabel(bool isArabic) {
    final day = DateTime.now().weekday;

    switch (day) {
      case DateTime.sunday:
        return isArabic ? 'الأحد' : 'Sunday';
      case DateTime.monday:
        return isArabic ? 'الاثنين' : 'Monday';
      case DateTime.tuesday:
        return isArabic ? 'الثلاثاء' : 'Tuesday';
      case DateTime.wednesday:
        return isArabic ? 'الأربعاء' : 'Wednesday';
      case DateTime.thursday:
        return isArabic ? 'الخميس' : 'Thursday';
      case DateTime.friday:
        return isArabic ? 'الجمعة' : 'Friday';
      case DateTime.saturday:
        return isArabic ? 'السبت' : 'Saturday';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final bool isArabic = language.isArabic;

    final pages = [
      _buildHome(isArabic),
      const SchedulePage(),
      const PreparationsPage(),
    ];

    return Scaffold(
      backgroundColor: background,
      extendBody: true,
      body: pages[_currentIndex],
      bottomNavigationBar: _buildBottomNavigation(isArabic),
    );
  }

  Widget _buildHome(bool isArabic) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: primary,
        onRefresh: () async {
          await _loadAccountData();
          await _loadHomeSchedule();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _animated(
                0.0,
                _buildHeader(isArabic),
              ),
            ),
            SliverToBoxAdapter(
              child: _animated(
                0.12,
                _buildHeroCard(isArabic),
              ),
            ),
            SliverToBoxAdapter(
              child: _animated(
                0.22,
                _buildSectionHeader(
                  isArabic ? 'الوصول السريع' : 'Quick Access',
                  isArabic
                      ? 'كل ما تحتاجه بمكان واحد'
                      : 'Everything you need',
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _animated(
                0.28,
                _buildQuickActions(isArabic),
              ),
            ),
            if (_isAdmin)
              SliverToBoxAdapter(
                child: _animated(
                  0.35,
                  _buildAdminButton(isArabic),
                ),
              ),
            SliverToBoxAdapter(
              child: _animated(
                0.42,
                _buildNextClass(isArabic),
              ),
            ),
            SliverToBoxAdapter(
              child: _animated(
                0.52,
                _buildAnnouncement(isArabic),
              ),
            ),
            SliverToBoxAdapter(
              child: _animated(
                0.62,
                _isTeacher
                    ? _buildTeacherCard(isArabic)
                    : _buildSemesterCard(isArabic),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 125),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openPage(
                    const StudentProfilePage(),
                  ),
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primary,
                          primary.withValues(alpha: .72),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: .20),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(isArabic),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoadingProfile ? '...' : _studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF191722),
                          letterSpacing: -.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _academicInfo(isArabic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _headerButton(
            icon: Icons.swap_horiz_rounded,
            onTap: () => _openPage(
              const AccountsPage(),
            ),
          ),
          const SizedBox(width: 8),
          _headerButton(
            icon: Icons.settings_outlined,
            onTap: () => _openPage(
              const SettingsPage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.black.withValues(alpha: .045),
            ),
          ),
          child: Icon(
            icon,
            size: 21,
            color: const Color(0xFF393642),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(bool isArabic) {
    final lecture = _displayedLecture;
    final now = DateTime.now();
    final restDay = _isRestDay(now);

    final subject = restDay
        ? (isArabic ? 'استراحة' : 'Day Off')
        : lecture == null
        ? (isArabic ? 'لا توجد محاضرات' : 'No Classes')
        : lecture.subject;

    final professor = restDay
        ? (isArabic
        ? 'لا توجد محاضرات مجدولة اليوم'
        : 'No classes scheduled today')
        : lecture == null
        ? (isArabic
        ? 'لا توجد محاضرة مجدولة حالياً'
        : 'No scheduled class currently')
        : lecture.professor;

    final time = restDay
        ? '--:--'
        : lecture == null
        ? '--:--'
        : _formatLectureTime(lecture);

    final today = _todayLabel(isArabic);
    final date = _displayDate(isArabic);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 225,
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
              color: const Color(0xFF6C4CF1).withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -35,
              top: -40,
              child: Container(
                width: 135,
                height: 135,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 35,
              bottom: -60,
              child: Container(
                width: 105,
                height: 105,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -70,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.045),
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
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        today,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  professor.isEmpty
                      ? (isArabic
                      ? 'المدرس غير محدد'
                      : 'Teacher not specified')
                      : professor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    _HeroStat(
                      icon: Icons.access_time_rounded,
                      text: time,
                    ),
                    const SizedBox(width: 10),
                    _HeroStat(
                      icon: Icons.school_rounded,
                      text: restDay
                          ? (isArabic ? 'استراحة' : 'Day Off')
                          : (isArabic ? 'محاضرة' : 'Lecture'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1821),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _quickAction(
              icon: Icons.calendar_month_rounded,
              title: isArabic ? 'الجدول' : 'Schedule',
              subtitle: isArabic ? 'محاضراتك' : 'Your classes',
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickAction(
              icon: Icons.menu_book_rounded,
              title: isArabic ? 'التحضيرات' : 'Preparations',
              subtitle: isArabic
                  ? 'المواد الدراسية'
                  : 'Study materials',
              onTap: () {
                setState(() {
                  _currentIndex = 2;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(23),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: Colors.black.withValues(alpha: .045),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .025),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF26232E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminButton(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => _openPage(const AdminPage()),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF171525),
                  Color(0xFF28243A),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'لوحة الإدارة' : 'Admin Panel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isArabic
                            ? 'إدارة التطبيق والطلاب'
                            : 'Manage app and students',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .55),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: .75),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextClass(bool isArabic) {
    final lecture = _displayedLecture;

    final subject = lecture == null
        ? (isArabic ? 'لا توجد محاضرات حالياً' : 'No classes currently')
        : lecture.subject;

    final time = lecture == null
        ? '--:--'
        : lecture.startTime;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'المحاضرة القادمة' : 'Next Class',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1821),
            ),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: Colors.black.withValues(alpha: .045),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .025),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: primary,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF25222D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Room C',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: primary,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncement(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'آخر التحديثات' : 'Latest Updates',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1821),
            ),
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: Colors.black.withValues(alpha: .045),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3DD),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Color(0xFFDB921E),
                    size: 23,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isArabic
                                  ? 'تحديث تحضير الكتابة الأكاديمية'
                                  : 'Academic Writing Preparation',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF25222D),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              isArabic ? 'جديد' : 'NEW',
                              style: TextStyle(
                                color: primary,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        isArabic
                            ? 'تم تحديث التحضير وإضافة المحتوى الجديد للمادة.'
                            : 'The preparation has been updated with new study content.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1C1A27),
              Color(0xFF29253A),
            ],
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 67,
                    height: 67,
                    child: CircularProgressIndicator(
                      value: .72,
                      strokeWidth: 6,
                      backgroundColor:
                      Colors.white.withValues(alpha: .10),
                      valueColor:
                      AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const Text(
                    '72%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'التقدم الدراسي' : 'Academic Progress',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isArabic
                        ? 'أنجزت 18 محاضرة هذا الفصل'
                        : '18 classes completed this semester',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .55),
                      fontSize: 10.5,
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

  Widget _buildTeacherCard(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [
              primary,
              const Color(0xFF4F38BD),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: .18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.cast_for_education_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? 'حساب تدريسي' : 'Teacher Account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isArabic
                        ? 'مرحباً بك في Classroom Hub'
                        : 'Welcome to Classroom Hub',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .65),
                      fontSize: 10.5,
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

  Widget _buildBottomNavigation(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.black.withValues(alpha: .045),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .10),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _navItem(
              index: 0,
              icon: Icons.home_rounded,
              label: isArabic ? 'الرئيسية' : 'Home',
            ),
            _navItem(
              index: 1,
              icon: Icons.calendar_month_rounded,
              label: isArabic ? 'الجدول' : 'Schedule',
            ),
            _navItem(
              index: 2,
              icon: Icons.menu_book_rounded,
              label: isArabic ? 'التحضيرات' : 'Preparations',
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: .10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: selected ? 23 : 21,
                color: selected
                    ? primary
                    : const Color(0xFF96929F),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                  selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? primary
                      : const Color(0xFF96929F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animated(double start, Widget child) {
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(
        start,
        (start + .35).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .035),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _HomeLecture {
  final String day;
  final String subject;
  final String professor;
  final String startTime;
  final String endTime;
  final int order;

  const _HomeLecture({
    required this.day,
    required this.subject,
    required this.professor,
    required this.startTime,
    required this.endTime,
    required this.order,
  });

  String get uniqueKey {
    return '$day|$subject|$professor|$startTime|$endTime|$order';
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroStat({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}