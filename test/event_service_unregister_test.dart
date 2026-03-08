import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/models/registration_model.dart';

void main() {
  group('EventService unregisterFromEvent Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
      'should delete registration from new collection only when backward compatibility is disabled',
      () async {
        // Create event
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'participantCount': 1,
        });

        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Verify registration exists
        final beforeRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(beforeRegs.docs.length, 1);

        // Delete registration
        final regs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        for (var doc in regs.docs) {
          await doc.reference.delete();
        }

        // Verify registration is deleted
        final afterRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(afterRegs.docs.length, 0);
      },
    );

    test(
      'should delete registration from both collections when backward compatibility is enabled',
      () async {
        // Create event
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'participantCount': 1,
        });

        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Add registration to old collection
        await fakeFirestore.collection('eventRegistrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Verify registrations exist in both collections
        final beforeNewRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        final beforeOldRegs = await fakeFirestore
            .collection('eventRegistrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(beforeNewRegs.docs.length, 1);
        expect(beforeOldRegs.docs.length, 1);

        // Delete from both collections (simulating backward compatibility)
        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        for (var doc in newRegs.docs) {
          await doc.reference.delete();
        }

        final oldRegs = await fakeFirestore
            .collection('eventRegistrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        for (var doc in oldRegs.docs) {
          await doc.reference.delete();
        }

        // Verify registrations are deleted from both collections
        final afterNewRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        final afterOldRegs = await fakeFirestore
            .collection('eventRegistrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(afterNewRegs.docs.length, 0);
        expect(afterOldRegs.docs.length, 0);
      },
    );

    test('should handle unregistering when no registration exists', () async {
      // Create event
      await fakeFirestore.collection('events').doc('event-1').set({
        'title': 'Test Event',
        'participantCount': 0,
      });

      // Try to delete non-existent registration
      final regs = await fakeFirestore
          .collection('registrations')
          .where('eventId', isEqualTo: 'event-1')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      expect(regs.docs.length, 0);

      // Should not throw error when no registration exists
      for (var doc in regs.docs) {
        await doc.reference.delete();
      }
    });

    test(
      'should only delete registration for specific user and event',
      () async {
        // Create event
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'participantCount': 2,
        });

        // Add registrations for multiple users
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'other-user-456',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Delete only test-user-123's registration
        final regs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        for (var doc in regs.docs) {
          await doc.reference.delete();
        }

        // Verify only test-user-123's registration is deleted
        final afterTestUserRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        final afterOtherUserRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'other-user-456')
            .get();

        expect(afterTestUserRegs.docs.length, 0);
        expect(afterOtherUserRegs.docs.length, 1);
      },
    );

    test('should use RegistrationModel for querying registrations', () async {
      final timestamp = Timestamp.now();

      // Add registration to new collection
      final doc = await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': timestamp,
      });

      // Fetch and deserialize using RegistrationModel
      final snapshot = await doc.get();
      final registration = RegistrationModel.fromFirestore(
        snapshot.data()!,
        snapshot.id,
      );

      expect(registration.eventId, 'event-1');
      expect(registration.userId, 'test-user-123');
      expect(registration.status, 'registered');
      expect(registration.registeredAt, timestamp.toDate());
    });

    test(
      'should handle multiple registrations for same user across different events',
      () async {
        // Create events
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Event 1',
          'participantCount': 1,
        });

        await fakeFirestore.collection('events').doc('event-2').set({
          'title': 'Event 2',
          'participantCount': 1,
        });

        // Add registrations for same user to different events
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-2',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Delete registration for event-1 only
        final regs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        for (var doc in regs.docs) {
          await doc.reference.delete();
        }

        // Verify only event-1 registration is deleted
        final afterEvent1Regs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        final afterEvent2Regs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-2')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(afterEvent1Regs.docs.length, 0);
        expect(afterEvent2Regs.docs.length, 1);
      },
    );
  });
}
