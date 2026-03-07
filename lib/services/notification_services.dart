import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> init() async {
    // Request permission for iOS/Android (Android 13+ requires this)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

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

      // Subscribe to a global topic so EVERYONE gets notified when an event is created
      await _fcm.subscribeToTopic('all_events');
      print('Subscribed to topic: all_events');
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
}
