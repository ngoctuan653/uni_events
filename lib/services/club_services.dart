import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club_member_model.dart';
import 'notification_services.dart';

/// Service for managing club staff membership.
///
/// Uses 'clubMembers' Firestore collection for many-to-many
/// relationship between users and clubs.
class ClubService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  /// Add a user as staff to a club
  Future<void> addStaff(String clubId, String userId) async {
    // Check if already a member
    final existing = await _db
        .collection('clubMembers')
        .where('clubId', isEqualTo: clubId)
        .where('userId', isEqualTo: userId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('User is already a staff member of this club');
    }

    final member = ClubMemberModel(
      id: '',
      clubId: clubId,
      userId: userId,
      role: 'staff',
      addedAt: DateTime.now(),
    );

    await _db.collection('clubMembers').add(member.toMap());

    // Get club name for notification
    String clubName = 'a club';
    try {
      final clubDoc = await _db.collection('users').doc(clubId).get();
      if (clubDoc.exists) {
        clubName = (clubDoc.data()?['name'] as String?) ?? 'a club';
      }
    } catch (_) {}

    final message =
        'You have been added as staff of $clubName. You can now manage check-ins for events.';

    // Save in-app notification
    await _db.collection('user_notifications').add({
      'userId': userId,
      'eventId': '',
      'eventTitle': clubName,
      'type': 'staff_promoted',
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send system push notification (works in background & terminated)
    await _notificationService.sendPushToUser(
      targetUserId: userId,
      title: 'Staff Promotion 🎉',
      body: message,
      type: 'staff_promoted',
    );
  }

  /// Remove a staff member from a club
  Future<void> removeStaff(String clubId, String userId) async {
    final snapshot = await _db
        .collection('clubMembers')
        .where('clubId', isEqualTo: clubId)
        .where('userId', isEqualTo: userId)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Get club name for notification
    String clubName = 'a club';
    try {
      final clubDoc = await _db.collection('users').doc(clubId).get();
      if (clubDoc.exists) {
        clubName = (clubDoc.data()?['name'] as String?) ?? 'a club';
      }
    } catch (_) {}

    final message = 'You have been removed from staff of $clubName.';

    // Save in-app notification
    await _db.collection('user_notifications').add({
      'userId': userId,
      'eventId': '',
      'eventTitle': clubName,
      'type': 'staff_removed',
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Send system push notification
    await _notificationService.sendPushToUser(
      targetUserId: userId,
      title: 'Staff Update',
      body: message,
      type: 'staff_removed',
    );
  }

  /// Get all members of a club (real-time stream)
  Stream<List<ClubMemberModel>> getClubMembers(String clubId) {
    return _db
        .collection('clubMembers')
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClubMemberModel.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Get all clubs a user belongs to
  Future<List<ClubMemberModel>> getUserClubMemberships(String userId) async {
    final snapshot = await _db
        .collection('clubMembers')
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((doc) => ClubMemberModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Check if user is staff or admin for a specific club
  Future<bool> isStaffOrAdmin(String userId, String clubId) async {
    final snapshot = await _db
        .collection('clubMembers')
        .where('clubId', isEqualTo: clubId)
        .where('userId', isEqualTo: userId)
        .get();

    if (snapshot.docs.isNotEmpty) return true;

    // Also check if user is the club leader (club_admin)
    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    if (clubDoc.exists) {
      final data = clubDoc.data();
      if (data != null && data['leaderId'] == userId) return true;
    }

    // Also check if clubId is a user doc (old system where club = user)
    final userDoc = await _db.collection('users').doc(clubId).get();
    if (userDoc.exists) {
      if (clubId == userId) return true;
    }

    return false;
  }

  /// Check if current user is staff/admin for a club
  Future<bool> isCurrentUserStaffOrAdmin(String clubId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return isStaffOrAdmin(user.uid, clubId);
  }

  /// Search users by email (for adding staff)
  Future<List<Map<String, dynamic>>> searchUserByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  /// Search users by studentId (for adding staff)
  Future<List<Map<String, dynamic>>> searchUserByStudentId(
    String studentId,
  ) async {
    final snapshot = await _db
        .collection('users')
        .where('studentId', isEqualTo: studentId)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }
}
