import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/untils/migration_script.dart';

void main() {
  group('MigrationScript', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MigrationScript migrationScript;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      migrationScript = MigrationScript(firestore: fakeFirestore);
    });

    group('migrateRegistrations', () {
      test('should handle empty source collection', () async {
        // Act
        final result = await migrationScript.migrateRegistrations(
          dryRun: false,
        );

        // Assert
        expect(result.success, true);
        expect(result.sourceCount, 0);
        expect(result.migratedDocs, isEmpty);
        expect(result.errors, isEmpty);
      });

      test(
        'should migrate documents in dry-run mode without making changes',
        () async {
          // Arrange - Add test data to source collection
          await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
            'eventId': 'event1',
            'userId': 'user1',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          await fakeFirestore.collection('eventRegistrations').doc('reg2').set({
            'eventId': 'event2',
            'userId': 'user2',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Act
          final result = await migrationScript.migrateRegistrations(
            dryRun: true,
          );

          // Assert
          expect(result.success, true);
          expect(result.sourceCount, 2);
          expect(result.migratedDocs.length, 2);
          expect(result.errors, isEmpty);

          // Verify target collection is still empty (dry-run)
          final targetSnapshot = await fakeFirestore
              .collection('registrations')
              .get();
          expect(targetSnapshot.docs.length, 0);
        },
      );

      test('should migrate documents and preserve document IDs', () async {
        // Arrange
        final timestamp = Timestamp.now();
        await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        await fakeFirestore.collection('eventRegistrations').doc('reg2').set({
          'eventId': 'event2',
          'userId': 'user2',
          'status': 'cancelled',
          'registeredAt': timestamp,
        });

        // Act
        final result = await migrationScript.migrateRegistrations(
          dryRun: false,
        );

        // Assert
        expect(result.success, true);
        expect(result.sourceCount, 2);
        expect(result.migratedDocs, containsAll(['reg1', 'reg2']));
        expect(result.targetCount, 2);
        expect(result.errors, isEmpty);

        // Verify documents exist in target with same IDs
        final doc1 = await fakeFirestore
            .collection('registrations')
            .doc('reg1')
            .get();
        expect(doc1.exists, true);
        expect(doc1.data()?['eventId'], 'event1');
        expect(doc1.data()?['userId'], 'user1');
        expect(doc1.data()?['status'], 'registered');

        final doc2 = await fakeFirestore
            .collection('registrations')
            .doc('reg2')
            .get();
        expect(doc2.exists, true);
        expect(doc2.data()?['eventId'], 'event2');
        expect(doc2.data()?['status'], 'cancelled');
      });

      test('should preserve all fields during migration', () async {
        // Arrange
        final timestamp = Timestamp.fromDate(DateTime(2024, 1, 15, 10, 30));
        await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
          'eventId': 'event123',
          'userId': 'user456',
          'status': 'registered',
          'registeredAt': timestamp,
          'extraField': 'extraValue', // Additional field to test preservation
        });

        // Act
        final result = await migrationScript.migrateRegistrations(
          dryRun: false,
        );

        // Assert
        expect(result.success, true);
        final doc = await fakeFirestore
            .collection('registrations')
            .doc('reg1')
            .get();
        expect(doc.data()?['eventId'], 'event123');
        expect(doc.data()?['userId'], 'user456');
        expect(doc.data()?['status'], 'registered');
        expect(doc.data()?['registeredAt'], timestamp);
        expect(doc.data()?['extraField'], 'extraValue');
      });

      test('should skip documents that already exist in target', () async {
        // Arrange
        final timestamp = Timestamp.now();

        // Add to source
        await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        await fakeFirestore.collection('eventRegistrations').doc('reg2').set({
          'eventId': 'event2',
          'userId': 'user2',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Add reg1 to target (already migrated)
        await fakeFirestore.collection('registrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Act
        final result = await migrationScript.migrateRegistrations(
          dryRun: false,
        );

        // Assert
        expect(result.success, true);
        expect(result.sourceCount, 2);
        expect(result.migratedDocs, ['reg2']); // Only reg2 migrated
        expect(result.skippedDocs, ['reg1']); // reg1 skipped
        expect(result.targetCount, 2); // Both exist in target now
      });

      test('should report errors for invalid data', () async {
        // Arrange - Add document with missing required fields
        await fakeFirestore
            .collection('eventRegistrations')
            .doc('invalid1')
            .set({
              'eventId': 'event1',
              // Missing userId, status, registeredAt
            });

        await fakeFirestore.collection('eventRegistrations').doc('valid1').set({
          'eventId': 'event2',
          'userId': 'user2',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Act
        final result = await migrationScript.migrateRegistrations(
          dryRun: false,
        );

        // Assert
        expect(result.sourceCount, 2);
        expect(result.migratedDocs, ['valid1']); // Only valid doc migrated
        expect(result.errors.length, greaterThanOrEqualTo(1));
        expect(result.errors.any((e) => e.contains('invalid1')), true);
        expect(
          result.errors.any((e) => e.contains('missing required fields')),
          true,
        );
      });

      test('should call progress callback during migration', () async {
        // Arrange
        final progressUpdates = <String>[];

        for (int i = 0; i < 5; i++) {
          await fakeFirestore
              .collection('eventRegistrations')
              .doc('reg$i')
              .set({
                'eventId': 'event$i',
                'userId': 'user$i',
                'status': 'registered',
                'registeredAt': Timestamp.now(),
              });
        }

        // Act
        await migrationScript.migrateRegistrations(
          dryRun: false,
          onProgress: (current, total, message) {
            progressUpdates.add('$current/$total: $message');
          },
        );

        // Assert
        expect(progressUpdates.isNotEmpty, true);
        expect(progressUpdates.any((msg) => msg.contains('Counting')), true);
        expect(
          progressUpdates.any((msg) => msg.contains('Found 5 documents')),
          true,
        );
      });

      test('should handle large batch of documents', () async {
        // Arrange - Create 50 documents
        for (int i = 0; i < 50; i++) {
          await fakeFirestore
              .collection('eventRegistrations')
              .doc('reg$i')
              .set({
                'eventId': 'event${i % 10}',
                'userId': 'user$i',
                'status': 'registered',
                'registeredAt': Timestamp.now(),
              });
        }

        // Act
        final result = await migrationScript.migrateRegistrations(
          dryRun: false,
        );

        // Assert
        expect(result.success, true);
        expect(result.sourceCount, 50);
        expect(result.migratedDocs.length, 50);
        expect(result.targetCount, 50);
        expect(result.errors, isEmpty);
      });
    });

    group('validateMigration', () {
      test('should validate successful migration', () async {
        // Arrange - Add matching documents to both collections
        final timestamp = Timestamp.now();

        await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        await fakeFirestore.collection('registrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        // Act
        final result = await migrationScript.validateMigration();

        // Assert
        expect(result.isValid, true);
        expect(result.sourceCount, 1);
        expect(result.targetCount, 1);
        expect(result.errors, isEmpty);
      });

      test('should detect missing documents in target', () async {
        // Arrange - Add to source but not target
        await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Act
        final result = await migrationScript.validateMigration();

        // Assert
        expect(result.isValid, false);
        expect(result.sourceCount, 1);
        expect(result.targetCount, 0);
        expect(result.errors.length, 1);
        expect(result.errors.first, contains('reg1'));
        expect(
          result.errors.first,
          contains('exists in source but not in target'),
        );
      });

      test('should detect field mismatches', () async {
        // Arrange - Add documents with different field values
        final timestamp = Timestamp.now();

        await fakeFirestore.collection('eventRegistrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'registered',
          'registeredAt': timestamp,
        });

        await fakeFirestore.collection('registrations').doc('reg1').set({
          'eventId': 'event1',
          'userId': 'user1',
          'status': 'cancelled', // Different status
          'registeredAt': timestamp,
        });

        // Act
        final result = await migrationScript.validateMigration();

        // Assert
        expect(result.isValid, false);
        expect(result.errors.length, 1);
        expect(result.errors.first, contains('Field mismatch'));
        expect(result.errors.first, contains('status'));
      });

      test('should validate multiple documents correctly', () async {
        // Arrange
        final timestamp = Timestamp.now();

        // Add 3 matching documents
        for (int i = 1; i <= 3; i++) {
          final data = {
            'eventId': 'event$i',
            'userId': 'user$i',
            'status': 'registered',
            'registeredAt': timestamp,
          };
          await fakeFirestore
              .collection('eventRegistrations')
              .doc('reg$i')
              .set(data);
          await fakeFirestore
              .collection('registrations')
              .doc('reg$i')
              .set(data);
        }

        // Act
        final result = await migrationScript.validateMigration();

        // Assert
        expect(result.isValid, true);
        expect(result.sourceCount, 3);
        expect(result.targetCount, 3);
        expect(result.errors, isEmpty);
      });
    });

    group('MigrationResult', () {
      test('should format toString correctly', () {
        // Arrange
        final result = MigrationResult()
          ..sourceCount = 10
          ..targetCount = 10
          ..migratedDocs = ['doc1', 'doc2']
          ..skippedDocs = ['doc3']
          ..errors = ['Error 1']
          ..success = false
          ..durationSeconds = 5;

        // Act
        final output = result.toString();

        // Assert
        expect(output, contains('Source documents: 10'));
        expect(output, contains('Target documents: 10'));
        expect(output, contains('Migrated: 2'));
        expect(output, contains('Skipped: 1'));
        expect(output, contains('Errors: 1'));
        expect(output, contains('Success: false'));
        expect(output, contains('Duration: 5s'));
        expect(output, contains('Error 1'));
      });
    });

    group('ValidationResult', () {
      test('should format toString correctly', () {
        // Arrange
        final result = ValidationResult()
          ..sourceCount = 5
          ..targetCount = 4
          ..isValid = false
          ..errors = ['Missing doc1', 'Field mismatch in doc2'];

        // Act
        final output = result.toString();

        // Assert
        expect(output, contains('Source count: 5'));
        expect(output, contains('Target count: 4'));
        expect(output, contains('Valid: false'));
        expect(output, contains('Missing doc1'));
        expect(output, contains('Field mismatch in doc2'));
      });
    });
  });
}
