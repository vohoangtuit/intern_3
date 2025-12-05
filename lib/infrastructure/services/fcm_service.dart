import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level function for background notification response
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background action tap if needed
}

/// FCM Service for handling push notifications
/// Used for incoming video calls when app is in background/terminated
class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  /// Initialize FCM and get token
  Future<void> initialize() async {
    try {
      // Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationResponse(response);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Request permission for iOS
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
      });

      // Setup message handlers
      _setupMessageHandlers();
    } catch (e) {
      // debugPrint removed for production
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        if (response.actionId == 'accept') {
          _notificationController.add({
            'type': 'call_action',
            'action': 'accept',
            ...data,
          });
        } else if (response.actionId == 'decline') {
          _notificationController.add({
            'type': 'call_action',
            'action': 'decline',
            ...data,
          });
        } else {
          // Default tap - just open the call screen
          // Treat as incoming call to trigger the UI
          _notificationController.add({
            'type': 'incoming_call',
            ...data,
          });
        }
      } catch (e) {
        // Handle error
      }
    }
  }

  /// Show notification with Accept/Decline buttons
  Future<void> showIncomingCallNotification(Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'call_channel',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming video calls',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Incoming Call',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('accept', 'Accept', showsUserInterface: true, titleColor: Color.fromARGB(255, 0, 255, 0)),
        const AndroidNotificationAction('decline', 'Decline', showsUserInterface: true, titleColor: Color.fromARGB(255, 255, 0, 0)),
      ],
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      data.hashCode, // Unique ID
      'Incoming Call',
      '${data['callerName'] ?? 'Someone'} is calling...',
      platformChannelSpecifics,
      payload: jsonEncode(data),
    );
  }


  /// Save FCM token to Firestore for the current user
  Future<void> saveFCMTokenForUser(String userId) async {
    if (_fcmToken == null) {
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // debugPrint removed for production
    }
  }

  /// Get FCM token for a specific user
  Future<String?> getFCMTokenForUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final token = doc.data()?['fcmToken'] as String?;
      return token;
    } catch (e) {
      // debugPrint removed for production
      return null;
    }
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Handle messages when app is in FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleIncomingMessage(message);
    });

    // Handle notification tap when app is in BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleIncomingMessage(message);
    });

    // Check for initial message when app was opened from TERMINATED state
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleIncomingMessage(message);
      }
    });
  }

  /// Handle incoming FCM message
  void _handleIncomingMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'incoming_call') {
      // Show local notification with actions
      showIncomingCallNotification(data);

      // Emit to stream for UI to handle
      _notificationController.add({
        'type': 'incoming_call',
        'callId': data['callId'],
        'callerId': data['callerId'],
        'callerName': data['callerName'],
        'callerAvatar': data['callerAvatar'],
        'channelName': data['channelName'],
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _notificationController.close();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handling logic
}
