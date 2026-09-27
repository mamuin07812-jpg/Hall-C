import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'firebase_options.dart';
import 'login_page.dart';
import 'language_controller.dart';
import 'app_settings.dart';
import 'account_gate.dart';
import 'notification_service.dart';

final FlutterLocalNotificationsPlugin
flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel notificationChannel =
AndroidNotificationChannel(
  'classroom_hub_notifications',
  'Classroom Hub Notifications',
  description: 'Notifications for Classroom Hub',
  importance: Importance.high,
);

StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
_firestoreNotificationSubscription;

bool _firestoreInitialSnapshotHandled = false;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'Background notification: ${message.notification?.title}',
  );
}

Future<void> _initializeLocalNotifications() async {
  const androidSettings =
  AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );

  const initializationSettings =
  InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  final androidPlugin =
  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    notificationChannel,
  );
}

Future<void> _showForegroundNotification(
    RemoteMessage message,
    ) async {
  final notification = message.notification;

  if (notification == null) {
    return;
  }

  const androidDetails =
  AndroidNotificationDetails(
    'classroom_hub_notifications',
    'Classroom Hub Notifications',
    channelDescription:
    'Notifications for Classroom Hub',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const notificationDetails =
  NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: notification.hashCode,
    title:
    notification.title ?? 'Classroom Hub',
    body:
    notification.body ?? '',
    notificationDetails:
    notificationDetails,
    payload:
    message.data.toString(),
  );
}

Future<void> _showFirestoreNotification(
    String title,
    String body,
    ) async {
  if (title.trim().isEmpty &&
      body.trim().isEmpty) {
    return;
  }

  const androidDetails =
  AndroidNotificationDetails(
    'classroom_hub_notifications',
    'Classroom Hub Notifications',
    channelDescription:
    'Notifications for Classroom Hub',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const notificationDetails =
  NotificationDetails(
    android: androidDetails,
  );

  final notificationId =
      DateTime.now()
          .millisecondsSinceEpoch %
          2147483647;

  await flutterLocalNotificationsPlugin.show(
    id: notificationId,
    title: title.trim().isEmpty
        ? 'Classroom Hub'
        : title.trim(),
    body: body.trim(),
    notificationDetails:
    notificationDetails,
  );
}

void _startFirestoreNotificationListener() {
  if (kIsWeb) {
    return;
  }

  if (_firestoreNotificationSubscription !=
      null) {
    return;
  }

  _firestoreInitialSnapshotHandled =
  false;

  _firestoreNotificationSubscription =
      FirebaseFirestore.instance
          .collection('notifications')
          .orderBy(
        'createdAt',
        descending: true,
      )
          .limit(20)
          .snapshots()
          .listen(
            (snapshot) async {
          if (!_firestoreInitialSnapshotHandled) {
            _firestoreInitialSnapshotHandled =
            true;

            debugPrint(
              'Firestore notification listener initialized.',
            );

            return;
          }

          for (final change
          in snapshot.docChanges) {
            if (change.type !=
                DocumentChangeType.added) {
              continue;
            }

            final data =
            change.doc.data();

            if (data == null) {
              continue;
            }

            final title =
                data['title']
                    ?.toString() ??
                    '';

            final body =
                data['body']
                    ?.toString() ??
                    '';

            final target =
                data['target']
                    ?.toString() ??
                    'all';

            final currentUser =
                FirebaseAuth
                    .instance
                    .currentUser;

            if (target != 'all' &&
                currentUser != null &&
                target != currentUser.uid) {
              continue;
            }

            if (target != 'all' &&
                currentUser == null) {
              continue;
            }

            debugPrint(
              'Firestore notification received: '
                  '$title',
            );

            await _showFirestoreNotification(
              title,
              body,
            );
          }
        },
        onError: (error) {
          debugPrint(
            'Firestore notification listener error: '
                '$error',
          );
        },
      );
}

Future<void> _initializeNotifications() async {
  if (kIsWeb) {
    return;
  }

  await _initializeLocalNotifications();

  await NotificationService.initialize();

  final messaging =
      FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    announcement: false,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) async {
      debugPrint(
        'Foreground notification: '
            '${message.notification?.title}',
      );

      debugPrint(
        'Foreground notification body: '
            '${message.notification?.body}',
      );

      await _showForegroundNotification(
        message,
      );
    },
  );

  FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
      debugPrint(
        'Notification opened: '
            '${message.notification?.title}',
      );
    },
  );

  final initialMessage =
  await messaging.getInitialMessage();

  if (initialMessage != null) {
    debugPrint(
      'App opened from notification: '
          '${initialMessage.notification?.title}',
    );
  }

  await NotificationService.syncFcmToken();

  await NotificationService
      .rescheduleLectureReminders();

  _startFirestoreNotificationListener();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp(
      options:
      DefaultFirebaseOptions.currentPlatform,
    );

    await _initializeNotifications();
  }

  await supabase.Supabase.initialize(
    url:
    'https://gxlgtqywfhkczujcisaf.supabase.co',
    publishableKey:
    'sb_publishable_1JZJvLj4wwbFSHv3AI1Gpw_9_kccxKR',
  );

  final languageController =
  LanguageController();

  await languageController.loadLanguage();

  final settingsController =
  AppSettingsController();

  await settingsController.loadSettings();

  runApp(
    LanguageScope(
      controller: languageController,
      child: SettingsScope(
        controller: settingsController,
        child: const ClassroomHubApp(),
      ),
    ),
  );
}

class ClassroomHubApp
    extends StatelessWidget {
  const ClassroomHubApp({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final languageController =
    LanguageScope.of(context);

    final settingsController =
    SettingsScope.of(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClassroomHub',
      locale:
      languageController.locale,
      themeMode:
      settingsController.themeMode,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (
          context,
          child,
          ) {
        return Directionality(
          textDirection:
          languageController.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child:
          child ??
              const SizedBox(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed:
        Colors.deepPurple,
        brightness:
        Brightness.light,
        scaffoldBackgroundColor:
        const Color(0xFFF7F7FC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed:
        Colors.deepPurple,
        brightness:
        Brightness.dark,
        scaffoldBackgroundColor:
        const Color(0xFF0F0E16),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate
    extends StatelessWidget {
  const AuthGate({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return StreamBuilder<User?>(
      stream:
      FirebaseAuth.instance
          .authStateChanges(),
      builder: (
          context,
          snapshot,
          ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const AccountGate();
        }

        return const LoginPage();
      },
    );
  }
}