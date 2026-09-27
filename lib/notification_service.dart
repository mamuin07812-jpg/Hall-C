import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin
  _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel
  _lectureChannel =
  AndroidNotificationChannel(
    'classroom_hub_lecture_reminders',
    'Lecture Reminders',
    description:
    'Reminders for upcoming Classroom Hub lectures',
    importance: Importance.high,
  );

  static const String _timezoneName =
      'Asia/Baghdad';

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || _initialized) {
      return;
    }

    tz.initializeTimeZones();

    try {
      tz.setLocalLocation(
        tz.getLocation(_timezoneName),
      );
    } catch (e) {
      debugPrint(
        'Timezone initialization error: $e',
      );
    }

    const androidSettings =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings =
    InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
    );

    final androidPlugin =
    _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      _lectureChannel,
    );

    _initialized = true;

    debugPrint(
      'NotificationService initialized.',
    );
  }

  static Future<void> syncFcmToken() async {
    if (kIsWeb) {
      return;
    }

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint(
          'FCM token not synced: no signed-in user.',
        );
        return;
      }

      final token =
      await FirebaseMessaging.instance.getToken();

      if (token == null ||
          token.trim().isEmpty) {
        debugPrint(
          'FCM token is null or empty.',
        );
        return;
      }

      await _saveToken(
        uid: user.uid,
        token: token,
      );

      FirebaseMessaging.instance.onTokenRefresh.listen(
            (newToken) async {
          if (newToken.trim().isEmpty) {
            return;
          }

          final currentUser =
              FirebaseAuth.instance.currentUser;

          if (currentUser == null) {
            return;
          }

          await _saveToken(
            uid: currentUser.uid,
            token: newToken,
          );
        },
      );

      debugPrint(
        'FCM token saved successfully.',
      );
    } catch (e) {
      debugPrint(
        'FCM token sync error: $e',
      );
    }
  }

  static Future<void> _saveToken({
    required String uid,
    required String token,
  }) async {
    final tokenReference =
    FirebaseFirestore.instance
        .collection('notification_tokens')
        .doc(token);

    await tokenReference.set(
      {
        'uid': uid,
        'token': token,
        'platform':
        defaultTargetPlatform.name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  static Future<void>
  rescheduleLectureReminders() async {
    if (kIsWeb) {
      return;
    }

    try {
      if (!_initialized) {
        await initialize();
      }

      await _localNotifications.cancelAll();

      final snapshot =
      await FirebaseFirestore.instance
          .collection('schedules')
          .get();

      int scheduledCount = 0;

      for (final document
      in snapshot.docs) {
        final data = document.data();

        final dayAr =
            data['dayAr']
                ?.toString()
                .trim() ??
                '';

        if (dayAr.isEmpty) {
          continue;
        }

        if (data['lectures'] is! List) {
          final subject =
              data['subject']
                  ?.toString()
                  .trim() ??
                  '';

          final start =
              data['startTime']
                  ?.toString()
                  .trim() ??
                  data['start']
                      ?.toString()
                      .trim() ??
                  '';

          if (subject.isEmpty ||
              start.isEmpty) {
            continue;
          }

          final success =
          await _scheduleLectureReminder(
            notificationKey:
            document.id,
            dayAr: dayAr,
            subject: subject,
            start: start,
          );

          if (success) {
            scheduledCount++;
          }

          continue;
        }

        final lectures =
        data['lectures'];

        if (lectures is! List) {
          continue;
        }

        for (int index = 0;
        index < lectures.length;
        index++) {
          final item =
          lectures[index];

          if (item is! Map) {
            continue;
          }

          final lecture =
          Map<String, dynamic>.from(
            item,
          );

          final subject =
              lecture['subject']
                  ?.toString()
                  .trim() ??
                  '';

          final start =
              lecture['startTime']
                  ?.toString()
                  .trim() ??
                  lecture['start']
                      ?.toString()
                      .trim() ??
                  '';

          if (subject.isEmpty ||
              start.isEmpty) {
            continue;
          }

          final success =
          await _scheduleLectureReminder(
            notificationKey:
            '${document.id}_$index',
            dayAr: dayAr,
            subject: subject,
            start: start,
          );

          if (success) {
            scheduledCount++;
          }
        }
      }

      debugPrint(
        'Lecture reminders scheduled: '
            '$scheduledCount',
      );
    } catch (e) {
      debugPrint(
        'Schedule reminders error: $e',
      );
    }
  }

  static Future<bool>
  _scheduleLectureReminder({
    required String notificationKey,
    required String dayAr,
    required String subject,
    required String start,
  }) async {
    final dayOfWeek =
    _arabicDayToWeekday(dayAr);

    if (dayOfWeek == null) {
      return false;
    }

    final lectureMinutes =
    _timeToMinutes(start);

    if (lectureMinutes == -1) {
      debugPrint(
        'Invalid lecture time: $start',
      );
      return false;
    }

    int reminderMinutes =
        lectureMinutes - 15;

    int dayOffset = 0;

    if (reminderMinutes < 0) {
      reminderMinutes +=
          24 * 60;
      dayOffset = -1;
    }

    final hour =
        reminderMinutes ~/ 60;

    final minute =
        reminderMinutes % 60;

    final now =
    tz.TZDateTime.now(
      tz.local,
    );

    final firstDate =
    _nextWeekdayAtTime(
      now: now,
      weekday: dayOfWeek,
      hour: hour,
      minute: minute,
    );

    final adjustedDate =
    firstDate.add(
      Duration(
        days: dayOffset,
      ),
    );

    final scheduledDate =
    adjustedDate.isAfter(now)
        ? adjustedDate
        : adjustedDate.add(
      const Duration(
        days: 7,
      ),
    );

    final notificationId =
    _notificationId(
      notificationKey,
    );

    const title =
        '⏰ تذكير بالمحاضرة';

    final body =
        'بعد 15 دقيقة تبدأ محاضرة $subject';

    const androidDetails =
    AndroidNotificationDetails(
      'classroom_hub_lecture_reminders',
      'Lecture Reminders',
      channelDescription:
      'Reminders for upcoming Classroom Hub lectures',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails =
    NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails:
      notificationDetails,
      androidScheduleMode:
      AndroidScheduleMode.exactAllowWhileIdle,
      payload:
      'lecture:$notificationKey',
      matchDateTimeComponents:
      DateTimeComponents
          .dayOfWeekAndTime,
    );

    debugPrint(
      'Scheduled reminder: '
          '$subject at $scheduledDate',
    );

    return true;
  }

  static tz.TZDateTime
  _nextWeekdayAtTime({
    required tz.TZDateTime now,
    required int weekday,
    required int hour,
    required int minute,
  }) {
    var daysUntil =
        weekday - now.weekday;

    if (daysUntil < 0) {
      daysUntil += 7;
    }

    var result = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(
      Duration(
        days: daysUntil,
      ),
    );

    if (!result.isAfter(now)) {
      result = result.add(
        const Duration(days: 7),
      );
    }

    return result;
  }

  static int?
  _arabicDayToWeekday(
      String day,
      ) {
    switch (day.trim()) {
      case 'الاثنين':
        return DateTime.monday;
      case 'الثلاثاء':
        return DateTime.tuesday;
      case 'الأربعاء':
        return DateTime.wednesday;
      case 'الخميس':
        return DateTime.thursday;
      case 'الجمعة':
        return DateTime.friday;
      case 'السبت':
        return DateTime.saturday;
      case 'الأحد':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  static int _timeToMinutes(
      String value,
      ) {
    final text =
    value.trim().toUpperCase();

    if (text.isEmpty) {
      return -1;
    }

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$',
    ).firstMatch(text);

    if (match == null) {
      return -1;
    }

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

  static int _notificationId(
      String value,
      ) {
    int hash = 0;

    for (final codeUnit
    in value.codeUnits) {
      hash =
      ((hash * 31) + codeUnit) &
      0x7FFFFFFF;
    }

    return hash == 0 ? 1 : hash;
  }
}