import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's registration for an event (intent to attend).
///
/// This model maps to the 'registrations' Firestore collection, which stores
/// records of users who have signed up for events.
///
/// ## IMPORTANT: Registrations are MUTABLE
/// Registration records CAN be modified or deleted (cancelled) before the event.
/// This mutability is important for:
/// - Allowing users to cancel their registration
/// - Managing waitlists when capacity changes
/// - Updating registration status (registered → cancelled → waitlist)
/// - Providing flexibility in event planning
///
/// ## Firestore Collection: 'registrations'
///
/// **Schema:**
/// - `eventId` (string, indexed): Reference to events collection
/// - `userId` (string, indexed): Reference to users collection
/// - `status` (string): Registration state
///   - 'registered': User is actively registered
///   - 'cancelled': User cancelled their registration
///   - 'waitlist': User is on waitlist (if event is full)
/// - `registeredAt` (Timestamp): When the user registered
///
/// **Required Firestore Indexes:**
/// - Composite index: (eventId, userId) - for checking if user is registered
/// - Single field index: userId - for querying user's registrations
/// - Single field index: eventId - for querying event's registrations
///
/// **Purpose:**
/// - Track which users have signed up for which events
/// - Manage event capacity and waitlists
/// - Send event notifications to registered users
/// - Display user's registered events in UI
///
/// **Lifecycle:**
/// - Created when user clicks "Register" button (days/weeks before event)
/// - MUTABLE: Can be cancelled or status updated before event
/// - Can be deleted (unregister) before event starts
/// - Separate from check-in (which is IMMUTABLE and created at event time)
///
/// ## Registration vs Check-In Separation
///
/// **Registration (RegistrationModel):**
/// - Intent to attend (created days before event)
/// - MUTABLE: Can be cancelled or modified
/// - Used for capacity planning and notifications
/// - Stored in 'registrations' collection
/// - Has status field (registered, cancelled, waitlist)
///
/// **Check-In (CheckInModel):**
/// - Proof of attendance (created at event time)
/// - IMMUTABLE: Permanent record, cannot be changed
/// - Used for attendance verification and reports
/// - Stored in 'checkins' collection (separate from registrations)
/// - No status field (existence = attended)
///
/// This separation enables:
/// - Comparing registration vs attendance rates (no-show analysis)
/// - Managing capacity before event starts (registrations)
/// - Tracking actual attendance for reports (check-ins)
/// - Different lifecycles: registrations are mutable, check-ins are immutable
/// - Analytics: registration count vs check-in count = no-show rate
///
/// ## Future QR Code Integration
///
/// When QR-based check-in is implemented:
/// 1. User registers for event (creates RegistrationModel)
/// 2. System generates unique QR code linked to this registration
/// 3. User displays QR code at event entrance
/// 4. Staff/system scans QR code and validates registration
/// 5. System creates CheckInModel (immutable attendance record)
///
/// The registration serves as the prerequisite for check-in - users must
/// be registered before they can check in.
///
/// Validates Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
class RegistrationModel {
  final String id;
  final String eventId;
  final String userId;
  final String status;
  final DateTime registeredAt;
  final String
  qrCode; // Unique QR code for check-in (equals registration doc ID)

  RegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.status,
    required this.registeredAt,
    this.qrCode = '',
  });

  factory RegistrationModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return RegistrationModel(
      id: id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'registered',
      registeredAt: data['registeredAt'] != null
          ? (data['registeredAt'] as Timestamp).toDate()
          : DateTime.now(),
      qrCode: data['qrCode'] ?? id, // Default to doc ID if not set
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'status': status,
      'registeredAt': Timestamp.fromDate(registeredAt),
      'qrCode': qrCode,
    };
  }
}
