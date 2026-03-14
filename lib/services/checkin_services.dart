import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/checkin_model.dart';
import 'package:rxdart/rxdart.dart';
import 'notification_services.dart';

/// Service for managing event check-ins via QR code scanning.
///
/// Handles QR-based check-in, manual check-in, and participant status queries.
class CheckInService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// Validate if check-in is allowed based on event time window
  Future<Map<String, dynamic>> _validateCheckInTimeWindow(
    String eventId,
  ) async {
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (!eventDoc.exists) {
      throw Exception('Event not found.');
    }

    final eventData = eventDoc.data()!;

    // Check if event has date information
    // Support both startDate/endDate (old) and startTime/endTime (new)
    final startDateTimestamp =
        eventData['startDate'] as Timestamp? ??
        eventData['startTime'] as Timestamp?;
    final endDateTimestamp =
        eventData['endDate'] as Timestamp? ??
        eventData['endTime'] as Timestamp?;

    if (startDateTimestamp != null && endDateTimestamp != null) {
      final startDate = startDateTimestamp.toDate();
      final endDate = endDateTimestamp.toDate();
      final now = DateTime.now();

      print('🕐 Check-in time validation:');
      print('   Now: $now');
      print('   Event starts: $startDate');
      print('   Event ends: $endDate');

      // Check if event has started
      if (now.isBefore(startDate)) {
        final daysUntil = startDate.difference(now).inDays;
        final hoursUntil = startDate.difference(now).inHours;

        print('❌ Check-in blocked: Event has not started yet');

        if (daysUntil > 0) {
          throw Exception(
            'Check-in not available yet. Event starts in $daysUntil day${daysUntil > 1 ? 's' : ''}.',
          );
        } else {
          throw Exception(
            'Check-in not available yet. Event starts in $hoursUntil hour${hoursUntil > 1 ? 's' : ''}.',
          );
        }
      }

      // Check if event has ended
      if (now.isAfter(endDate)) {
        print('❌ Check-in blocked: Event has already ended');
        throw Exception(
          'This event has already ended. Check-in is no longer available.',
        );
      }

      print('✅ Check-in allowed: Event is currently active');
    } else {
      // If no dates set, allow check-in (backward compatibility)
      print('⚠️ Event has no start/end dates, allowing check-in');
    }

    return eventData;
  }

  /// Check in a user by scanning their QR code (which contains the registration ID)
  ///
  /// Returns a map with check-in result info.
  /// Throws if registration not found, already checked in, or invalid.
  Future<Map<String, dynamic>> checkInByQR(
    String registrationId, {
    required String expectedEventId,
  }) async {
    print('🔍 checkInByQR called with registrationId: $registrationId');

    final staffUser = _auth.currentUser;
    if (staffUser == null) throw Exception('Staff not logged in');

    // Find the registration
    final regDoc = await _db
        .collection('registrations')
        .doc(registrationId)
        .get();

    if (!regDoc.exists) {
      throw Exception('Invalid QR code. Registration not found.');
    }

    final regData = regDoc.data()!;
    final eventId = regData['eventId'] as String;
    final userId = regData['userId'] as String;

    // Validate QR belongs to this event
    if (eventId != expectedEventId) {
      throw Exception('This QR code is for a different event.');
    }

    // Validate check-in time window and get event data
    final eventData = await _validateCheckInTimeWindow(eventId);

    // Check if already checked in
    final existingCheckin = await _db
        .collection('checkins')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    if (existingCheckin.docs.isNotEmpty) {
      throw Exception('This student has already checked in.');
    }

    // Create check-in record
    final checkin = CheckInModel(
      id: '',
      eventId: eventId,
      userId: userId,
      checkedInAt: DateTime.now(),
      checkedInBy: staffUser.uid,
    );

    await _db.collection('checkins').add(checkin.toMap());
    print('✅ Check-in record created for user: $userId');

    // Get user info for display
    final userDoc = await _db.collection('users').doc(userId).get();
    final userName = userDoc.exists
        ? (userDoc.data()?['name'] ?? 'Unknown')
        : 'Unknown';
    final studentId = userDoc.exists
        ? (userDoc.data()?['studentId'] ?? '')
        : '';

    // Get event title (already fetched above for validation)
    final eventTitle = eventData['title'] ?? 'Event';

    // Send check-in success notification to student
    print(
      '📤 [QR Check-in] Sending notification to user: $userId for event: $eventTitle',
    );
    try {
      await _notificationService.sendPushToUser(
        targetUserId: userId,
        title: '✅ Check-in Successful',
        body: 'You have successfully checked in to "$eventTitle"',
        type: 'checkin_success',
        extraData: {
          'eventId': eventId,
          'eventName': eventTitle,
          'checkedInAt': DateTime.now().toIso8601String(),
        },
      );
      print('✅ [QR Check-in] Push notification sent successfully');

      // Save in-app notification
      await _db.collection('user_notifications').add({
        'userId': userId,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'type': 'checkin_success',
        'message': 'You have successfully checked in to "$eventTitle"',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ [QR Check-in] In-app notification saved');
    } catch (e) {
      print('❌ [QR Check-in] Error sending notification: $e');
      // Don't throw - check-in succeeded even if notification fails
    }

    return {
      'success': true,
      'userName': userName,
      'studentId': studentId,
      'eventId': eventId,
    };
  }

  /// Manual check-in (fallback when student doesn't have QR)
  Future<void> manualCheckIn(String eventId, String userId) async {
    print('🔍 [Manual Check-in] Called for userId: $userId, eventId: $eventId');

    final staffUser = _auth.currentUser;
    if (staffUser == null) throw Exception('Staff not logged in');

    // Validate check-in time window and get event data
    final eventData = await _validateCheckInTimeWindow(eventId);

    // Check if already checked in
    final existingCheckin = await _db
        .collection('checkins')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    if (existingCheckin.docs.isNotEmpty) {
      throw Exception('This student has already checked in.');
    }

    // Verify user is registered
    final regSnapshot = await _db
        .collection('registrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    if (regSnapshot.docs.isEmpty) {
      throw Exception('Student is not registered for this event.');
    }

    // Create check-in record
    final checkin = CheckInModel(
      id: '',
      eventId: eventId,
      userId: userId,
      checkedInAt: DateTime.now(),
      checkedInBy: staffUser.uid,
    );

    await _db.collection('checkins').add(checkin.toMap());
    print('✅ [Manual Check-in] Check-in record created for user: $userId');

    // Get event info for notification (already fetched above)
    final eventTitle = eventData['title'] ?? 'Event';

    // Send check-in success notification to student
    print(
      '📤 [Manual Check-in] Sending notification to user: $userId for event: $eventTitle',
    );
    try {
      await _notificationService.sendPushToUser(
        targetUserId: userId,
        title: '✅ Check-in Successful',
        body: 'You have successfully checked in to "$eventTitle"',
        type: 'checkin_success',
        extraData: {
          'eventId': eventId,
          'eventName': eventTitle,
          'checkedInAt': DateTime.now().toIso8601String(),
        },
      );
      print('✅ [Manual Check-in] Push notification sent successfully');

      // Save in-app notification
      await _db.collection('user_notifications').add({
        'userId': userId,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'type': 'checkin_success',
        'message': 'You have successfully checked in to "$eventTitle"',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ [Manual Check-in] In-app notification saved');
    } catch (e) {
      print('❌ [Manual Check-in] Error sending notification: $e');
      // Don't throw - check-in succeeded even if notification fails
    }
  }

  /// Undo a check-in (staff made a mistake, scanned wrong person, etc.)
  Future<void> undoCheckIn(String eventId, String userId) async {
    final staffUser = _auth.currentUser;
    if (staffUser == null) throw Exception('Staff not logged in');

    final checkins = await _db
        .collection('checkins')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    if (checkins.docs.isEmpty) {
      throw Exception('No check-in record found for this user.');
    }

    // Delete all check-in records for this user/event
    for (var doc in checkins.docs) {
      await doc.reference.delete();
    }
  }

  /// Get participants with their check-in status (real-time stream)
  ///
  /// Combines BOTH registrations AND checkins streams so that
  /// check-in changes trigger an immediate UI update.
  Stream<List<Map<String, dynamic>>> getEventParticipantsWithStatus(
    String eventId,
  ) {
    final regStream = _db
        .collection('registrations')
        .where('eventId', isEqualTo: eventId)
        .snapshots();

    final checkinStream = _db
        .collection('checkins')
        .where('eventId', isEqualTo: eventId)
        .snapshots();

    // CombineLatest fires when EITHER stream emits a new value
    return Rx.combineLatest2<
          QuerySnapshot,
          QuerySnapshot,
          Future<List<Map<String, dynamic>>>
        >(regStream, checkinStream, (regSnapshot, checkinSnapshot) async {
          List<Map<String, dynamic>> participants = [];

          // Create a map of userId -> checkin data
          final checkinMap = <String, Map<String, dynamic>>{};
          for (var doc in checkinSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            checkinMap[data['userId']] = data;
          }

          for (var regDoc in regSnapshot.docs) {
            final regData = regDoc.data() as Map<String, dynamic>;
            final userId = regData['userId'] as String;

            // Get user info
            final userDoc = await _db.collection('users').doc(userId).get();
            final userData = userDoc.exists ? userDoc.data() : null;

            final checkinData = checkinMap[userId];
            final isCheckedIn = checkinData != null;

            participants.add({
              'registrationId': regDoc.id,
              'userId': userId,
              'name': userData?['name'] ?? 'Unknown',
              'email': userData?['email'] ?? '',
              'studentId': userData?['studentId'] ?? '',
              'avatar': userData?['avatar'],
              'isCheckedIn': isCheckedIn,
              'checkedInAt': isCheckedIn
                  ? (checkinData['checkedInAt'] as Timestamp).toDate()
                  : null,
            });
          }

          // Sort: checked-in first, then alphabetical
          participants.sort((a, b) {
            if (a['isCheckedIn'] != b['isCheckedIn']) {
              return a['isCheckedIn'] ? -1 : 1;
            }
            return (a['name'] as String).compareTo(b['name'] as String);
          });

          return participants;
        })
        .asyncMap((future) => future);
  }

  /// Get check-in count for an event
  Stream<int> getCheckInCountStream(String eventId) {
    return _db
        .collection('checkins')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
