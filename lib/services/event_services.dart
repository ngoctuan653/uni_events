import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';
import '../models/registration_model.dart';
import 'notification_services.dart';
// CheckInModel is prepared for future QR-based attendance tracking feature.
// Uncomment when implementing check-in functionality. Check-ins are IMMUTABLE
// attendance records (separate from mutable registrations).
// import '../models/checkin_model.dart';
import '../untils/migration_config.dart';

/// Service for managing events and event registrations in Firestore.
///
/// This service interacts with the following Firestore collections:
///
/// ## Collection: 'registrations'
/// Stores user registrations for events (intent to attend).
///
/// **Schema:**
/// - `eventId` (string, indexed): Reference to events collection
/// - `userId` (string, indexed): Reference to users collection
/// - `status` (string): Registration state ('registered', 'cancelled', 'waitlist')
/// - `registeredAt` (Timestamp): When the user registered
///
/// **Required Indexes:**
/// - Composite index: (eventId, userId) - for checking if user is registered
/// - Single field index: userId - for querying user's registrations
/// - Single field index: eventId - for querying event's registrations
///
/// **Purpose:** Tracks which users have signed up for which events. Used for
/// capacity management, sending event notifications, and displaying user's
/// registered events.
///
/// ---
///
/// ## Collection: 'checkins' (Future Feature)
/// Stores user check-ins at events (actual attendance).
///
/// **Schema:**
/// - `eventId` (string, indexed): Reference to events collection
/// - `userId` (string, indexed): Reference to users collection
/// - `checkedInAt` (Timestamp): When the user checked in
/// - `checkedInBy` (string, optional): User ID of staff who performed check-in
///   (null for QR self-check-in)
///
/// **Required Indexes:**
/// - Composite index: (eventId, userId) - for checking if user checked in
/// - Single field index: userId - for querying user's check-ins
/// - Single field index: eventId - for querying event's check-ins
///
/// **Purpose:** Records physical attendance at events. Separate from registrations
/// to distinguish intent to attend (registration) from actual attendance (check-in).
/// Prepared for future QR-based attendance tracking.
///
/// **Registration vs Check-In:**
/// - Registration: Created when user clicks "Register" button (days before event)
/// - Check-In: Created when user arrives at event (at event time)
/// - Registrations are mutable (can be cancelled), check-ins are immutable
/// - Used for different purposes: registrations for planning, check-ins for verification
///
/// ---
///
/// ## Collection: 'clubs' (Optional - Future Enhancement)
/// Stores student club/organization information.
///
/// **Schema:**
/// - `name` (string): Club name
/// - `description` (string): Short description
/// - `leaderId` (string): Reference to users collection (club leader)
/// - `history` (string): Club history text
/// - `introduction` (string): Club introduction text
/// - `avatar` (string, optional): Club logo/avatar URL
/// - `createdAt` (Timestamp): Club creation timestamp
/// - `updatedAt` (Timestamp): Last update timestamp
///
/// **Purpose:** Separates club data from UserModel for better scalability and
/// data independence. Currently, club data may be embedded in UserModel.
///
/// ---
///
/// **Indexing Requirements:**
/// All collections that store user-specific data include a `userId` field for
/// efficient querying. All collections that store event-specific data include
/// an `eventId` field. Composite indexes on (eventId, userId) enable fast
/// lookups for checking registration/check-in status.
class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection name for event registrations
  /// Updated from 'eventRegistrations' to 'registrations' following Firebase naming conventions
  static const String _registrationsCollection = 'registrations';

  /// Deprecated collection name - used only for backward compatibility during migration
  static const String _deprecatedRegistrationsCollection = 'eventRegistrations';

  // ─── BACKWARD COMPATIBILITY HELPERS ───

  /// Helper method to query registrations with backward compatibility
  ///
  /// Checks both 'registrations' (new) and 'eventRegistrations' (deprecated) collections
  /// during migration period. Logs warnings when reading from deprecated collection.
  ///
  /// Returns a list of RegistrationModel objects from both collections, with duplicates
  /// removed (preferring new collection if same registration exists in both).
  Future<List<RegistrationModel>> _getRegistrationsWithBackwardCompatibility({
    String? eventId,
    String? userId,
  }) async {
    final Map<String, RegistrationModel> registrationsMap = {};

    // Query new collection
    Query<Map<String, dynamic>> newQuery = _db.collection(
      _registrationsCollection,
    );
    if (eventId != null) {
      newQuery = newQuery.where('eventId', isEqualTo: eventId);
    }
    if (userId != null) {
      newQuery = newQuery.where('userId', isEqualTo: userId);
    }

    final newSnapshot = await newQuery.get();
    for (var doc in newSnapshot.docs) {
      final registration = RegistrationModel.fromFirestore(doc.data(), doc.id);
      // Use composite key to identify unique registrations
      final key = '${registration.eventId}_${registration.userId}';
      registrationsMap[key] = registration;
    }

    // Query old collection during migration period
    if (MigrationConfig.enableBackwardCompatibility) {
      Query<Map<String, dynamic>> oldQuery = _db.collection(
        _deprecatedRegistrationsCollection,
      );
      if (eventId != null) {
        oldQuery = oldQuery.where('eventId', isEqualTo: eventId);
      }
      if (userId != null) {
        oldQuery = oldQuery.where('userId', isEqualTo: userId);
      }

      final oldSnapshot = await oldQuery.get();

      if (oldSnapshot.docs.isNotEmpty && MigrationConfig.logDeprecatedReads) {
        print(
          'Warning: Reading ${oldSnapshot.docs.length} registration(s) from deprecated collection "$_deprecatedRegistrationsCollection"'
          '${eventId != null ? ' for event $eventId' : ''}'
          '${userId != null ? ' for user $userId' : ''}',
        );
      }

      // Add registrations from old collection that don't exist in new collection
      for (var doc in oldSnapshot.docs) {
        final registration = RegistrationModel.fromFirestore(
          doc.data(),
          doc.id,
        );
        final key = '${registration.eventId}_${registration.userId}';
        // Only add if not already present from new collection
        if (!registrationsMap.containsKey(key)) {
          registrationsMap[key] = registration;
        }
      }
    }

    return registrationsMap.values.toList();
  }

  /// Helper method to check if a registration exists with backward compatibility
  ///
  /// Checks both collections during migration period and logs when deprecated
  /// collection is accessed.
  ///
  /// Returns true if registration exists in either collection.
  Future<bool> _registrationExists({
    required String eventId,
    required String userId,
  }) async {
    // Check new collection
    final newSnapshot = await _db
        .collection(_registrationsCollection)
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (newSnapshot.docs.isNotEmpty) {
      return true;
    }

    // Check old collection during migration period
    if (MigrationConfig.enableBackwardCompatibility) {
      final oldSnapshot = await _db
          .collection(_deprecatedRegistrationsCollection)
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (oldSnapshot.docs.isNotEmpty) {
        if (MigrationConfig.logDeprecatedReads) {
          print(
            'Warning: Found registration in deprecated collection "$_deprecatedRegistrationsCollection" '
            'for event $eventId and user $userId',
          );
        }
        return true;
      }
    }

    return false;
  }

  // CREATE EVENT
  Future<void> createEvent(Event event) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Create a new event with the creator and timestamps
    Event newEvent = Event(
      id: '', // Will be assigned by Firestore
      title: event.title,
      description: event.description,
      clubId: user.uid,
      location: event.location,
      startTime: event.startTime,
      endTime: event.endTime,
      capacity: event.capacity,
      participantCount: 0,
      image: event.image,
      createdBy: user.uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: event.status.isNotEmpty ? event.status : 'active',
      note: event.note,
    );

    try {
      DocumentReference docRef = await _db
          .collection('events')
          .add(newEvent.toMap());

      // Trigger a global push notification by writing to a 'notifications' collection.
      // A Firebase Cloud Function should be set up to listen to this collection
      // and send an FCM message to the 'all_events' topic.
      await _db.collection('notifications').add({
        'title': 'New Event: ${event.title}',
        'body': 'Tap to check out this new event!',
        'topic': 'all_events',
        'eventId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  // UPDATE EVENT
  Future<void> updateEvent(Event event) async {
    // Compare with old data to detect changes worth notifying
    final oldDoc = await _db.collection('events').doc(event.id).get();
    if (oldDoc.exists) {
      // Use Event.fromFirestore to deserialize old event data
      final oldEvent = Event.fromFirestore(oldDoc.data()!, oldDoc.id);
      final oldStatus = oldEvent.status;

      // 1. Status changed to inactive → notify "event cancelled"
      if (oldStatus != 'inactive' && event.status == 'inactive') {
        await _notifyRegisteredUsers(
          eventId: event.id,
          eventTitle: event.title,
          type: 'event_cancelled',
          message:
              'The event "${event.title}" has been deactivated by the organizer.',
        );
      }

      // 2. Status changed from inactive back to active → notify "event reactivated"
      if (oldStatus == 'inactive' && event.status != 'inactive') {
        await _notifyRegisteredUsers(
          eventId: event.id,
          eventTitle: event.title,
          type: 'event_reactivated',
          message:
              'The event "${event.title}" has been reactivated! It is now active again.',
        );
      }

      // 3. Date/time or location changed -> notify "event updated"
      final oldStart = oldEvent.startTime;
      final oldEnd = oldEvent.endTime;
      final newStart = event.startTime;
      final newEnd = event.endTime;

      bool dateChanged = false;
      if (oldStart != null && newStart != null) {
        dateChanged = oldStart != newStart;
      } else if ((oldStart == null) != (newStart == null)) {
        dateChanged = true;
      }
      if (!dateChanged && oldEnd != null && newEnd != null) {
        dateChanged = oldEnd != newEnd;
      }

      bool locationChanged = oldEvent.location != event.location;

      if ((dateChanged || locationChanged) && event.status != 'inactive') {
        String newDateStr = '';
        if (dateChanged && newStart != null) {
          newDateStr =
              '${newStart.day}/${newStart.month}/${newStart.year} ${newStart.hour}:${newStart.minute.toString().padLeft(2, '0')}';
        }

        String msg = 'The event "${event.title}" has been updated.';
        if (dateChanged && locationChanged) {
          msg =
              'The event "${event.title}" has been rescheduled${newDateStr.isNotEmpty ? ' to $newDateStr' : ''} and the location was changed to ${event.location}. Please check the new details.';
        } else if (dateChanged) {
          msg =
              'The event "${event.title}" has been rescheduled${newDateStr.isNotEmpty ? ' to $newDateStr' : ''}. Please check the new details.';
        } else if (locationChanged) {
          msg =
              'The location for event "${event.title}" has been changed to ${event.location}. Please check the new details.';
        }

        await _notifyRegisteredUsers(
          eventId: event.id,
          eventTitle: event.title,
          type: 'event_updated',
          message: msg,
        );
      }
    }

    Event updatedEvent = Event(
      id: event.id,
      title: event.title,
      description: event.description,
      clubId: event.clubId,
      location: event.location,
      startTime: event.startTime,
      endTime: event.endTime,
      capacity: event.capacity,
      participantCount: event.participantCount,
      image: event.image,
      createdBy: event.createdBy,
      createdAt: event.createdAt,
      updatedAt: DateTime.now(),
      status: event.status,
      note: event.note,
    );

    await _db.collection('events').doc(event.id).update(updatedEvent.toMap());
  }

  // DELETE EVENT
  Future<void> deleteEvent(String eventId) async {
    // Get event title before deleting
    final eventDoc = await _db.collection('events').doc(eventId).get();
    String eventTitle = 'Unknown Event';
    if (eventDoc.exists) {
      // Use Event.fromFirestore to deserialize event data
      final event = Event.fromFirestore(eventDoc.data()!, eventDoc.id);
      eventTitle = event.title;
    }

    // Notify registered users before deleting
    await _notifyRegisteredUsers(
      eventId: eventId,
      eventTitle: eventTitle,
      type: 'event_deleted',
      message: 'The event "$eventTitle" has been deleted by the organizer.',
    );

    // Delete the event
    await _db.collection('events').doc(eventId).delete();

    // Delete registrations from new collection
    var regs = await _db
        .collection(_registrationsCollection)
        .where('eventId', isEqualTo: eventId)
        .get();
    for (var doc in regs.docs) {
      await doc.reference.delete();
    }

    // Delete registrations from old collection (backward compatibility)
    if (MigrationConfig.enableBackwardCompatibility) {
      var oldRegs = await _db
          .collection(_deprecatedRegistrationsCollection)
          .where('eventId', isEqualTo: eventId)
          .get();
      for (var doc in oldRegs.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Notify all registered users of an event
  Future<void> _notifyRegisteredUsers({
    required String eventId,
    required String eventTitle,
    required String type,
    required String message,
  }) async {
    // Assuming NotificationService is imported and available in scope.
    // For this to be syntactically correct, you would need:
    // import 'package:your_app_path/services/notification_service.dart'; // or wherever it is
    // And an instance field like:
    // final NotificationService _notificationService = NotificationService();
    // in the class where this method resides.
    final notificationService = NotificationService();

    // Get all registrations using backward compatibility helper
    final registrations = await _getRegistrationsWithBackwardCompatibility(
      eventId: eventId,
    );

    // Write to user_notifications and send push for each user
    for (var registration in registrations) {
      await _db.collection('user_notifications').add({
        'userId': registration.userId,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'type': type,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send system push notification
      await notificationService.sendPushToUser(
        targetUserId: registration.userId,
        title: _getNotificationTitle(type, eventTitle),
        body: message,
        type: type,
        extraData: {'eventId': eventId, 'eventName': eventTitle},
      );
    }

    // Write to notifications collection for Firestore listener
    await _db.collection('notifications').add({
      'title': _getNotificationTitle(type, eventTitle),
      'body': message,
      'topic': 'all_events',
      'eventId': eventId,
      'eventName': eventTitle,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get notification title based on type
  String _getNotificationTitle(String type, String eventTitle) {
    switch (type) {
      case 'event_cancelled':
        return 'Event Cancelled';
      case 'event_reactivated':
        return 'Event Reactivated';
      case 'event_updated':
        return 'Event Updated';
      case 'event_deleted':
        return 'Event Deleted';
      default:
        return 'Event Notification';
    }
  }

  // GET MANAGED EVENTS
  Stream<List<Event>> getManagedEvents() {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _db
        .collection('events')
        .where('clubId', isEqualTo: user.uid)
        // .orderBy('startTime', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Event.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // GET EVENTS BY CLUB ID (public - for viewing any club's events)
  Stream<List<Event>> getEventsByClubId(String clubId) {
    return _db
        .collection('events')
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Event.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // GET ALL EVENTS
  Stream<List<Event>> getAllEvents() {
    return _db
        .collection('events')
        .where('status', whereIn: ['active', 'published'])
        // .orderBy('startTime', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Event.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  // ─── REGISTRATION ───
  //
  // REGISTRATION vs CHECK-IN SEPARATION
  //
  // This service maintains a clear separation between two distinct concepts:
  //
  // 1. REGISTRATION (Intent to Attend)
  //    - Created when user clicks "Register" button (days/weeks before event)
  //    - Stored in 'registrations' collection
  //    - MUTABLE: Users can cancel/modify their registration before the event
  //    - Purpose: Capacity planning, sending notifications, showing user's upcoming events
  //    - Lifecycle: Can be created, updated (status changes), and deleted
  //
  // 2. CHECK-IN (Actual Attendance) - FUTURE FEATURE
  //    - Created when user physically arrives at event (at event time)
  //    - Stored in 'checkins' collection (separate from registrations)
  //    - IMMUTABLE: Once created, check-in records cannot be modified or deleted
  //    - Purpose: Attendance verification, attendance reports, analytics
  //    - Lifecycle: Create-only, permanent record
  //
  // WHY SEPARATE COLLECTIONS?
  // - Different lifecycles: Registration happens early, check-in happens at event
  // - Different mutability: Registrations can be cancelled, check-ins are permanent
  // - Different purposes: Registration for planning, check-in for verification
  // - Analytics: Compare registration count vs actual attendance (no-show rate)
  // - Data integrity: Attendance records must be immutable for audit purposes
  //
  // FUTURE QR CODE INTEGRATION:
  // - Check-in will support QR code scanning for self-service attendance
  // - Each registration could generate a unique QR code for the user
  // - QR code validation will create a check-in record in 'checkins' collection
  // - CheckInModel.checkedInBy field distinguishes:
  //   * null = QR self-check-in
  //   * userId = manual check-in by staff member
  // - QR codes will be event-specific and time-limited for security
  // - Future fields may include: qrCode, validationMethod, qrScannedAt

  /// Register current user for an event
  Future<void> registerForEvent(String eventId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check if already registered using backward compatibility helper
    final alreadyRegistered = await _registrationExists(
      eventId: eventId,
      userId: user.uid,
    );

    if (alreadyRegistered) {
      throw Exception('You are already registered for this event');
    }

    // Check capacity
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      // Use Event.fromFirestore to deserialize event data
      final event = Event.fromFirestore(eventDoc.data()!, eventDoc.id);
      if (event.capacity > 0 && event.participantCount >= event.capacity) {
        throw Exception('Event is full');
      }
    }

    // Create registration using RegistrationModel
    final registration = RegistrationModel(
      id: '', // Will be assigned by Firestore
      eventId: eventId,
      userId: user.uid,
      status: 'registered',
      registeredAt: DateTime.now(),
    );

    // Write to registrations collection only
    final docRef = await _db
        .collection(_registrationsCollection)
        .add(registration.toMap());

    // Update the registration with qrCode = document ID (unique QR for check-in)
    await docRef.update({'qrCode': docRef.id});

    // Increment participant count
    await _db.collection('events').doc(eventId).update({
      'participantCount': FieldValue.increment(1),
    });
  }

  /// Unregister current user from an event
  Future<void> unregisterFromEvent(String eventId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Use RegistrationModel to query existing registrations with backward compatibility
    final registrations = await _getRegistrationsWithBackwardCompatibility(
      eventId: eventId,
      userId: user.uid,
    );

    if (registrations.isEmpty) {
      // No registration found, nothing to delete
      return;
    }

    // Delete from new collection
    final newRegs = await _db
        .collection(_registrationsCollection)
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .get();

    for (var doc in newRegs.docs) {
      await doc.reference.delete();
    }

    // Delete from old collection during migration period
    if (MigrationConfig.enableBackwardCompatibility) {
      final oldRegs = await _db
          .collection(_deprecatedRegistrationsCollection)
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: user.uid)
          .get();

      if (oldRegs.docs.isNotEmpty && MigrationConfig.logDeprecatedReads) {
        print(
          'Warning: Deleting registration from deprecated collection "$_deprecatedRegistrationsCollection"',
        );
      }

      for (var doc in oldRegs.docs) {
        await doc.reference.delete();
      }
    }

    // Decrement participant count (we know registration exists from earlier check)
    await _db.collection('events').doc(eventId).update({
      'participantCount': FieldValue.increment(-1),
    });
  }

  /// Stream that checks if current user is registered for an event (real-time)
  Stream<bool> isRegisteredStream(String eventId) {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    // Check new collection
    final newStream = _db
        .collection(_registrationsCollection)
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return false;
          // Use RegistrationModel.fromFirestore() for deserialization
          for (var doc in snapshot.docs) {
            final registration = RegistrationModel.fromFirestore(
              doc.data(),
              doc.id,
            );
            // Check if registration is active (not cancelled)
            if (registration.status == 'registered') {
              return true;
            }
          }
          return false;
        });

    // If backward compatibility is disabled, return only new collection stream
    if (!MigrationConfig.enableBackwardCompatibility) {
      return newStream;
    }

    // Check old collection during migration period
    final oldStream = _db
        .collection(_deprecatedRegistrationsCollection)
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return false;

          if (MigrationConfig.logDeprecatedReads) {
            print(
              'Warning: Found registration in deprecated collection "$_deprecatedRegistrationsCollection"',
            );
          }

          // Use RegistrationModel.fromFirestore() for deserialization
          for (var doc in snapshot.docs) {
            final registration = RegistrationModel.fromFirestore(
              doc.data(),
              doc.id,
            );
            // Check if registration is active (not cancelled)
            if (registration.status == 'registered') {
              return true;
            }
          }
          return false;
        });

    // Combine both streams - user is registered if found in either collection
    return newStream.asyncMap((isInNew) async {
      if (isInNew) return true;
      return await oldStream.first;
    });
  }

  /// Get the registration count for an event (real-time)
  Stream<int> getParticipantCountStream(String eventId) {
    return _db
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((doc) => doc.data()?['participantCount'] ?? 0);
  }

  /// Get events the current user has registered for (real-time)
  Stream<List<Event>> getRegisteredEvents() {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Get registrations from new collection
    return _db
        .collection(_registrationsCollection)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          // Use helper to get all registrations with backward compatibility
          final registrations =
              await _getRegistrationsWithBackwardCompatibility(
                userId: user.uid,
              );

          // Fetch event details for each registration
          List<Event> events = [];
          for (var registration in registrations) {
            final eventDoc = await _db
                .collection('events')
                .doc(registration.eventId)
                .get();
            if (eventDoc.exists) {
              events.add(
                Event.fromFirestore(
                  eventDoc.data() as Map<String, dynamic>,
                  eventDoc.id,
                ),
              );
            }
          }

          return events;
        });
  }

  /// Check if user has a registered event that conflicts with the given event's time
  Future<Event?> getConflictingEvent(Event targetEvent) async {
    if (targetEvent.startTime == null || targetEvent.endTime == null) {
      return null;
    }

    User? user = _auth.currentUser;
    if (user == null) return null;

    // Get all user's registrations using backward compatibility helper
    final registrations = await _getRegistrationsWithBackwardCompatibility(
      userId: user.uid,
    );

    // Check each registered event for time conflicts
    for (var registration in registrations) {
      if (registration.eventId == targetEvent.id) continue; // Skip self

      final eventDoc = await _db
          .collection('events')
          .doc(registration.eventId)
          .get();
      if (!eventDoc.exists) continue;

      final existingEvent = Event.fromFirestore(
        eventDoc.data() as Map<String, dynamic>,
        eventDoc.id,
      );

      if (existingEvent.startTime == null || existingEvent.endTime == null) {
        continue;
      }

      // Check time overlap:
      // Event A overlaps with Event B if A starts before B ends AND A ends after B starts
      bool overlaps =
          targetEvent.startTime!.isBefore(existingEvent.endTime!) &&
          targetEvent.endTime!.isAfter(existingEvent.startTime!);

      if (overlaps) {
        return existingEvent;
      }
    }

    return null;
  }

  // ─── CHECK-IN (FUTURE FEATURE) ───
  //
  // IMPORTANT: Check-in is SEPARATE from registration and serves a different purpose.
  //
  // REGISTRATION vs CHECK-IN COMPARISON:
  //
  // ┌─────────────────┬──────────────────────┬──────────────────────┐
  // │ Aspect          │ Registration         │ Check-In             │
  // ├─────────────────┼──────────────────────┼──────────────────────┤
  // │ When Created    │ Days before event    │ At event time        │
  // │ Collection      │ 'registrations'      │ 'checkins'           │
  // │ Mutability      │ MUTABLE (can cancel) │ IMMUTABLE (permanent)│
  // │ Purpose         │ Intent to attend     │ Proof of attendance  │
  // │ Used For        │ Planning, capacity   │ Verification, reports│
  // │ Can Be Deleted  │ Yes (unregister)     │ No (audit trail)     │
  // │ Status Field    │ Yes (registered,     │ No (existence =      │
  // │                 │ cancelled, waitlist) │ attended)            │
  // └─────────────────┴──────────────────────┴──────────────────────┘
  //
  // IMMUTABILITY OF CHECK-INS:
  // Check-in records are IMMUTABLE once created because:
  // - They serve as official attendance records for reporting
  // - They may be used for academic credit or participation tracking
  // - They provide an audit trail that cannot be tampered with
  // - Analytics depend on accurate historical attendance data
  //
  // FUTURE QR CODE INTEGRATION POINTS:
  //
  // 1. QR Code Generation (Registration Phase):
  //    - When user registers, generate a unique QR code for that event
  //    - QR code contains: eventId, userId, registrationId, timestamp, signature
  //    - Store QR code data in registration record or separate qr_codes collection
  //    - QR code is displayed in user's "My Events" screen
  //
  // 2. QR Code Scanning (Check-In Phase):
  //    - Event organizer/staff uses app to scan attendee QR codes
  //    - Validate QR code: check signature, event match, time window
  //    - Create check-in record in 'checkins' collection
  //    - Display confirmation to both scanner and attendee
  //
  // 3. Self-Service Check-In:
  //    - Event displays a QR code at entrance
  //    - Attendees scan event QR code with their app
  //    - App validates user is registered and creates check-in record
  //    - Alternative to staff-scanned check-in
  //
  // 4. CheckInModel Fields for QR:
  //    - checkedInBy: null for QR self-check-in, userId for staff check-in
  //    - Future fields: qrCode (scanned value), validationMethod ('qr_scan' | 'manual')
  //    - Future fields: qrScannedAt, scannerDeviceId for audit trail
  //
  // 5. Security Considerations:
  //    - QR codes should be time-limited (valid only near event time)
  //    - QR codes should be signed/encrypted to prevent forgery
  //    - Check-in should verify user is registered before allowing
  //    - Prevent duplicate check-ins (one check-in per user per event)
  //
  // The following methods are placeholders ready for implementation when
  // the QR-based check-in feature is developed.

  /// Collection name for event check-ins (future feature)
  // static const String _checkinsCollection = 'checkins';

  /// Check in current user for an event (future feature)
  ///
  /// Creates a check-in record in the 'checkins' collection to track actual attendance.
  /// This is separate from registration - a user must be registered before checking in.
  ///
  /// Parameters:
  /// - [eventId]: The event to check in to
  /// - [checkedInBy]: Optional user ID of staff member performing manual check-in
  ///                  (null for QR self-check-in)
  ///
  /// Throws:
  /// - Exception if user is not logged in
  /// - Exception if user is not registered for the event
  /// - Exception if user is already checked in
  // Future<void> checkInForEvent(String eventId, {String? checkedInBy}) async {
  //   User? user = _auth.currentUser;
  //   if (user == null) throw Exception('User not logged in');
  //
  //   // Verify user is registered for the event
  //   final isRegistered = await _registrationExists(
  //     eventId: eventId,
  //     userId: user.uid,
  //   );
  //   if (!isRegistered) {
  //     throw Exception('You must be registered for this event to check in');
  //   }
  //
  //   // Check if already checked in
  //   final existingCheckin = await _db
  //       .collection(_checkinsCollection)
  //       .where('eventId', isEqualTo: eventId)
  //       .where('userId', isEqualTo: user.uid)
  //       .limit(1)
  //       .get();
  //
  //   if (existingCheckin.docs.isNotEmpty) {
  //     throw Exception('You are already checked in to this event');
  //   }
  //
  //   // Create check-in using CheckInModel
  //   final checkin = CheckInModel(
  //     id: '', // Will be assigned by Firestore
  //     eventId: eventId,
  //     userId: user.uid,
  //     checkedInAt: DateTime.now(),
  //     checkedInBy: checkedInBy,
  //   );
  //
  //   // Write to checkins collection
  //   await _db.collection(_checkinsCollection).add(checkin.toMap());
  // }

  /// Stream that checks if current user is checked in to an event (real-time)
  ///
  /// Returns a stream that emits true if the user has checked in, false otherwise.
  /// This is separate from registration status - a user can be registered but not checked in.
  // Stream<bool> isCheckedInStream(String eventId) {
  //   User? user = _auth.currentUser;
  //   if (user == null) return Stream.value(false);
  //
  //   return _db
  //       .collection(_checkinsCollection)
  //       .where('eventId', isEqualTo: eventId)
  //       .where('userId', isEqualTo: user.uid)
  //       .snapshots()
  //       .map((snapshot) => snapshot.docs.isNotEmpty);
  // }

  /// Get check-in count for an event (real-time)
  ///
  /// Returns a stream that emits the number of users who have checked in to the event.
  /// This is different from participantCount which tracks registrations.
  // Stream<int> getCheckinCountStream(String eventId) {
  //   return _db
  //       .collection(_checkinsCollection)
  //       .where('eventId', isEqualTo: eventId)
  //       .snapshots()
  //       .map((snapshot) => snapshot.docs.length);
  // }

  /// Get all check-ins for an event
  ///
  /// Returns a list of CheckInModel objects for all users who have checked in.
  /// Useful for attendance reports and verification.
  // Future<List<CheckInModel>> getEventCheckins(String eventId) async {
  //   final snapshot = await _db
  //       .collection(_checkinsCollection)
  //       .where('eventId', isEqualTo: eventId)
  //       .get();
  //
  //   return snapshot.docs
  //       .map((doc) => CheckInModel.fromFirestore(doc.data(), doc.id))
  //       .toList();
  // }

  /// Get events the current user has checked in to (real-time)
  ///
  /// Returns a stream of events where the user has actual attendance records.
  /// This is separate from getRegisteredEvents() which shows intent to attend.
  // Stream<List<Event>> getCheckedInEvents() {
  //   User? user = _auth.currentUser;
  //   if (user == null) return Stream.value([]);
  //
  //   return _db
  //       .collection(_checkinsCollection)
  //       .where('userId', isEqualTo: user.uid)
  //       .snapshots()
  //       .asyncMap((snapshot) async {
  //         // Fetch event details for each check-in
  //         List<Event> events = [];
  //         for (var doc in snapshot.docs) {
  //           final checkin = CheckInModel.fromFirestore(doc.data(), doc.id);
  //           final eventDoc = await _db
  //               .collection('events')
  //               .doc(checkin.eventId)
  //               .get();
  //           if (eventDoc.exists) {
  //             events.add(
  //               Event.fromFirestore(
  //                 eventDoc.data() as Map<String, dynamic>,
  //                 eventDoc.id,
  //               ),
  //             );
  //           }
  //         }
  //         return events;
  //       });
  // }
}
