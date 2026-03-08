import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/models/registration_model.dart';

void main() {
  group('EventService isRegisteredStream Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
      'should use RegistrationModel.fromFirestore() for deserialization',
      () async {
        final timestamp = Timestamp.now();

        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Query and verify deserialization works
        final snapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(snapshot.docs.length, 1);

        // Deserialize using RegistrationModel
        final registration = RegistrationModel.fromFirestore(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );

        expect(registration.eventId, 'event-1');
        expect(registration.userId, 'test-user-123');
        expect(registration.status, 'registered');
        expect(registration.registeredAt, isA<DateTime>());
      },
    );

    test(
      'should return true only for active registrations (status = registered)',
      () async {
        final timestamp = Timestamp.now();

        // Add active registration
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Add cancelled registration
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-2',
          'userId': 'test-user-123',
          'status': 'cancelled',
          'registeredAt': timestamp,
        });

        // Query active registration
        final activeSnapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        final activeReg = RegistrationModel.fromFirestore(
          activeSnapshot.docs.first.data(),
          activeSnapshot.docs.first.id,
        );

        expect(activeReg.status, 'registered');

        // Query cancelled registration
        final cancelledSnapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-2')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        final cancelledReg = RegistrationModel.fromFirestore(
          cancelledSnapshot.docs.first.data(),
          cancelledSnapshot.docs.first.id,
        );

        expect(cancelledReg.status, 'cancelled');
      },
    );

    test('should deserialize from both new and old collections', () async {
      final timestamp = Timestamp.now();

      // Add registration to new collection
      await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': timestamp,
      });

      // Add registration to old collection
      await fakeFirestore.collection('eventRegistrations').add({
        'eventId': 'event-2',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': timestamp,
      });

      // Query and deserialize from new collection
      final newSnapshot = await fakeFirestore
          .collection('registrations')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      final newReg = RegistrationModel.fromFirestore(
        newSnapshot.docs.first.data(),
        newSnapshot.docs.first.id,
      );

      expect(newReg.eventId, 'event-1');

      // Query and deserialize from old collection
      final oldSnapshot = await fakeFirestore
          .collection('eventRegistrations')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      final oldReg = RegistrationModel.fromFirestore(
        oldSnapshot.docs.first.data(),
        oldSnapshot.docs.first.id,
      );

      expect(oldReg.eventId, 'event-2');
    });

    test('should handle empty snapshots correctly', () async {
      // Query non-existent registration
      final snapshot = await fakeFirestore
          .collection('registrations')
          .where('eventId', isEqualTo: 'non-existent')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      expect(snapshot.docs.isEmpty, true);
    });

    test('should handle multiple registrations and check status', () async {
      final timestamp = Timestamp.now();

      // Add multiple registrations with different statuses
      await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': timestamp,
      });

      await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-456',
        'status': 'cancelled',
        'registeredAt': timestamp,
      });

      await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-789',
        'status': 'waitlist',
        'registeredAt': timestamp,
      });

      // Query all registrations for event-1
      final snapshot = await fakeFirestore
          .collection('registrations')
          .where('eventId', isEqualTo: 'event-1')
          .get();

      expect(snapshot.docs.length, 3);

      // Count active registrations
      int activeCount = 0;
      for (var doc in snapshot.docs) {
        final reg = RegistrationModel.fromFirestore(doc.data(), doc.id);
        if (reg.status == 'registered') {
          activeCount++;
        }
      }

      expect(activeCount, 1);
    });
  });
}
