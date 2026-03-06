import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // CREATE EVENT
  Future<void> createEvent({
    required String title,
    required String description,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
    required int capacity,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _db.collection('events').add({
      'title': title,
      'description': description,
      'clubId': user
          .uid, // Using UID as club ID for simplicity, assuming club admin is the user
      'location': location,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'capacity': capacity,
      'participantCount': 0,
      'image': '',
      'createdBy': user.uid,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'status': 'published',
    });
  }

  // UPDATE EVENT
  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required String location,
    required DateTime startTime,
    required DateTime endTime,
    required int capacity,
  }) async {
    await _db.collection('events').doc(eventId).update({
      'title': title,
      'description': description,
      'location': location,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'capacity': capacity,
      'updatedAt': Timestamp.now(),
    });
  }

  // DELETE EVENT
  Future<void> deleteEvent(String eventId) async {
    // Note: should also delete from eventRegistrations if there are any
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

  // GET MANAGED EVENTS
  Stream<QuerySnapshot> getManagedEvents() {
    User? user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _db
        .collection('events')
        .where('clubId', isEqualTo: user.uid)
        .orderBy('startTime', descending: true)
        .snapshots();
  }
}
