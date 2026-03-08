import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/models/registration_model.dart';

void main() {
  group('EventService Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    const testUserId = 'test-user-123';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('End-to-End Registration Flow', () {
      test('should complete full registration flow using RegistrationModel', () async {
        final eventId = 'event-1';
        await fakeFirestore.collection('events').doc(eventId).set({
          'title': 'Test Event',
          'capacity': 100,
          'participantCount': 0,
          'status': 'active',
        });

        final registration = RegistrationModel(
          id: '',
          eventId: eventId,
          userId: testUserId,
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        await fakeFirestore.collection('registrations').add(registration.toMap());
        await fakeFirestore.collection('events').doc(eventId).update({
          'participantCount': FieldValue.increment(1),
        });

        final regSnapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: eventId)
            .where('userId', isEqualTo: testUserId)
            .get();

        expect(regSnapshot.docs.length, 1);
        expect(regSnapshot.docs.first.data()['status'], 'registered');

        final eventSnapshot = await fakeFirestore.collection('events').doc(eventId).get();
        expect(eventSnapshot.data()?['participantCount'], 1);

        final savedReg = RegistrationModel.fromFirestore(
          regSnapshot.docs.first.data(),
          regSnapshot.docs.first.id,
        );
        expect(savedReg.eventId, eventId);
        expect(savedReg.userId, testUserId);
        expect(savedReg.status, 'registered');
      });
    });
  });
}
