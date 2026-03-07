import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      final oldData = oldDoc.data()!;
      final oldStatus = oldData['status'] ?? '';

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

      // 3. Date/time changed → notify "event rescheduled"
      final oldStart = oldData['startTime'] as Timestamp?;
      final oldEnd = oldData['endTime'] as Timestamp?;
      final newStart = event.startTime;
      final newEnd = event.endTime;

      bool dateChanged = false;
      if (oldStart != null && newStart != null) {
        dateChanged = oldStart.toDate() != newStart;
      } else if ((oldStart == null) != (newStart == null)) {
        dateChanged = true;
      }
      if (!dateChanged && oldEnd != null && newEnd != null) {
        dateChanged = oldEnd.toDate() != newEnd;
      }

      if (dateChanged && event.status != 'inactive') {
        String newDateStr = '';
        if (newStart != null) {
          newDateStr =
              '${newStart.day}/${newStart.month}/${newStart.year} ${newStart.hour}:${newStart.minute.toString().padLeft(2, '0')}';
        }
        await _notifyRegisteredUsers(
          eventId: event.id,
          eventTitle: event.title,
          type: 'event_updated',
          message:
              'The event "${event.title}" has been rescheduled${newDateStr.isNotEmpty ? ' to $newDateStr' : ''}. Please check the new details.',
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
      eventTitle = eventDoc.data()?['title'] ?? 'Unknown Event';
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

    // Delete registrations
    var regs = await _db
        .collection('eventRegistrations')
        .where('eventId', isEqualTo: eventId)
        .get();
    for (var doc in regs.docs) {
      await doc.reference.delete();
    }
  }

  /// Notify all registered users of an event
  Future<void> _notifyRegisteredUsers({
    required String eventId,
    required String eventTitle,
    required String type,
    required String message,
  }) async {
    final regs = await _db
        .collection('eventRegistrations')
        .where('eventId', isEqualTo: eventId)
        .get();

    // Write to user_notifications for registered users
    for (var regDoc in regs.docs) {
      String userId = regDoc['userId'];
      await _db.collection('user_notifications').add({
        'userId': userId,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'type': type,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Write to notifications collection to trigger Cloud Function for FCM push notification
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

  /// Register current user for an event
  Future<void> registerForEvent(String eventId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check if already registered
    final existing = await _db
        .collection('eventRegistrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('You are already registered for this event');
    }

    // Check capacity
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (eventDoc.exists) {
      final data = eventDoc.data()!;
      final capacity = data['capacity'] ?? 0;
      final participantCount = data['participantCount'] ?? 0;
      if (capacity > 0 && participantCount >= capacity) {
        throw Exception('Event is full');
      }
    }

    // Create registration
    await _db.collection('eventRegistrations').add({
      'eventId': eventId,
      'userId': user.uid,
      'registeredAt': FieldValue.serverTimestamp(),
    });

    // Increment participant count
    await _db.collection('events').doc(eventId).update({
      'participantCount': FieldValue.increment(1),
    });
  }

  /// Unregister current user from an event
  Future<void> unregisterFromEvent(String eventId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final regs = await _db
        .collection('eventRegistrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .get();

    for (var doc in regs.docs) {
      await doc.reference.delete();
    }

    if (regs.docs.isNotEmpty) {
      // Decrement participant count
      await _db.collection('events').doc(eventId).update({
        'participantCount': FieldValue.increment(-1),
      });
    }
  }

  /// Stream that checks if current user is registered for an event (real-time)
  Stream<bool> isRegisteredStream(String eventId) {
    User? user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _db
        .collection('eventRegistrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
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

    return _db
        .collection('eventRegistrations')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Event> events = [];
          for (var doc in snapshot.docs) {
            String eventId = doc['eventId'];
            final eventDoc = await _db.collection('events').doc(eventId).get();
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

    // Get all user's registrations
    final regs = await _db
        .collection('eventRegistrations')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (var regDoc in regs.docs) {
      String eventId = regDoc['eventId'];
      if (eventId == targetEvent.id) continue; // Skip self

      final eventDoc = await _db.collection('events').doc(eventId).get();
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
}
