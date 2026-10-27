import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'language_controller.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  static const Color primary = Color(0xFF6C4CF1);
  static const Color primaryDark = Color(0xFF5132C8);
  static const Color background = Color(0xFFF7F7FB);
  static const Color textDark = Color(0xFF181625);
  static const Color textMuted = Color(0xFF777487);

  static const allowedDays = [
    'الأحد',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
  ];

  String _normalizeDepartment(String value) {
    final v = value.trim();

    if (v == 'قسم اللغة الانكليزية' ||
        v == 'قسم اللغة الإنجليزية' ||
        v == 'اللغة الانكليزية' ||
        v == 'اللغة الإنجليزية') {
      return 'English Language Department';
    }

    return v;
  }

  String _normalizeStage(String value) {
    final v = value.trim();

    switch (v) {
      case 'المرحلة الأولى':
      case 'المرحلة الاولى':
      case 'First':
      case '1':
        return 'First Stage';

      case 'المرحلة الثانية':
      case 'المرحلة الثانيه':
      case 'Second':
      case '2':
        return 'Second Stage';

      case 'المرحلة الثالثة':
      case 'المرحلة الثالثه':
      case 'Third':
      case '3':
        return 'Third Stage';

      case 'المرحلة الرابعة':
      case 'المرحلة الرابعه':
      case 'Fourth':
      case '4':
        return 'Fourth Stage';

      default:
        return v;
    }
  }

  String _normalizeGroup(String value) {
    final v = value.trim().toUpperCase();

    if (v == 'GROUP A' ||
        v == 'المجموعة A' ||
        v == 'قاعة A') {
      return 'A';
    }

    if (v == 'GROUP B' ||
        v == 'المجموعة B' ||
        v == 'قاعة B') {
      return 'B';
    }

    if (v == 'GROUP C' ||
        v == 'المجموعة C' ||
        v == 'قاعة C') {
      return 'C';
    }

    if (v == 'GROUP D' ||
        v == 'المجموعة D' ||
        v == 'قاعة D') {
      return 'D';
    }

    return v;
  }

  String _buildScheduleKey({
    required String department,
    required String stage,
    required String group,
  }) {
    return '${_normalizeDepartment(department)}|'
        '${_normalizeStage(stage)}|'
        '${_normalizeGroup(group)}';
  }

  Future<List<Map<String, dynamic>>> _loadSchedule() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return _fallbackForGroup('C');
      }

      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (!studentSnapshot.exists) {
        return _fallbackForGroup('C');
      }

      final studentData = studentSnapshot.data();

      if (studentData == null) {
        return _fallbackForGroup('C');
      }

      final department = _normalizeDepartment(
        studentData['department']?.toString() ?? '',
      );

      final stage = _normalizeStage(
        studentData['stage']?.toString() ?? '',
      );

      final group = _normalizeGroup(
        studentData['group']?.toString() ??
            studentData['studentGroup']?.toString() ??
            studentData['section']?.toString() ??
            '',
      );

      debugPrint('========================================');
      debugPrint('SCHEDULE DEBUG');
      debugPrint('Student UID: ${user.uid}');
      debugPrint('Department: $department');
      debugPrint('Stage: $stage');
      debugPrint('Group: $group');

      if (department.isEmpty ||
          stage.isEmpty ||
          group.isEmpty) {
        debugPrint('Missing profile data.');
        debugPrint('========================================');

        return _fallbackForGroup(
          group.isEmpty ? 'C' : group,
        );
      }

      final scheduleKey = _buildScheduleKey(
        department: department,
        stage: stage,
        group: group,
      );

      debugPrint('Schedule Key: $scheduleKey');

      final directDocument = await FirebaseFirestore.instance
          .collection('schedules')
          .doc(scheduleKey)
          .get();

      if (directDocument.exists) {
        debugPrint('Schedule found directly by document ID.');

        final data = directDocument.data();

        if (data != null) {
          final parsed = _parseSchedule(data);

          if (parsed.isNotEmpty) {
            debugPrint(
              'Loaded Firestore schedule for group $group.',
            );
            debugPrint('========================================');

            return await _mergeTargetedLectures(
              parsed,
              department: department,
              stage: stage,
              group: group,
            );
          }
        }
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where(
        'scheduleKey',
        isEqualTo: scheduleKey,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();

        final parsed = _parseSchedule(data);

        if (parsed.isNotEmpty) {
          debugPrint(
            'Schedule found by scheduleKey query.',
          );
          debugPrint('========================================');

          return await _mergeTargetedLectures(
            parsed,
            department: department,
            stage: stage,
            group: group,
          );
        }
      }

      debugPrint(
        'No Firestore schedule found for $scheduleKey',
      );

      debugPrint(
        'Using local fallback for group $group',
      );

      debugPrint('========================================');

      final targeted = await _loadTargetedLectures(
        department: department,
        stage: stage,
        group: group,
      );
      if (targeted.isNotEmpty) return targeted;
      return _fallbackForGroup(group);
    } catch (e) {
      debugPrint('Schedule loading error: $e');

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return _fallbackForGroup('C');
      }

      try {
        final studentSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .get();

        final data = studentSnapshot.data();

        final group = _normalizeGroup(
          data?['group']?.toString() ??
              data?['studentGroup']?.toString() ??
              data?['section']?.toString() ??
              'C',
        );

        return _fallbackForGroup(group);
      } catch (_) {
        return _fallbackForGroup('C');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _mergeTargetedLectures(
    List<Map<String, dynamic>> base, {
    required String department,
    required String stage,
    required String group,
  }) async {
    final targeted = await _loadTargetedLectures(
      department: department,
      stage: stage,
      group: group,
    );
    if (targeted.isEmpty) return base;

    final merged = <String, Map<String, dynamic>>{};
    for (final day in base) {
      final name = day['dayAr']?.toString() ?? '';
      merged[name] = {
        'dayAr': name,
        'lectures': List<Map<String, dynamic>>.from(
          (day['lectures'] as List? ?? const []).map(
            (lecture) => Map<String, dynamic>.from(lecture as Map),
          ),
        ),
      };
    }
    for (final day in targeted) {
      final name = day['dayAr']?.toString() ?? '';
      final existing = merged.putIfAbsent(
        name,
        () => {'dayAr': name, 'lectures': <Map<String, dynamic>>[]},
      );
      (existing['lectures'] as List).addAll(
        (day['lectures'] as List).map(
          (lecture) => Map<String, dynamic>.from(lecture as Map),
        ),
      );
    }
    return allowedDays
        .where((day) => merged.containsKey(day))
        .map((day) => merged[day]!)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadTargetedLectures({
    required String department,
    required String stage,
    required String group,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .get();
    final byDay = <String, List<Map<String, String>>>{};

    String canonicalDay(Map<String, dynamic> data) {
      final value = (data['dayAr'] ?? data['day'] ?? '').toString().trim();
      const days = <String, String>{
        'Sunday': 'الأحد', 'Monday': 'الاثنين',
        'Tuesday': 'الثلاثاء', 'Wednesday': 'الأربعاء',
        'الأحد': 'الأحد', 'الاحد': 'الأحد',
        'الاثنين': 'الاثنين', 'الإثنين': 'الاثنين',
        'الثلاثاء': 'الثلاثاء', 'الأربعاء': 'الأربعاء',
        'الاربعاء': 'الأربعاء',
      };
      return days[value] ?? '';
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['days'] is List || data['lectures'] is List) continue;
      if (data['teacherId'] == null || data['department'] == null ||
          data['stage'] == null || data['group'] == null) continue;
      if (_normalizeDepartment(data['department'].toString()) != department ||
          _normalizeStage(data['stage'].toString()) != stage) continue;

      final rawHalls = data['audienceHalls'];
      final halls = rawHalls is List
          ? rawHalls.map((value) => _normalizeGroup(value.toString())).toSet()
          : <String>{};
      final targetGroup = _normalizeGroup(data['group'].toString());
      final matches = halls.isNotEmpty
          ? halls.contains(group)
          : (targetGroup == 'ALL' || targetGroup == group);
      if (!matches) continue;

      final day = canonicalDay(data);
      if (!allowedDays.contains(day)) continue;
      final subject = data['subject']?.toString().trim() ?? '';
      final professor = data['professor']?.toString().trim() ??
          data['teacher']?.toString().trim() ?? '';
      final start = data['startTime']?.toString().trim() ??
          data['start']?.toString().trim() ?? '';
      final end = data['endTime']?.toString().trim() ??
          data['end']?.toString().trim() ?? '';
      if (subject.isEmpty || start.isEmpty || end.isEmpty) continue;
      (byDay[day] ??= []).add({
        'subject': subject,
        'professor': professor,
        'start': start,
        'end': end,
      });
    }

    return allowedDays
        .where(byDay.containsKey)
        .map((day) => <String, dynamic>{
          'dayAr': day,
          'lectures': byDay[day]!,
        })
        .toList();
  }

  List<Map<String, dynamic>> _parseSchedule(
      Map<String, dynamic> data,
      ) {
    final rawDays = data['days'];

    if (rawDays is! List) {
      return [];
    }

    final Map<String, Map<String, dynamic>> days = {};

    for (final rawDay in rawDays) {
      if (rawDay is! Map) {
        continue;
      }

      final dayName =
          rawDay['dayAr']?.toString().trim() ?? '';

      if (!allowedDays.contains(dayName)) {
        continue;
      }

      final rawLectures = rawDay['lectures'];

      final List<Map<String, String>> lectures = [];

      if (rawLectures is List) {
        for (final item in rawLectures) {
          if (item is! Map) {
            continue;
          }

          final subject =
              item['subject']?.toString().trim() ?? '';

          final professor =
              item['professor']?.toString().trim() ??
                  item['teacher']?.toString().trim() ??
                  '';

          final start =
              item['start']?.toString().trim() ??
                  item['startTime']?.toString().trim() ??
                  '';

          final end =
              item['end']?.toString().trim() ??
                  item['endTime']?.toString().trim() ??
                  '';

          if (subject.isEmpty &&
              professor.isEmpty &&
              start.isEmpty &&
              end.isEmpty) {
            continue;
          }

          lectures.add({
            'subject': subject,
            'professor': professor,
            'start': start,
            'end': end,
          });
        }
      }

      days[dayName] = {
        'dayAr': dayName,
        'lectures': lectures,
      };
    }

    final result = <Map<String, dynamic>>[];

    for (final dayName in allowedDays) {
      final firestoreDay = days[dayName];

      if (firestoreDay == null) {
        continue;
      }

      final lectures =
      firestoreDay['lectures']
      as List<Map<String, String>>;

      if (lectures.isEmpty) {
        continue;
      }

      result.add({
        'dayAr': dayName,
        'lectures': lectures,
      });
    }

    return result;
  }

  List<Map<String, dynamic>> _fallbackForGroup(
      String group,
      ) {
    switch (_normalizeGroup(group)) {
      case 'A':
        return _groupASchedule();

      case 'B':
        return _groupBSchedule();

      case 'C':
        return _groupCSchedule();

      case 'D':
        return _groupDSchedule();

      default:
        return _groupCSchedule();
    }
  }

  List<Map<String, dynamic>> _groupASchedule() {
    return [
      {
        'dayAr': 'الأحد',
        'lectures': [
          {
            'subject': 'الكتابة',
            'professor': 'م.م زيد علي عبد الرضا',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'الرواية',
            'professor': 'م.م علاء عبد الكاظم',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الاثنين',
        'lectures': [
          {
            'subject': 'المحادثة',
            'professor': 'م.د خورشيد',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'عقائد',
            'professor': 'م.د صدر الدين القبانجي',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'علم اللغة',
            'professor': 'م.م بنين حميد',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الثلاثاء',
        'lectures': [
          {
            'subject': 'طرائق التدريس',
            'professor': 'م.د علي تقي',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'النحو',
            'professor': 'م.م شيماء خوام',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الأربعاء',
        'lectures': [
          {
            'subject': 'الإرشاد',
            'professor': 'م.م سوزان صالح',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'الشعر',
            'professor': 'م.م نسرين عبد العباس',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'المسرحية',
            'professor': 'م.م حسين علي هادي',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _groupBSchedule() {
    return [
      {
        'dayAr': 'الأحد',
        'lectures': [
          {
            'subject': 'الكتابة',
            'professor': 'م.م زيد علي عبد الرضا',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'الرواية',
            'professor': 'م.م علاء عبد الكاظم',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الاثنين',
        'lectures': [
          {
            'subject': 'علم اللغة',
            'professor': 'م.م بنين حميد',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'عقائد',
            'professor': 'م.د صدر الدين القبانجي',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'المحادثة',
            'professor': 'م.د خورشيد',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الثلاثاء',
        'lectures': [
          {
            'subject': 'النحو',
            'professor': 'م.م شيماء خوام',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'طرائق التدريس',
            'professor': 'م.د علي تقي',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الأربعاء',
        'lectures': [
          {
            'subject': 'المسرحية',
            'professor': 'م.م حسين علي هادي',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'الإرشاد',
            'professor': 'م.م سوزان صالح',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'الشعر',
            'professor': 'م.م نسرين عبد العباس',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _groupCSchedule() {
    return [
      {
        'dayAr': 'الأحد',
        'lectures': [
          {
            'subject': 'الشعر',
            'professor': 'م.م نسرين عبد العباس',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'المحادثة',
            'professor': 'م.د خورشيد',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الاثنين',
        'lectures': [
          {
            'subject': 'الإرشاد',
            'professor': 'م.م سوزان صالح',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'عقائد',
            'professor': 'م.د صدر الدين القبانجي',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'طرائق التدريس',
            'professor': 'م.د علي تقي',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الثلاثاء',
        'lectures': [
          {
            'subject': 'المسرحية',
            'professor': 'م.م حسين علي هادي',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'علم اللغة',
            'professor': 'م.م بنين حميد',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الأربعاء',
        'lectures': [
          {
            'subject': 'النحو',
            'professor': 'م.م شيماء خوام',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'الكتابة',
            'professor': 'م.م زيد علي عبد الرضا',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'الرواية',
            'professor': 'م.م علاء عبد الكاظم',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _groupDSchedule() {
    return [
      {
        'dayAr': 'الأحد',
        'lectures': [
          {
            'subject': 'المحادثة',
            'professor': 'م.د خورشيد',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'الشعر',
            'professor': 'م.م نسرين عبد العباس',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الاثنين',
        'lectures': [
          {
            'subject': 'طرائق التدريس',
            'professor': 'م.د علي تقي',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'عقائد',
            'professor': 'م.د صدر الدين القبانجي',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'الإرشاد',
            'professor': 'م.م سوزان صالح',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الثلاثاء',
        'lectures': [
          {
            'subject': 'علم اللغة',
            'professor': 'م.م بنين حميد',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'المسرحية',
            'professor': 'م.م حسين علي هادي',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
      {
        'dayAr': 'الأربعاء',
        'lectures': [
          {
            'subject': 'الرواية',
            'professor': 'م.م علاء عبد الكاظم',
            'start': '08:30 AM',
            'end': '10:00 AM',
          },
          {
            'subject': 'النحو',
            'professor': 'م.م شيماء خوام',
            'start': '10:30 AM',
            'end': '12:00 PM',
          },
          {
            'subject': 'الكتابة',
            'professor': 'م.م زيد علي عبد الرضا',
            'start': '12:30 PM',
            'end': '02:00 PM',
          },
        ],
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final language = LanguageScope.of(context);
    final isArabic = language.isArabic;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          isArabic ? 'الجدول الأسبوعي' : 'Weekly Schedule',
          style: const TextStyle(
            color: textDark,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadSchedule(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            );
          }

          final schedule = snapshot.data ?? [];

          final totalLectures = schedule.fold<int>(
            0,
                (total, day) =>
            total + (day['lectures'] as List).length,
          );

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              18,
              8,
              18,
              30,
            ),
            children: [
              _ScheduleHeader(
                totalDays: schedule.length,
                totalLectures: totalLectures,
                isArabic: isArabic,
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Text(
                    isArabic
                        ? 'جدول المحاضرات'
                        : 'Class Schedule',
                    style: const TextStyle(
                      color: textDark,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
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
                      isArabic
                          ? '$totalLectures محاضرات'
                          : '$totalLectures Lectures',
                      style: const TextStyle(
                        color: primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...schedule.map(
                    (day) {
                  return _DayCard(
                    dayName: day['dayAr'] as String,
                    lectures:
                    List<Map<String, String>>.from(
                      day['lectures'] as List,
                    ),
                    isArabic: isArabic,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  final int totalDays;
  final int totalLectures;
  final bool isArabic;

  const _ScheduleHeader({
    required this.totalDays,
    required this.totalLectures,
    required this.isArabic,
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
            color:
            const Color(0xFF6C4CF1).withValues(alpha: 0.22),
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
                color:
                Colors.white.withValues(alpha: 0.08),
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
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withValues(alpha: 0.16),
                      borderRadius:
                      BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                      Colors.white.withValues(alpha: 0.15),
                      borderRadius:
                      BorderRadius.circular(30),
                    ),
                    child: Text(
                      isArabic
                          ? '$totalDays أيام'
                          : '$totalDays Days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                isArabic
                    ? 'الجدول الأسبوعي'
                    : 'Weekly Schedule',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                isArabic
                    ? 'تابع محاضراتك الدراسية طوال الأسبوع'
                    : 'Keep track of your lectures throughout the week',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _HeaderStat(
                    icon: Icons.menu_book_rounded,
                    value: '$totalLectures',
                    label:
                    isArabic ? 'محاضرات' : 'Lectures',
                  ),
                  const SizedBox(width: 10),
                  _HeaderStat(
                    icon: Icons.calendar_today_rounded,
                    value: '$totalDays',
                    label: isArabic ? 'أيام' : 'Days',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String dayName;
  final List<Map<String, String>> lectures;
  final bool isArabic;

  const _DayCard({
    required this.dayName,
    required this.lectures,
    required this.isArabic,
  });

  static const Color primary = Color(0xFF6C4CF1);

  String _dayName() {
    if (isArabic) return dayName;

    switch (dayName) {
      case 'الأحد':
        return 'Sunday';
      case 'الاثنين':
        return 'Monday';
      case 'الثلاثاء':
        return 'Tuesday';
      case 'الأربعاء':
        return 'Wednesday';
      default:
        return dayName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6C4CF1),
                      Color(0xFF8C63F7),
                    ],
                  ),
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayName(),
                      style: const TextStyle(
                        color: Color(0xFF181625),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isArabic
                          ? 'محاضرات الجامعة'
                          : 'University lectures',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EDFF),
                  borderRadius:
                  BorderRadius.circular(30),
                ),
                child: Text(
                  '${lectures.length}',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          ...lectures.asMap().entries.map(
                (entry) {
              final lecture = entry.value;

              return _LectureCard(
                number: entry.key + 1,
                subject: lecture['subject'] ?? '',
                professor:
                lecture['professor'] ?? '',
                start: lecture['start'] ?? '',
                end: lecture['end'] ?? '',
                isLast:
                entry.key == lectures.length - 1,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  final int number;
  final String subject;
  final String professor;
  final String start;
  final String end;
  final bool isLast;

  const _LectureCard({
    required this.number,
    required this.subject,
    required this.professor,
    required this.start,
    required this.end,
    required this.isLast,
  });

  String _formatTime(String value) {
    final raw = value.trim();

    if (raw.isEmpty) {
      return '';
    }

    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(raw);

    if (amPmMatch != null) {
      final hour =
          int.tryParse(amPmMatch.group(1)!) ?? 0;

      final minute = amPmMatch.group(2)!;

      final period =
      amPmMatch.group(3)!.toUpperCase();

      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    }

    final twentyFourHourMatch = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(raw);

    if (twentyFourHourMatch != null) {
      int hour =
          int.tryParse(twentyFourHourMatch.group(1)!) ?? 0;

      final minute = twentyFourHourMatch.group(2)!;

      final period = hour >= 12 ? 'PM' : 'AM';

      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }

      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    }

    return raw.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final formattedStart = _formatTime(start);
    final formattedEnd = _formatTime(end);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE8FF),
                    borderRadius:
                    BorderRadius.circular(11),
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xFF6C4CF1),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin:
                      const EdgeInsets.symmetric(
                        vertical: 5,
                      ),
                      color:
                      const Color(0xFFE7E1FA),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin:
              const EdgeInsets.only(bottom: 11),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FB),
                borderRadius:
                BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFEEEAF6),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF181625),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                          const Color(0xFFEDE8FF),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color:
                          Color(0xFF6C4CF1),
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 17,
                        color: Color(0xFF8A8494),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          professor,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF777280),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color:
                          Color(0xFF6C4CF1),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          formattedStart,
                          style: const TextStyle(
                            color: Color(0xFF383441),
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // السهم الصحيح للواجهة العربية
                        const Text(
                          '←',
                          style: TextStyle(
                            color:
                            Color(0xFF6C4CF1),
                            fontSize: 15,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),

                        const SizedBox(width: 8),
                        Text(
                          formattedEnd,
                          style: const TextStyle(
                            color: Color(0xFF383441),
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}