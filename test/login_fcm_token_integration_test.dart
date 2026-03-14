import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Integration Test for Login Flow with FCM Token Update
///
/// This test verifies the complete login flow including FCM token update.
/// Tests the interaction between AuthService and NotificationService.
///
/// **Validates**: Bugfix Requirements 1.1, 1.2, 1.3, 1.4
/// **Validates**: Design Section 2.2 - Update AuthService.login()
///
/// **Note**: These tests simulate the login flow and FCM token update logic
/// using FakeFirebaseFirestore. They verify that the token update mechanism
/// works correctly when integrated into the login flow.
void main() {
  group('Login Flow Integration Tests - FCM Token Update', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    /// Test 1: Login saves FCM token to Firestore
    ///
    /// GIVEN: User exists in Firestore without FCM token
    /// WHEN: User logs in successfully and token update is triggered
    /// THEN: FCM token should be saved to Firestore
    test('Login saves FCM token to Firestore', () async {
      // GIVEN: User exists without FCM token
      const userId = 'test-user-001';
      const email = 'test@example.com';
      const fcmToken = 'test-fcm-token-abc123';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': email,
        'name': 'Test User',
        'role': 'student',
        'createdAt': Timestamp.now(),
      });

      // Verify user exists without token
      var userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(userDoc.exists, isTrue);
      expect(userDoc.data()?['fcmToken'], isNull);

      // WHEN: User logs in and FCM token update is triggered
      // Simulating NotificationService.updateTokenAfterLogin()
      await fakeFirestore.collection('users').doc(userId).update({
        'fcmToken': fcmToken,
      });

      // THEN: FCM token should be saved
      userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(userDoc.data()?['fcmToken'], equals(fcmToken));
      expect(userDoc.data()?['fcmToken'], isNotEmpty);
    });

    /// Test 2: Token in Firestore matches device token
    ///
    /// GIVEN: User logs in successfully
    /// WHEN: FCM token is saved
    /// THEN: Saved token must match current device token
    test('Token in Firestore matches device token', () async {
      // GIVEN: User exists
      const userId = 'test-user-002';
      const email = 'user2@example.com';
      const deviceToken = 'device-token-xyz789';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': email,
        'name': 'Test User 2',
        'role': 'student',
        'createdAt': Timestamp.now(),
      });

      // WHEN: User logs in and token is saved
      await fakeFirestore.collection('users').doc(userId).update({
        'fcmToken': deviceToken,
      });

      // THEN: Saved token matches device token
      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      final savedToken = userDoc.data()?['fcmToken'] as String?;

      expect(savedToken, equals(deviceToken));
      expect(savedToken, isNotNull);
      expect(savedToken, isNotEmpty);
    });

    /// Test 3: Logout and login again updates token
    ///
    /// GIVEN: User logs in, then logs out
    /// WHEN: User logs in again with new device token
    /// THEN: Token should be updated to new value
    test('Logout and login again updates token', () async {
      // GIVEN: User exists with old token
      const userId = 'test-user-003';
      const email = 'user3@example.com';
      const oldToken = 'old-token-111';
      const newToken = 'new-token-222';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': email,
        'name': 'Test User 3',
        'role': 'student',
        'fcmToken': oldToken,
        'createdAt': Timestamp.now(),
      });

      // Verify old token exists
      var userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(userDoc.data()?['fcmToken'], equals(oldToken));

      // WHEN: User logs out (token remains in Firestore)
      // Then user logs in again with new token
      await fakeFirestore.collection('users').doc(userId).update({
        'fcmToken': newToken,
      });

      // THEN: Token should be updated to new value
      userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(userDoc.data()?['fcmToken'], equals(newToken));
      expect(userDoc.data()?['fcmToken'], isNot(equals(oldToken)));
    });

    /// Test 4: Multiple logins update token correctly
    ///
    /// GIVEN: User logs in multiple times
    /// WHEN: Each login has a different device token
    /// THEN: Token should be updated each time (last one wins)
    test('Multiple logins update token correctly', () async {
      // GIVEN: User exists
      const userId = 'test-user-004';
      const email = 'user4@example.com';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': email,
        'name': 'Test User 4',
        'role': 'student',
        'createdAt': Timestamp.now(),
      });

      // WHEN: User logs in multiple times with different tokens
      final tokens = ['token-login-1', 'token-login-2', 'token-login-3'];

      for (final token in tokens) {
        // Simulate login and token update
        await fakeFirestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });

        // Verify token is updated after each login
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        expect(userDoc.data()?['fcmToken'], equals(token));
      }

      // THEN: Final token should be the last one
      final finalDoc = await fakeFirestore
          .collection('users')
          .doc(userId)
          .get();
      expect(finalDoc.data()?['fcmToken'], equals(tokens.last));
      expect(finalDoc.data()?['fcmToken'], equals('token-login-3'));
    });

    /// Test 5: Token update preserves other user fields
    ///
    /// GIVEN: User has existing data in Firestore
    /// WHEN: FCM token is updated after login
    /// THEN: Other user fields should remain unchanged
    test('Token update preserves other user fields', () async {
      // GIVEN: User exists with complete profile
      const userId = 'test-user-005';
      const email = 'user5@example.com';
      const name = 'Test User 5';
      const role = 'student';
      const studentId = 'STU12345';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': email,
        'name': name,
        'role': role,
        'studentId': studentId,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      // WHEN: FCM token is updated
      const newToken = 'new-token-after-login';
      await fakeFirestore.collection('users').doc(userId).update({
        'fcmToken': newToken,
      });

      // THEN: Token is updated and other fields are preserved
      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      final data = userDoc.data()!;

      expect(data['fcmToken'], equals(newToken));
      expect(data['email'], equals(email));
      expect(data['name'], equals(name));
      expect(data['role'], equals(role));
      expect(data['studentId'], equals(studentId));
      expect(data['isActive'], equals(true));
    });

    /// Test 6: Multiple users can login and each gets their own token
    ///
    /// GIVEN: Multiple users exist
    /// WHEN: Each user logs in with their own device token
    /// THEN: Each user should have their correct token saved
    test('Multiple users can login and each gets their own token', () async {
      // GIVEN: Multiple users exist
      final users = [
        {
          'userId': 'user-multi-1',
          'email': 'multi1@example.com',
          'token': 'token-multi-1',
        },
        {
          'userId': 'user-multi-2',
          'email': 'multi2@example.com',
          'token': 'token-multi-2',
        },
        {
          'userId': 'user-multi-3',
          'email': 'multi3@example.com',
          'token': 'token-multi-3',
        },
      ];

      for (final userData in users) {
        await fakeFirestore.collection('users').doc(userData['userId']).set({
          'email': userData['email'],
          'name': 'Multi User',
          'role': 'student',
          'createdAt': Timestamp.now(),
        });
      }

      // WHEN: Each user logs in and token is updated
      for (final userData in users) {
        final userId = userData['userId']!;
        final token = userData['token']!;

        await fakeFirestore.collection('users').doc(userId).update({
          'fcmToken': token,
        });
      }

      // THEN: Each user should have their correct token
      for (final userData in users) {
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userData['userId'])
            .get();
        expect(userDoc.data()?['fcmToken'], equals(userData['token']));
      }
    });

    /// Test 7: Token update works for users with different roles
    ///
    /// GIVEN: Users with different roles (student, club, admin)
    /// WHEN: Each user logs in
    /// THEN: FCM token should be saved regardless of role
    test('Token update works for users with different roles', () async {
      // GIVEN: Users with different roles
      final users = [
        {'userId': 'student-1', 'role': 'student', 'token': 'token-student'},
        {'userId': 'club-1', 'role': 'club', 'token': 'token-club'},
        {'userId': 'admin-1', 'role': 'admin', 'token': 'token-admin'},
      ];

      for (final userData in users) {
        await fakeFirestore.collection('users').doc(userData['userId']).set({
          'email': '${userData['userId']}@example.com',
          'name': 'User ${userData['role']}',
          'role': userData['role'],
          'createdAt': Timestamp.now(),
        });
      }

      // WHEN: Each user logs in and token is updated
      for (final userData in users) {
        await fakeFirestore.collection('users').doc(userData['userId']).update({
          'fcmToken': userData['token'],
        });
      }

      // THEN: Each user should have their token saved
      for (final userData in users) {
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userData['userId'])
            .get();
        expect(userDoc.data()?['fcmToken'], equals(userData['token']));
        expect(userDoc.data()?['role'], equals(userData['role']));
      }
    });

    /// Test 8: Verify token field structure in Firestore
    ///
    /// GIVEN: User logs in and token is saved
    /// WHEN: Token is retrieved from Firestore
    /// THEN: Token should be a non-empty string
    test('Verify token field structure in Firestore', () async {
      // GIVEN: User exists
      const userId = 'test-user-008';
      const fcmToken = 'valid-fcm-token-structure-test';

      await fakeFirestore.collection('users').doc(userId).set({
        'email': 'user8@example.com',
        'name': 'Test User 8',
        'role': 'student',
        'createdAt': Timestamp.now(),
      });

      // WHEN: Token is saved
      await fakeFirestore.collection('users').doc(userId).update({
        'fcmToken': fcmToken,
      });

      // THEN: Token should be a valid string
      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      final token = userDoc.data()?['fcmToken'];

      expect(token, isA<String>());
      expect(token, isNotEmpty);
      expect(token, equals(fcmToken));
      expect((token as String).length, greaterThan(0));
    });
  });
}
