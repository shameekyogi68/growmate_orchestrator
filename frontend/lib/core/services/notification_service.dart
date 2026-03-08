import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Android Notification Channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  Future<void> initialize() async {
    try {
      // 1. Request Permissions (FCM Side)
      await _requestPermissions();

      // 2. Initialize Timezone for Scheduling (Wrap in try because TZ often fails on emulators/certain devices)
      try {
        tz.initializeTimeZones();
        final String timeZoneName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        debugPrint('Timezone initialization failed: $e');
      }

      // 3. Initialize Local Notifications (Wait for explicit Android 13 grant)
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      bool? initialized = await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationAction(details.payload, details.actionId);
        },
      );
      debugPrint('Local Notifications initialized: $initialized');

      // 4. Create Android Channels
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Android 13+ requires explicit request for this plugin too
        await androidPlugin?.requestNotificationsPermission();

        await androidPlugin?.createNotificationChannel(_channel);
        await androidPlugin?.createNotificationChannel(
          const AndroidNotificationChannel(
            'engagement_channel',
            'Farm Tips & Updates',
            description: 'Non-critical daily tips and market updates.',
            importance: Importance.defaultImportance,
          ),
        );
      }

      // 5. Listen for token refreshes automatically (Ensures high reliability)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token Refreshed (system triggered): $newToken');
      });

      // 6. Setup Listeners
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
    } catch (e) {
      debugPrint('CRITICAL: Notification Service failed to initialize: $e');
    }
  }

  void _handleNotificationAction(String? payload, String? actionId) {
    debugPrint('Notification Action: $actionId, Payload: $payload');
  }

  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );
      debugPrint('FCM Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM Permission request error: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNS Token is null (iOS)');
          return null;
        }
      }
      final token = await _fcm.getToken();
      debugPrint('FCM Token Generated: ${token?.substring(0, 10)}...');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    if (notification != null) {
      try {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              data['priority'] == 'HIGH' ? _channel.id : 'engagement_channel',
              data['priority'] == 'HIGH' ? _channel.name : 'Farm Tips',
              channelDescription: _channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
              fullScreenIntent:
                  true, // Force it to pop on top of the current screen
              styleInformation: BigTextStyleInformation(
                notification.body ?? '',
              ),
              actions: [
                if (data['priority'] == 'HIGH')
                  const AndroidNotificationAction(
                    'view_advisory',
                    'View Advisory',
                  ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: data['route'],
        );
      } catch (e) {
        debugPrint('Error showing local notification: $e');
      }
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      // Navigate to specific screen based on data payload
      print('Navigating to: $route');
    }
  }

  /// Schedules a local notification to appear after [duration]
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required Duration duration,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(duration),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules a repeating daily reminder at a specific time
  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Schedules repeating reminders every 2 hours during the daytime (8 AM to 8 PM)
  Future<void> scheduleTwoHourCycle() async {
    // 1. Clear old engagement notifications to prevent duplicates
    for (int i = 1000; i < 1010; i++) {
      await _localNotifications.cancel(i);
    }

    final now = tz.TZDateTime.now(tz.local);

    // Engagement content to keep it interesting
    final contents = [
      {
        "t": "Weather Check ☁️",
        "b": "Check the cloud cover for your farm area now.",
      },
      {
        "t": "Mandi Prices 🌾",
        "b": "Udupi market prices were just updated. See them now!",
      },
      {
        "t": "Crop Health 🔍",
        "b": "Any change in your Paddy leaves? Take a photo for the AI.",
      },
      {
        "t": "Watering Tip 💧",
        "b": "Early morning is the best time. See your soil advice.",
      },
      {
        "t": "Pest Watch 🐜",
        "b": "High humidity today. Check for signs of Stem Borer.",
      },
      {
        "t": "GrowMate Community 👩‍🌾",
        "b": "Other farmers are sowing MO-4. See why.",
      },
    ];

    // Schedule 6 slots, 2 hours apart
    for (int i = 0; i < 6; i++) {
      int hourDelay = (i + 1) * 2;

      // We only want to notify if the farmer is awake (e.g., between 8am and 9pm)
      tz.TZDateTime scheduledTime = now.add(Duration(hours: hourDelay));

      if (scheduledTime.hour >= 8 && scheduledTime.hour <= 21) {
        await scheduleNotification(
          id: 1000 + i,
          title: contents[i % contents.length]["t"]!,
          body: contents[i % contents.length]["b"]!,
          duration: Duration(hours: hourDelay),
        );
      }
    }
    print("Scheduled 2-hour engagement cycle for the next 12 hours.");
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}

// Global background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}
