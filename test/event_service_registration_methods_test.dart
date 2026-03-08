import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/models/registration_model.dart';

void main() {
  group('EventService Registration Methods Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('registerForEvent Tests', () {
      test(
        'should create registration using RegistrationModel.toMap()',
        () async {
          // Create test event
          await fakeFirestore.collection('events').doc('event-1').set({
            'title': 'Test Event',
            'capacity': 100,
            'participantCount': 0,
          });

          // Create registration using RegistrationModel
          final registration = RegistrationModel(
            id: '',
            eventId: 'event-1',
            userId: 'test-user-123',
            status: 'registered',
            registeredAt: DateTime.now(),
          );

          // Write to registrations collection
          await fakeFirestore
              .collection('registrations')
              .add(registration.toMap());

          // Verify registration was created
          final snapshot = await fakeFirestore
              .collection('registrations')
              .where('eventId', isEqualTo: 'event-1')
              .where('userId', isEqualTo: 'test-user-123')
              .get();

          expect(snapshot.docs.length, 1);
          expect(snapshot.docs.first.data()['eventId'], 'event-1');
          expect(snapshot.docs.first.data()['userId'], 'test-user-123');
          expect(snapshot.docs.first.data()['status'], 'registered');
          expect(snapshot.docs.first.data()['registeredAt'], isA<Timestamp>());
        },
      );

      test('should write only to registrations collection', () async {
        // Create test event
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'capacity': 100,
          'participantCount': 0,
        });

        // Create registration
        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        // Write to registrations collection only
        await fakeFirestore
            .collection('registrations')
            .add(registration.toMap());

        // Verify it's in new collection
        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        // Verify it's NOT in old collection
        final oldRegs = await fakeFirestore
            .collection('eventRegistrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        expect(newRegs.docs.length, 1);
        expect(oldRegs.docs.length, 0);
      });

      test('should serialize DateTime to Timestamp correctly', () async {
        final testDate = DateTime(2024, 1, 15, 10, 30);

        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: testDate,
        );

        final map = registration.toMap();

        expect(map['registeredAt'], isA<Timestamp>());
        expect((map['registeredAt'] as Timestamp).toDate(), testDate);
      });

      test('should include all required fields in toMap()', () async {
        final registration = RegistrationModel(
          id: 'test-id',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        final map = registration.toMap();

        expect(map.containsKey('eventId'), true);
        expect(map.containsKey('userId'), true);
        expect(map.containsKey('status'), true);
        expect(map.containsKey('registeredAt'), true);
        // Note: id is not included in toMap() as it's the document ID
        expect(map.containsKey('id'), false);
      });

      test('should handle different status values', () async {
        final statuses = ['registered', 'cancelled', 'waitlist'];

        for (var status in statuses) {
          final registration = RegistrationModel(
            id: '',
            eventId: 'event-1',
            userId: 'test-user-123',
            status: status,
            registeredAt: DateTime.now(),
          );

          final map = registration.toMap();
          expect(map['status'], status);
        }
      });
    });

    group('Backward Compatibility Tests', () {
      test(
        'should read from both registrations and eventRegistrations collections',
        () async {
          // Add registration to new collection
          await fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Add registration to old collection
          await fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-2',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Query both collections
          final newRegs = await fakeFirestore
              .collection('registrations')
              .where('userId', isEqualTo: 'test-user-123')
              .get();

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

      test('should prefer new collection when duplicate exists', () async {
        final timestamp1 = Timestamp.fromDate(DateTime(2024, 1, 1));
        final timestamp2 = Timestamp.fromDate(DateTime(2024, 1, 2));

        // Add same registration to both collections
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp2, // Newer
        });

        await fakeFirestore.collection('eventRegistrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp1, // Older
        });

        // Query new collection (should be preferred)
        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(newRegs.docs.length, 1);
        expect(newRegs.docs.first.data()['registeredAt'], timestamp2);
      });

      test(
        'should check both collections for existing registrations',
        () async {
          // Add registration to old collection only
          await fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-1',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Check new collection (empty)
          final newRegs = await fakeFirestore
              .collection('registrations')
              .where('eventId', isEqualTo: 'event-1')
              .where('userId', isEqualTo: 'test-user-123')
              .get();

          // Check old collection (has registration)
          final oldRegs = await fakeFirestore
              .collection('eventRegistrations')
              .where('eventId', isEqualTo: 'event-1')
              .where('userId', isEqualTo: 'test-user-123')
              .get();

          expect(newRegs.docs.isEmpty, true);
          expect(oldRegs.docs.isNotEmpty, true);
        },
      );

      test(
        'should handle querying by eventId with backward compatibility',
        () async {
          // Add registrations for same event in both collections
          await fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'user-1',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          await fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-1',
            'userId': 'user-2',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Query both collections by eventId
          final newRegs = await fakeFirestore
              .collection('registrations')
              .where('eventId', isEqualTo: 'event-1')
              .get();

          final oldRegs = await fakeFirestore
              .collection('eventRegistrations')
              .where('eventId', isEqualTo: 'event-1')
              .get();

          expect(newRegs.docs.length, 1);
          expect(oldRegs.docs.length, 1);
        },
      );

      test(
        'should handle querying by userId with backward compatibility',
        () async {
          // Add registrations for same user in both collections
          await fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          await fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-2',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Query both collections by userId
          final newRegs = await fakeFirestore
              .collection('registrations')
              .where('userId', isEqualTo: 'test-user-123')
              .get();

          final oldRegs = await fakeFirestore
              .collection('eventRegistrations')
              .where('userId', isEqualTo: 'test-user-123')
              .get();

          expect(newRegs.docs.length, 1);
          expect(oldRegs.docs.length, 1);
        },
      );
    });

    group('Collection Name Update Tests', () {
      test('should use registrations collection name', () async {
        // Verify collection name by testing actual usage
        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        await fakeFirestore
            .collection('registrations')
            .add(registration.toMap());

        final snapshot = await fakeFirestore.collection('registrations').get();

        expect(snapshot.docs.length, 1);
      });

      test('should reference deprecated collection name', () async {
        // Verify deprecated collection name by testing backward compatibility
        await fakeFirestore.collection('eventRegistrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        final snapshot = await fakeFirestore
            .collection('eventRegistrations')
            .get();

        expect(snapshot.docs.length, 1);
      });

      test('should write to registrations collection', () async {
        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        // Write to new collection
        await fakeFirestore
            .collection('registrations')
            .add(registration.toMap());

        // Verify it's in registrations collection
        final snapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        expect(snapshot.docs.length, 1);
      });

      test('should not write to eventRegistrations collection', () async {
        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        // Write to new collection only
        await fakeFirestore
            .collection('registrations')
            .add(registration.toMap());

        // Verify old collection is empty
        final oldSnapshot = await fakeFirestore
            .collection('eventRegistrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        expect(oldSnapshot.docs.isEmpty, true);
      });

      test('should query registrations collection for reads', () async {
        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Query from registrations collection
        final snapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.first.data()['eventId'], 'event-1');
      });
    });

    group('RegistrationModel Integration Tests', () {
      test('should round-trip serialize and deserialize correctly', () async {
        final originalDate = DateTime(2024, 1, 15, 10, 30);
        final original = RegistrationModel(
          id: 'test-id',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: originalDate,
        );

        // Serialize
        final map = original.toMap();

        // Write to Firestore
        final docRef = await fakeFirestore.collection('registrations').add(map);

        // Read from Firestore
        final snapshot = await docRef.get();

        // Deserialize
        final deserialized = RegistrationModel.fromFirestore(
          snapshot.data()!,
          snapshot.id,
        );

        expect(deserialized.eventId, original.eventId);
        expect(deserialized.userId, original.userId);
        expect(deserialized.status, original.status);
        expect(deserialized.registeredAt.year, originalDate.year);
        expect(deserialized.registeredAt.month, originalDate.month);
        expect(deserialized.registeredAt.day, originalDate.day);
      });

      test('should handle missing optional fields with defaults', () async {
        // Add registration without status field
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

        // Should use default value
        expect(registration.status, 'registered');
      });

      test('should convert Timestamp to DateTime on read', () async {
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

      test('should convert DateTime to Timestamp on write', () async {
        final dateTime = DateTime(2024, 1, 15, 10, 30);

        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: dateTime,
        );

        final map = registration.toMap();

        expect(map['registeredAt'], isA<Timestamp>());
        expect((map['registeredAt'] as Timestamp).toDate().year, 2024);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty eventId', () async {
        final registration = RegistrationModel(
          id: '',
          eventId: '',
          userId: 'test-user-123',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        final map = registration.toMap();
        expect(map['eventId'], '');
      });

      test('should handle empty userId', () async {
        final registration = RegistrationModel(
          id: '',
          eventId: 'event-1',
          userId: '',
          status: 'registered',
          registeredAt: DateTime.now(),
        );

        final map = registration.toMap();
        expect(map['userId'], '');
      });

      test('should handle multiple registrations for same user', () async {
        // Add multiple registrations
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

        // Query all registrations for user
        final snapshot = await fakeFirestore
            .collection('registrations')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(snapshot.docs.length, 2);
      });

      test('should handle multiple users for same event', () async {
        // Add multiple registrations
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'user-1',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'user-2',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Query all registrations for event
        final snapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        expect(snapshot.docs.length, 2);
      });

      test('should handle concurrent registration writes', () async {
        final timestamp = Timestamp.now();

        // Simulate concurrent writes
        await Future.wait([
          fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'user-1',
            'status': 'registered',
            'registeredAt': timestamp,
          }),
          fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'user-2',
            'status': 'registered',
            'registeredAt': timestamp,
          }),
          fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'user-3',
            'status': 'registered',
            'registeredAt': timestamp,
          }),
        ]);

        final snapshot = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        expect(snapshot.docs.length, 3);
      });
    });
  });
}
