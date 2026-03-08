import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's membership in a club (many-to-many relationship).
///
/// This model maps to the 'clubMembers' Firestore collection.
///
/// ## Firestore Collection: 'clubMembers'
///
/// **Schema:**
/// - `clubId` (string, indexed): Reference to clubs collection
/// - `userId` (string, indexed): Reference to users collection
/// - `role` (string): Member role in the club ('staff' or 'admin')
/// - `addedAt` (Timestamp): When the member was added
///
/// **Purpose:**
/// - Track which users belong to which clubs
/// - Manage club staff permissions (scan QR, view participants)
/// - Support many-to-many relationship between users and clubs
/// - Enable role-based access within clubs
class ClubMemberModel {
  final String id;
  final String clubId;
  final String userId;
  final String role; // 'staff' or 'admin'
  final DateTime addedAt;

  ClubMemberModel({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.role,
    required this.addedAt,
  });

  factory ClubMemberModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ClubMemberModel(
      id: id,
      clubId: data['clubId'] ?? '',
      userId: data['userId'] ?? '',
      role: data['role'] ?? 'staff',
      addedAt: data['addedAt'] != null
          ? (data['addedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clubId': clubId,
      'userId': userId,
      'role': role,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
