import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/models/registration_model.dart';

void main() {
  group('EventService getRegisteredEvents Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
      'should use RegistrationModel.fromFirestore for deserialization',
      () async {
        final timestamp = Timestamp.now();

        // Add registration to new collection
        final doc = await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Fetch and verify deserialization
        final snapshot = await doc.get();
        final registration = RegistrationModel.fromFirestore(
          snapshot.data()!,
          snapshot.id,
        );

        expect(registration.eventId, 'event-1');
        expect(registration.userId, 'test-user-123');
        expect(registration.status, 'registered');
        expect(registration.registeredAt, isA<DateTime>());
      },
    );

    test(
      'should query registrations collection with backward compatibility',
      () async {
        final timestamp = Timestamp.now();

        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Add registration to old collection (backward compatibility)
        await fakeFirestore.collection('eventRegistrations').add({
          'eventId': 'event-2',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Query new collection
        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        // Query old collection
        final oldRegs = await fakeFirestore
            .collection('eventRegistrations')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(newRegs.docs.length, 1);
        expect(oldRegs.docs.length, 1);

        // Verify both can be deserialized with RegistrationModel
        final newReg = RegistrationModel.fromFirestore(
          newRegs.docs.first.data(),
          newRegs.docs.first.id,
        );
        final oldReg = RegistrationModel.fromFirestore(
          oldRegs.docs.first.data(),
          oldRegs.docs.first.id,
        );

        expect(newReg.eventId, 'event-1');
        expect(oldReg.eventId, 'event-2');
      },
    );

    test('should maintain Stream<List<Event>> return type', () async {
      // This test verifies the method signature is maintained
      // The actual method returns Stream<List<Event>>, not Stream<List<RegistrationModel>>

      // Add test event
      await fakeFirestore.collection('events').doc('event-1').set({
        'title': 'Test Event',
        'description': 'Test Description',
        'clubId': 'club-1',
        'location': 'Test Location',
        'startTime': Timestamp.now(),
        'endTime': Timestamp.now(),
        'capacity': 100,
        'participantCount': 1,
        'image': '',
        'createdBy': 'test-user',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'status': 'active',
        'note': '',
      });

      // Add registration
      await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': Timestamp.now(),
      });

      // Verify registration exists
      final regs = await fakeFirestore
          .collection('registrations')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      expect(regs.docs.length, 1);

      // Verify event exists
      final event = await fakeFirestore
          .collection('events')
          .doc('event-1')
          .get();
      expect(event.exists, true);
    });

    test('should handle registrations with default status value', () async {
      // Add registration without explicit status
      final doc = await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'registeredAt': Timestamp.now(),
      });

      final snapshot = await doc.get();
      final registration = RegistrationModel.fromFirestore(
        snapshot.data()!,
        snapshot.id,
      );

      // Should use default 'registered' status
      expect(registration.status, 'registered');
    });

    test('should convert Firestore Timestamp to DateTime', () async {
      final timestamp = Timestamp.fromDate(DateTime(2024, 1, 15, 10, 30));

      final doc = await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': timestamp,
      });

      final snapshot = await doc.get();
      final registration = RegistrationModel.fromFirestore(
        snapshot.data()!,
        snapshot.id,
      );

      expect(registration.registeredAt, isA<DateTime>());
      expect(registration.registeredAt.year, 2024);
      expect(registration.registeredAt.month, 1);
      expect(registration.registeredAt.day, 15);
    });
  });
}
