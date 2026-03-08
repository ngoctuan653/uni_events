import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a student club/organization that creates events.
///
/// This model maps to the 'clubs' Firestore collection (optional future enhancement),
/// which stores information about student clubs and organizations.
///
/// ## Firestore Collection: 'clubs' (Optional - Future Enhancement)
///
/// **Schema:**
/// - `name` (string): Club name
/// - `description` (string): Short description of the club
/// - `leaderId` (string): Reference to users collection (club leader)
/// - `history` (string): Club history text
/// - `introduction` (string): Club introduction text
/// - `avatar` (string, optional): Club logo/avatar URL
/// - `createdAt` (Timestamp): Club creation timestamp
/// - `updatedAt` (Timestamp): Last update timestamp
///
/// **Required Firestore Indexes:**
/// - Single field index: leaderId - for querying clubs by leader
///
/// **Purpose:**
/// - Store club information separately from UserModel
/// - Enable better scalability and data independence
/// - Support club-specific features (events, members, etc.)
/// - Manage club profiles and branding
///
/// **Current State:**
/// Currently, club data may be embedded in UserModel. This model prepares
/// the structure for separating club data into its own collection for better
/// scalability and maintainability.
///
/// **leaderId Field:**
/// The leaderId field references the users collection to identify the club
/// leader. This enables:
/// - Querying all clubs led by a specific user
/// - Managing club leadership changes
/// - Linking club events to club leaders
///
/// **Separation from UserModel:**
/// This model separates club data from UserModel for:
/// - Better data organization (clubs are entities, not user properties)
/// - Independent club lifecycle (clubs can exist beyond individual users)
/// - Scalability (clubs can have multiple members, events, etc.)
/// - Cleaner data model (users and clubs have different concerns)
///
/// Validates Requirements: 4.1, 4.2, 4.3, 4.4, 4.5
class ClubModel {
  final String id;
  final String name;
  final String description;
  final String leaderId; // References users collection (club leader)
  final String history;
  final String introduction;
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.leaderId,
    required this.history,
    required this.introduction,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserializes a Firestore document into a ClubModel instance.
  ///
  /// Converts Firestore Timestamp objects to DateTime objects.
  /// Provides default values for required fields to prevent null errors.
  factory ClubModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ClubModel(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      leaderId: data['leaderId'] ?? '',
      history: data['history'] ?? '',
      introduction: data['introduction'] ?? '',
      avatar: data['avatar'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Serializes the ClubModel to a Firestore-compatible map.
  ///
  /// Converts DateTime objects to Firestore Timestamp objects.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'leaderId': leaderId,
      'history': history,
      'introduction': introduction,
      'avatar': avatar,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
