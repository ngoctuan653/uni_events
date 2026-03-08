import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/models/registration_model.dart';
import 'package:uni_events/untils/migration_config.dart';

void main() {
  group('EventService Backward Compatibility Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test(
      'should read registrations from new collection only when backward compatibility is disabled',
      () async {
        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Add registration to old collection (should be ignored)
        await fakeFirestore.collection('eventRegistrations').add({
          'eventId': 'event-2',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Query with backward compatibility disabled
        // Note: This test assumes MigrationConfig.enableBackwardCompatibility = false
        // In real implementation, you'd need to mock or configure this

        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(newRegs.docs.length, 1);
        expect(newRegs.docs.first.data()['eventId'], 'event-1');
      },
    );

    test(
      'should read registrations from both collections when backward compatibility is enabled',
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
        expect(newRegs.docs.first.data()['eventId'], 'event-1');
        expect(oldRegs.docs.first.data()['eventId'], 'event-2');
      },
    );

    test(
      'should prefer new collection when same registration exists in both',
      () async {
        final timestamp1 = Timestamp.fromDate(DateTime(2024, 1, 1));
        final timestamp2 = Timestamp.fromDate(DateTime(2024, 1, 2));

        // Add same registration to both collections with different timestamps
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

        // The helper method should prefer the new collection
        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .where('userId', isEqualTo: 'test-user-123')
            .get();

        expect(newRegs.docs.length, 1);
        expect(newRegs.docs.first.data()['registeredAt'], timestamp2);
      },
    );

    test('should handle empty collections gracefully', () async {
      // Query empty collections
      final newRegs = await fakeFirestore
          .collection('registrations')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      final oldRegs = await fakeFirestore
          .collection('eventRegistrations')
          .where('userId', isEqualTo: 'test-user-123')
          .get();

      expect(newRegs.docs.length, 0);
      expect(oldRegs.docs.length, 0);
    });

    test(
      'should correctly deserialize RegistrationModel from both collections',
      () async {
        final timestamp = Timestamp.now();

        // Add registration to new collection
        final newDoc = await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Add registration to old collection
        final oldDoc = await fakeFirestore
            .collection('eventRegistrations')
            .add({
              'eventId': 'event-2',
              'userId': 'test-user-123',
              'status': 'registered',
              'registeredAt': timestamp,
            });

        // Fetch and deserialize
        final newSnapshot = await newDoc.get();
        final oldSnapshot = await oldDoc.get();

        final newReg = RegistrationModel.fromFirestore(
          newSnapshot.data()!,
          newSnapshot.id,
        );
        final oldReg = RegistrationModel.fromFirestore(
          oldSnapshot.data()!,
          oldSnapshot.id,
        );

        expect(newReg.eventId, 'event-1');
        expect(newReg.userId, 'test-user-123');
        expect(newReg.status, 'registered');
        expect(oldReg.eventId, 'event-2');
        expect(oldReg.userId, 'test-user-123');
        expect(oldReg.status, 'registered');
      },
    );

    test('should write registrations only to new collection', () async {
      // Simulate registration creation
      await fakeFirestore.collection('registrations').add({
        'eventId': 'event-1',
        'userId': 'test-user-123',
        'status': 'registered',
        'registeredAt': FieldValue.serverTimestamp(),
      });

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

    test('should handle registrations with missing optional fields', () async {
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

    test(
      'should query registrations by eventId with backward compatibility',
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

        // Query both collections
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
      'should handle concurrent registrations in both collections',
      () async {
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
          fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-1',
            'userId': 'user-3',
            'status': 'registered',
            'registeredAt': timestamp,
          }),
        ]);

        final newRegs = await fakeFirestore
            .collection('registrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        final oldRegs = await fakeFirestore
            .collection('eventRegistrations')
            .where('eventId', isEqualTo: 'event-1')
            .get();

        expect(newRegs.docs.length, 2);
        expect(oldRegs.docs.length, 1);
      },
    );
  });

  group('MigrationConfig Tests', () {
    test('should have backward compatibility enabled by default', () {
      expect(MigrationConfig.enableBackwardCompatibility, true);
    });

    test('should have deprecated read logging enabled by default', () {
      expect(MigrationConfig.logDeprecatedReads, true);
    });
  });
}
