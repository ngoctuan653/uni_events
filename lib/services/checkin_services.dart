import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/checkin_model.dart';
import 'package:rxdart/rxdart.dart';

/// Service for managing event check-ins via QR code scanning.
///
/// Handles QR-based check-in, manual check-in, and participant status queries.
class CheckInService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check in a user by scanning their QR code (which contains the registration ID)
  ///
  /// Returns a map with check-in result info.
  /// Throws if registration not found, already checked in, or invalid.
  Future<Map<String, dynamic>> checkInByQR(
    String registrationId, {
    required String expectedEventId,
  }) async {
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

    // Get user info for display
    final userDoc = await _db.collection('users').doc(userId).get();
    final userName = userDoc.exists
        ? (userDoc.data()?['name'] ?? 'Unknown')
        : 'Unknown';
    final studentId = userDoc.exists
        ? (userDoc.data()?['studentId'] ?? '')
        : '';

    return {
      'success': true,
      'userName': userName,
      'studentId': studentId,
      'eventId': eventId,
    };
  }

  /// Manual check-in (fallback when student doesn't have QR)
  Future<void> manualCheckIn(String eventId, String userId) async {
    final staffUser = _auth.currentUser;
    if (staffUser == null) throw Exception('Staff not logged in');

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
