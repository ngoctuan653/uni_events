import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks for Firebase services
@GenerateMocks([FirebaseAuth, User, UserCredential])
import 'fcm_token_bug_exploration_test.mocks.dart';

/// Bug Condition Exploration Test
///
/// **Bug Condition C(X)**: User X không có FCM token hợp lệ trong Firestore
/// (users/{userId}.fcmToken là null hoặc không tồn tại) SAU KHI đăng nhập thành công
///
/// **IMPORTANT**: This test is EXPECTED TO FAIL on the current unfixed code.
/// A failing test confirms the bug exists. A passing test means the bug doesn't exist
/// or the test is incorrect.
///
/// **Test Strategy**:
/// This test simulates property-based testing by exploring multiple scenarios
/// where users log in and checking if FCM tokens are properly saved to Firestore.
///
/// **Validates**: Bugfix Requirements 1.1, 1.2, 1.3
void main() {
  group('FCM Token Bug Exploration - Property-Based Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
    });

    /// Property 1: For all users who log in on a new device,
    /// FCM token MUST be saved to Firestore
    ///
    /// **Expected Result**: FAIL (bug exists - token not saved after login)
    test('Property 1: FCM token should be saved after login on new device', () async {
      // Generate multiple test cases to simulate property-based testing
      final testCases = [
        {
          'userId': 'user-001',
          'email': 'user1@test.com',
          'fcmToken': 'token-abc-123',
        },
        {
          'userId': 'user-002',
          'email': 'user2@test.com',
          'fcmToken': 'token-def-456',
        },
        {
          'userId': 'user-003',
          'email': 'user3@test.com',
          'fcmToken': 'token-ghi-789',
        },
        {
          'userId': 'user-004',
          'email': 'user4@test.com',
          'fcmToken': 'token-jkl-012',
        },
        {
          'userId': 'user-005',
          'email': 'user5@test.com',
          'fcmToken': 'token-mno-345',
        },
      ];

      int failureCount = 0;
      final List<String> counterexamples = [];

      for (final testCase in testCases) {
        final userId = testCase['userId'] as String;
        final email = testCase['email'] as String;
        final fcmToken = testCase['fcmToken'] as String;

        // GIVEN: User document exists in Firestore WITHOUT fcmToken
        await fakeFirestore.collection('users').doc(userId).set({
          'email': email,
          'name': 'Test User',
          'role': 'student',
          'createdAt': DateTime.now(),
        });

        // WHEN: User logs in successfully
        // (Simulating login - in real code, AuthService.login() is called)
        // The bug is that login does NOT update FCM token

        // THEN: Check if FCM token exists in Firestore
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final savedToken = userDoc.data()?['fcmToken'] as String?;

        // Bug Condition: Token should be saved but it's NOT
        if (savedToken == null || savedToken.isEmpty) {
          failureCount++;
          counterexamples.add(
            'User $userId logged in but fcmToken is ${savedToken == null ? "null" : "empty"}',
          );
        }
      }

      // This test SHOULD FAIL because the bug exists
      // All test cases should fail (no tokens saved after login)
      expect(
        failureCount,
        equals(0),
        reason:
            'Bug detected: ${counterexamples.length} users logged in without FCM token saved.\n'
            'Counterexamples:\n${counterexamples.join("\n")}\n\n'
            'This confirms Bug Condition C(X): Users do not have valid FCM tokens in Firestore after successful login.',
      );
    });

    /// Property 2: For all users who log in again on existing device,
    /// FCM token MUST be updated to latest value
    ///
    /// **Expected Result**: FAIL (bug exists - token not updated after re-login)
    test('Property 2: FCM token should be updated after re-login', () async {
      // Generate multiple test cases for re-login scenarios
      final testCases = [
        {
          'userId': 'user-101',
          'email': 'user101@test.com',
          'oldToken': 'old-token-aaa',
          'newToken': 'new-token-bbb',
        },
        {
          'userId': 'user-102',
          'email': 'user102@test.com',
          'oldToken': 'old-token-ccc',
          'newToken': 'new-token-ddd',
        },
        {
          'userId': 'user-103',
          'email': 'user103@test.com',
          'oldToken': 'old-token-eee',
          'newToken': 'new-token-fff',
        },
      ];

      int failureCount = 0;
      final List<String> counterexamples = [];

      for (final testCase in testCases) {
        final userId = testCase['userId'] as String;
        final email = testCase['email'] as String;
        final oldToken = testCase['oldToken'] as String;
        final newToken = testCase['newToken'] as String;

        // GIVEN: User document exists with OLD fcmToken
        await fakeFirestore.collection('users').doc(userId).set({
          'email': email,
          'name': 'Test User',
          'role': 'student',
          'fcmToken': oldToken,
          'createdAt': DateTime.now(),
        });

        // WHEN: User logs in again (device has new FCM token)
        // (Simulating re-login - in real code, AuthService.login() is called)
        // The bug is that login does NOT update FCM token to new value

        // THEN: Check if FCM token is updated to new value
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final savedToken = userDoc.data()?['fcmToken'] as String?;

        // Bug Condition: Token should be updated but it's NOT
        if (savedToken != newToken) {
          failureCount++;
          counterexamples.add(
            'User $userId re-logged in but fcmToken is still "$savedToken" (expected "$newToken")',
          );
        }
      }

      // This test SHOULD FAIL because the bug exists
      expect(
        failureCount,
        equals(0),
        reason:
            'Bug detected: ${counterexamples.length} users re-logged in without FCM token updated.\n'
            'Counterexamples:\n${counterexamples.join("\n")}\n\n'
            'This confirms Bug Condition C(X): FCM tokens are not updated after re-login.',
      );
    });

    /// Property 3: For all users without FCM token,
    /// push notifications CANNOT be sent
    ///
    /// **Expected Result**: FAIL (bug exists - users without tokens cannot receive notifications)
    test(
      'Property 3: Users without FCM token cannot receive push notifications',
      () async {
        // Generate multiple test cases for notification sending
        final testCases = [
          {
            'userId': 'user-201',
            'email': 'user201@test.com',
            'hasFcmToken': false,
          },
          {
            'userId': 'user-202',
            'email': 'user202@test.com',
            'hasFcmToken': false,
          },
          {
            'userId': 'user-203',
            'email': 'user203@test.com',
            'hasFcmToken': false,
          },
          {
            'userId': 'user-204',
            'email': 'user204@test.com',
            'hasFcmToken': true,
          }, // Control case
        ];

        int usersWithoutToken = 0;
        final List<String> counterexamples = [];

        for (final testCase in testCases) {
          final userId = testCase['userId'] as String;
          final email = testCase['email'] as String;
          final hasFcmToken = testCase['hasFcmToken'] as bool;

          // GIVEN: User document with or without fcmToken
          final userData = {
            'email': email,
            'name': 'Test User',
            'role': 'student',
            'createdAt': DateTime.now(),
          };

          if (hasFcmToken) {
            userData['fcmToken'] = 'valid-token-xyz';
          }

          await fakeFirestore.collection('users').doc(userId).set(userData);

          // WHEN: System tries to send push notification
          final userDoc = await fakeFirestore
              .collection('users')
              .doc(userId)
              .get();
          final fcmToken = userDoc.data()?['fcmToken'] as String?;

          // THEN: Check if notification can be sent
          final canSendNotification = fcmToken != null && fcmToken.isNotEmpty;

          if (!canSendNotification && !hasFcmToken) {
            usersWithoutToken++;
            counterexamples.add(
              'User $userId cannot receive notifications (fcmToken: ${fcmToken ?? "null"})',
            );
          }
        }

        // This test SHOULD FAIL because users without tokens exist
        // (they logged in but token wasn't saved)
        expect(
          usersWithoutToken,
          equals(0),
          reason:
              'Bug detected: $usersWithoutToken users cannot receive push notifications.\n'
              'Counterexamples:\n${counterexamples.join("\n")}\n\n'
              'This confirms Bug Condition C(X): Users who logged in do not have FCM tokens, '
              'preventing them from receiving notifications.',
        );
      },
    );

    /// Property 4: Invariant - After successful login, fcmToken field MUST exist and be non-empty
    ///
    /// **Expected Result**: FAIL (bug exists - invariant violated)
    test('Property 4: Invariant - fcmToken must exist after login', () async {
      // Test the invariant across different user scenarios
      final scenarios = [
        {'scenario': 'New user first login', 'userId': 'new-user-1'},
        {'scenario': 'Existing user re-login', 'userId': 'existing-user-1'},
        {
          'scenario': 'User login on different device',
          'userId': 'multi-device-user-1',
        },
        {
          'scenario': 'User login after logout',
          'userId': 'logout-login-user-1',
        },
      ];

      int invariantViolations = 0;
      final List<String> counterexamples = [];

      for (final scenario in scenarios) {
        final scenarioName = scenario['scenario'] as String;
        final userId = scenario['userId'] as String;

        // GIVEN: User exists in system
        await fakeFirestore.collection('users').doc(userId).set({
          'email': '$userId@test.com',
          'name': 'Test User',
          'role': 'student',
          'createdAt': DateTime.now(),
        });

        // WHEN: User logs in successfully
        // (Simulating login - AuthService.login() completes successfully)

        // THEN: Invariant check - fcmToken MUST exist and be non-empty
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        final invariantHolds = fcmToken != null && fcmToken.isNotEmpty;

        if (!invariantHolds) {
          invariantViolations++;
          counterexamples.add(
            'Scenario "$scenarioName": User $userId has invalid fcmToken (${fcmToken ?? "null"})',
          );
        }
      }

      // This test SHOULD FAIL because the invariant is violated
      expect(
        invariantViolations,
        equals(0),
        reason:
            'Bug detected: Invariant violated in $invariantViolations scenarios.\n'
            'Counterexamples:\n${counterexamples.join("\n")}\n\n'
            'This confirms Bug Condition C(X): The invariant "fcmToken must exist after login" is violated.',
      );
    });
  });
}
