import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's physical attendance at an event (actual attendance).
///
/// This model maps to the 'checkins' Firestore collection, which stores
/// records of users who have physically attended events.
///
/// ## IMPORTANT: Check-ins are IMMUTABLE
/// Once a check-in record is created, it CANNOT be modified or deleted.
/// This immutability is critical for:
/// - Maintaining accurate attendance records for reporting
/// - Providing an audit trail that cannot be tampered with
/// - Supporting academic credit or participation tracking
/// - Ensuring data integrity for analytics
///
/// ## Firestore Collection: 'checkins' (Future Feature)
///
/// **Schema:**
/// - `eventId` (string, indexed): Reference to events collection
/// - `userId` (string, indexed): Reference to users collection
/// - `checkedInAt` (Timestamp): When the user checked in
/// - `checkedInBy` (string, optional): User ID of staff who performed check-in
///   - null: QR self-check-in by user
///   - string: Staff member who manually checked in the user
///
/// **Required Firestore Indexes:**
/// - Composite index: (eventId, userId) - for checking if user checked in
/// - Single field index: userId - for querying user's check-ins
/// - Single field index: eventId - for querying event's check-ins
///
/// **Purpose:**
/// - Record physical attendance at events
/// - Track actual attendance vs registrations
/// - Generate attendance reports
/// - Verify QR code scans (future feature)
///
/// **Lifecycle:**
/// - Created when user arrives at event and checks in
/// - IMMUTABLE (permanent attendance record, cannot be cancelled or modified)
/// - Separate from registration (which is MUTABLE and can be cancelled)
///
/// ## Registration vs Check-In Separation
///
/// **Registration (RegistrationModel):**
/// - Intent to attend (created days before event)
/// - MUTABLE: Can be cancelled or modified
/// - Used for capacity planning and notifications
/// - Stored in 'registrations' collection
///
/// **Check-In (CheckInModel):**
/// - Proof of attendance (created at event time)
/// - IMMUTABLE: Permanent record, cannot be changed
/// - Used for attendance verification and reports
/// - Stored in 'checkins' collection (separate from registrations)
///
/// This separation enables:
/// - Comparing registration vs attendance rates (no-show analysis)
/// - Tracking attendance patterns over time
/// - Immutable attendance records for audit purposes
/// - Different validation methods (QR vs manual)
///
/// ## Future QR Code Integration
///
/// This model is prepared for QR-based check-in functionality:
///
/// **QR Check-In Flow:**
/// 1. User registers for event (creates RegistrationModel)
/// 2. System generates unique QR code for user's registration
/// 3. At event, user scans QR code or staff scans user's QR code
/// 4. System validates QR code and creates CheckInModel (immutable)
/// 5. Confirmation shown to user and staff
///
/// **Future Fields for QR Support:**
/// - `qrCode`: The QR code value that was scanned
/// - `validationMethod`: 'qr_scan' | 'manual' | 'staff'
/// - `qrScannedAt`: Timestamp when QR was scanned (may differ from checkedInAt)
/// - `scannerDeviceId`: Device that performed the scan (for audit trail)
///
/// **QR Integration Points:**
/// - QR code generation: When user registers (RegistrationModel created)
/// - QR code validation: Before creating CheckInModel
/// - QR code scanning: Staff app or self-service kiosk
/// - Security: QR codes should be time-limited and signed to prevent forgery
///
/// **checkedInBy Field:**
/// The checkedInBy field distinguishes between check-in methods:
/// - null: QR self-check-in by user (automated)
/// - userId: Manual check-in by event staff (staff-assisted)
/// This supports both automated QR scanning and manual check-in workflows.
///
/// Validates Requirements: 3.1, 3.2, 3.3, 3.4, 3.5
class CheckInModel {
  final String id;
  final String eventId;
  final String userId;
  final DateTime checkedInAt;
  final String? checkedInBy;

  CheckInModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.checkedInAt,
    this.checkedInBy,
  });

  /// Deserializes a Firestore document into a CheckInModel instance.
  ///
  /// Converts Firestore Timestamp objects to DateTime objects.
  /// Provides default values for optional fields to prevent null errors.
  factory CheckInModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CheckInModel(
      id: id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      checkedInAt: data['checkedInAt'] != null
          ? (data['checkedInAt'] as Timestamp).toDate()
          : DateTime.now(),
      checkedInBy: data['checkedInBy'],
    );
  }

  /// Serializes the CheckInModel to a Firestore-compatible map.
  ///
  /// Converts DateTime objects to Firestore Timestamp objects.
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'checkedInAt': Timestamp.fromDate(checkedInAt),
      'checkedInBy': checkedInBy,
    };
  }
}
