import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import '../screens/notification/notifications_screen.dart';

/// Top-level background message handler for FCM
/// This function is called when a message is received while the app is in background or terminated state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // GlobalKey for navigation from service
  static GlobalKey<NavigatorState>? navigatorKey;

  Future<void> init() async {
    // Skip FCM initialization on web platform
    if (kIsWeb) {
      print('Skipping FCM initialization on web platform');
      return;
    }

    // Step 1: Initialize local notifications plugin
    await _initializeLocalNotifications();

    // Step 2: Request permission for iOS/Android (Android 13+ requires this)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Step 3: Set foreground notification presentation options for iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Step 4: Log permission grant or denial
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get the FCM token
      String? token = await _fcm.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await saveTokenToDatabase(token);
      }

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        saveTokenToDatabase(newToken);
      });

      // Step 5: Set up foreground message handler
      _setupForegroundMessageHandler();

      // Step 6: Set up notification tap handler
      _setupNotificationTapHandler();

      // Step 7: Subscribe to "all_events" topic
      try {
        await _fcm.subscribeToTopic('all_events');
        print('Successfully subscribed to topic: all_events');
      } catch (e) {
        print('Failed to subscribe to topic all_events: $e');
        // Continue app initialization even if subscription fails
        // Subscription will be retried on next app launch
      }

      // Note: Removed _listenToFirestoreNotifications() here because we now use
      // real FCM push notifications which handle both background and foreground
      // natively. Listening to the Firestore collection would cause duplicate
      // notifications.
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // Save the FCM token to the user's document in Firestore
  Future<void> saveTokenToDatabase(String token) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _db.collection('users').doc(user.uid).update({'fcmToken': token});
      } catch (e) {
        print("Error saving FCM token: $e");
      }
    }
  }

  /// Initialize flutter_local_notifications plugin
  /// Configures Android notification channel and iOS notification settings
  Future<void> _initializeLocalNotifications() async {
    // Configure Android notification channel with MAX importance
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'Event Notifications', // name
      description: 'Notifications for event updates',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Configure iOS notification settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Configure Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Combine platform-specific settings
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    // Initialize the plugin with tap callback
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle local notification tap (foreground notifications)
        print('Local notification tapped: ${response.payload}');
        _navigateToNotificationsScreen();
      },
    );
  }

  /// Set up foreground message handler
  /// Listens to FirebaseMessaging.onMessage stream and displays local notifications
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        print('Received foreground message: ${message.messageId}');

        // Save notification to Firestore immediately when received
        createNotificationRecord(message);

        // Extract title and body from RemoteMessage
        final notification = message.notification;
        if (notification != null) {
          final title = notification.title;
          final body = notification.body;

          if (title != null) {
            print('Notification title: $title');
          }

          // Display local notification with high priority
          _showLocalNotificationHighPriority(
            title ?? 'Event Notification',
            body ?? 'You have a new event update',
          );
        }
      } catch (e) {
        print('Error processing foreground message ${message.messageId}: $e');
      }
    });
  }

  /// Display high priority local notification for foreground messages
  Future<void> _showLocalNotificationHighPriority(
    String title,
    String body,
  ) async {
    try {
      print(
        '_showLocalNotificationHighPriority called - Title: $title, Body: $body',
      );

      // Configure Android notification details with MAXIMUM priority
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'high_importance_channel',
            'Event Notifications',
            channelDescription: 'Notifications for event updates',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showWhen: true,
            visibility: NotificationVisibility.public,
            ticker: 'Event Update',
          );

      // Configure iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combine platform-specific details
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch;

      print('Calling _localNotifications.show with ID: $notificationId');

      // Show the notification
      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformDetails,
      );

      print('High priority notification shown successfully');
    } catch (e) {
      print('Error showing high priority notification: $e');
    }
  }

  /// Display local notification for foreground messages
  /// Extracts notification data and displays using platform-specific styling
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      print('_showLocalNotification called for message: ${message.messageId}');

      final notification = message.notification;
      if (notification == null) {
        print('No notification payload in message');
        return;
      }

      // Extract notification data
      final title = notification.title ?? 'Event Notification';
      final body = notification.body ?? 'You have a new event update';

      print('Showing notification - Title: $title, Body: $body');

      // Configure Android notification details
      const AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        'high_importance_channel', // Must match the channel ID created in _initializeLocalNotifications
        'Event Notifications',
        channelDescription: 'Notifications for event updates',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      // Configure iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Combine platform-specific details
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique notification ID from message ID
      final notificationId =
          message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

      print('Calling _localNotifications.show with ID: $notificationId');

      // Show the notification
      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformDetails,
      );

      print('Notification shown successfully');
    } catch (e) {
      print(
        'Error showing local notification for message ${message.messageId}: $e',
      );
    }
  }

  /// Set up notification tap handlers
  /// Handles taps on notifications in all app states (foreground, background, terminated)
  void _setupNotificationTapHandler() {
    // Handle notification taps for local notifications (foreground)
    // This requires passing a callback during initialization
    // We'll need to update _initializeLocalNotifications to include this

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      try {
        print('Notification tapped (background): ${message.messageId}');
        _handleNotificationTap(message);
      } catch (e) {
        print(
          'Error handling notification tap (background) for message ${message.messageId}: $e',
        );
      }
    });

    // Handle notification tap that launched the app from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        try {
          print('Notification tapped (terminated): ${message.messageId}');
          _handleNotificationTap(message);
        } catch (e) {
          print(
            'Error handling notification tap (terminated) for message ${message.messageId}: $e',
          );
        }
      }
    });
  }

  /// Create a notification record in Firestore from FCM RemoteMessage
  /// Extracts event data from message.data and persists to user_notifications collection
  Future<void> createNotificationRecord(RemoteMessage message) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('Cannot create notification record: User not authenticated');
        return;
      }

      // Extract event data from message.data
      final data = message.data;
      final eventId = data['eventId'] as String?;
      final eventName = data['eventName'] as String?;
      final type = data['type'] as String?;

      // Extract message body from notification
      final messageBody = message.notification?.body ?? 'Event update';

      // Validate required fields
      if (eventId == null || eventName == null || type == null) {
        print(
          'Cannot create notification record: Missing required fields in message data',
        );
        return;
      }

      // Create document in user_notifications collection
      await _db.collection('user_notifications').add({
        'userId': user.uid,
        'eventId': eventId,
        'eventTitle': eventName,
        'type': type,
        'message': messageBody,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Created notification record for event: $eventName');
    } catch (e) {
      print('Error creating notification record: $e');
    }
  }

  /// Handle notification tap by navigating to NotificationsScreen
  /// This is called when user taps a notification in any state
  void _handleNotificationTap(RemoteMessage message) {
    try {
      print('Handling notification tap for message: ${message.messageId}');
      // Persist notification to Firestore
      createNotificationRecord(message);
      _navigateToNotificationsScreen();
    } catch (e) {
      print(
        'Error handling notification tap for message ${message.messageId}: $e',
      );
    }
  }

  /// Navigate to NotificationsScreen using the global navigator key
  void _navigateToNotificationsScreen() {
    final context = navigatorKey?.currentContext;
    if (context != null) {
      // Import the NotificationsScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
    } else {
      print('Navigator context not available for navigation');
    }
  }

  /// Get user notifications stream (sorted client-side to avoid composite index)
  Stream<List<Map<String, dynamic>>> getUserNotifications() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('user_notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          // Sort client-side (newest first)
          list.sort((a, b) {
            final aTime = a['createdAt'] as Timestamp?;
            final bTime = b['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          return list;
        });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _db.collection('user_notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  /// Get unread notification count stream
  Stream<int> getUnreadCount() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _db
        .collection('user_notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Firebase project ID (from service-account.json)
  static const String _projectId = 'uni-events-72162';

  /// Send a push notification to a specific user via FCM V1 API
  ///
  /// Uses Service Account credentials (assets/service-account.json)
  /// to authenticate with FCM V1 API.
  Future<void> sendPushToUser({
    required String targetUserId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, String>? extraData,
  }) async {
    try {
      // Get target user's FCM token
      final userDoc = await _db.collection('users').doc(targetUserId).get();
      if (!userDoc.exists) {
        print('Cannot send push: user $targetUserId not found');
        return;
      }

      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        print('Cannot send push: user $targetUserId has no FCM token');
        return;
      }

      // Load Service Account credentials
      final serviceAccountJson = await rootBundle.loadString(
        'assets/service-account.json',
      );
      final serviceAccount = ServiceAccountCredentials.fromJson(
        jsonDecode(serviceAccountJson),
      );

      // Get OAuth2 access token
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final authClient = await clientViaServiceAccount(serviceAccount, scopes);

      // Build FCM V1 payload
      final payload = {
        'message': {
          'token': fcmToken,
          'notification': {'title': title, 'body': body},
          'data': {
            'type': type,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            ...?extraData,
          },
          'android': {
            'priority': 'HIGH',
            'notification': {
              'sound': 'default',
              'channel_id': 'high_importance_channel',
            },
          },
        },
      };

      // Send via FCM V1 API
      final response = await authClient.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      authClient.close();

      if (response.statusCode == 200) {
        print('Push notification sent to user $targetUserId');
      } else {
        print('FCM V1 send failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }
}
