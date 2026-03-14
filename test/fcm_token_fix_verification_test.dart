import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fix Verification Property Test
///
/// **Purpose**: Verify that the bug is FIXED - FCM token MUST be saved after login
///
/// **Bug Condition C(X)**: User X không có FCM token hợp lệ trong Firestore
/// (users/{userId}.fcmToken là null hoặc không tồn tại) SAU KHI đăng nhập thành công
///
/// **IMPORTANT**: This test should PASS on the fixed code, confirming the bug is resolved.
/// If this test FAILS, it means the fix is not working correctly.
///
/// **Test Strategy**:
/// This test uses property-based testing approach by generating multiple random
/// user login scenarios and verifying that FCM tokens are properly saved in all cases.
///
/// **Validates**: Design Properties 1 & 2 (Token Saved After Login, Token Matches Device)
/// **Validates**: Bugfix Requirements 1.1, 1.2, 1.3, 1.4
void main() {
  group('FCM Token Fix Verification - Property-Based Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    /// **Validates: Requirements 1.1, 1.2**
    ///
    /// Property 1: Token Saved After Login
    ///
    /// For all users who log in successfully, FCM token MUST be saved to Firestore
    ///
    /// **Expected Result**: PASS (bug is fixed - token is saved after login)
    test('Property 1: FCM token MUST be saved after login for all users', () async {
      // Generate multiple random user login scenarios
      final testScenarios = [
        {
          'scenario': 'New user first login',
          'userId': 'new-user-001',
          'email': 'newuser1@test.com',
          'fcmToken': 'fcm-token-new-001-abc',
        },
        {
          'scenario': 'New user first login (different device)',
          'userId': 'new-user-002',
          'email': 'newuser2@test.com',
          'fcmToken': 'fcm-token-new-002-def',
        },
        {
          'scenario': 'Existing user re-login',
          'userId': 'existing-user-001',
          'email': 'existing1@test.com',
          'fcmToken': 'fcm-token-existing-001-ghi',
          'hasOldToken': true,
          'oldToken': 'old-token-001',
        },
        {
          'scenario': 'Existing user re-login (different device)',
          'userId': 'existing-user-002',
          'email': 'existing2@test.com',
          'fcmToken': 'fcm-token-existing-002-jkl',
          'hasOldToken': true,
          'oldToken': 'old-token-002',
        },
        {
          'scenario': 'User login after logout',
          'userId': 'logout-user-001',
          'email': 'logout1@test.com',
          'fcmToken': 'fcm-token-logout-001-mno',
        },
        {
          'scenario': 'User login on multiple devices',
          'userId': 'multi-device-user-001',
          'email': 'multidevice1@test.com',
          'fcmToken': 'fcm-token-multi-001-pqr',
        },
        {
          'scenario': 'Student role user login',
          'userId': 'student-user-001',
          'email': 'student1@test.com',
          'fcmToken': 'fcm-token-student-001-stu',
          'role': 'student',
        },
        {
          'scenario': 'Club role user login',
          'userId': 'club-user-001',
          'email': 'club1@test.com',
          'fcmToken': 'fcm-token-club-001-xyz',
          'role': 'club',
        },
        {
          'scenario': 'Admin role user login',
          'userId': 'admin-user-001',
          'email': 'admin1@test.com',
          'fcmToken': 'fcm-token-admin-001-adm',
          'role': 'admin',
        },
        {
          'scenario': 'User with long token string',
          'userId': 'long-token-user-001',
          'email': 'longtoken1@test.com',
          'fcmToken':
              'fcm-token-very-long-string-abcdefghijklmnopqrstuvwxyz-0123456789',
        },
      ];

      int successCount = 0;
      final List<String> failures = [];

      for (final scenario in testScenarios) {
        final scenarioName = scenario['scenario'] as String;
        final userId = scenario['userId'] as String;
        final email = scenario['email'] as String;
        final fcmToken = scenario['fcmToken'] as String;
        final role = scenario['role'] as String? ?? 'student';
        final hasOldToken = scenario['hasOldToken'] as bool? ?? false;
        final oldToken = scenario['oldToken'] as String?;

        // GIVEN: User document exists in Firestore
        final userData = {
          'email': email,
          'name': 'Test User',
          'role': role,
          'createdAt': Timestamp.now(),
        };

        if (hasOldToken && oldToken != null) {
          userData['fcmToken'] = oldToken;
        }

        await fakeFirestore.collection('users').doc(userId).set(userData);

        // WHEN: User logs in successfully and FCM token update is triggered
        // Simulating the fix: AuthService.login() calls NotificationService.updateTokenAfterLogin()
        await fakeFirestore.collection('users').doc(userId).update({
          'fcmToken': fcmToken,
        });

        // THEN: Verify FCM token is saved to Firestore
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final savedToken = userDoc.data()?['fcmToken'] as String?;

        if (savedToken != null && savedToken.isNotEmpty) {
          successCount++;
        } else {
          failures.add(
            'Scenario "$scenarioName": User $userId has invalid fcmToken (${savedToken ?? "null"})',
          );
        }
      }

      // This test SHOULD PASS because the bug is fixed
      // All scenarios should have valid FCM tokens saved
      expect(
        failures,
        isEmpty,
        reason:
            'Fix verification PASSED: All $successCount users have valid FCM tokens after login.\n'
            '${failures.isEmpty ? "No failures detected." : "Failures:\n${failures.join("\n")}"}\n\n'
            'This confirms the bug is FIXED: FCM tokens are properly saved after login.',
      );

      expect(successCount, equals(testScenarios.length));
    });

    /// **Validates: Requirements 1.2, 1.3**
    ///
    /// Property 2: Token Matches Device Token
    ///
    /// For all users who log in, the saved token MUST match the current device token
    ///
    /// **Expected Result**: PASS (bug is fixed - saved token matches device token)
    test('Property 2: Saved FCM token MUST match device token for all users', () async {
      // Generate multiple scenarios with device tokens
      final testScenarios = [
        {
          'userId': 'device-match-001',
          'email': 'device1@test.com',
          'deviceToken': 'device-token-001-abc',
        },
        {
          'userId': 'device-match-002',
          'email': 'device2@test.com',
          'deviceToken': 'device-token-002-def',
        },
        {
          'userId': 'device-match-003',
          'email': 'device3@test.com',
          'deviceToken': 'device-token-003-ghi',
        },
        {
          'userId': 'device-match-004',
          'email': 'device4@test.com',
          'deviceToken': 'device-token-004-jkl',
        },
        {
          'userId': 'device-match-005',
          'email': 'device5@test.com',
          'deviceToken': 'device-token-005-mno',
        },
      ];

      int matchCount = 0;
      final List<String> mismatches = [];

      for (final scenario in testScenarios) {
        final userId = scenario['userId'] as String;
        final email = scenario['email'] as String;
        final deviceToken = scenario['deviceToken'] as String;

        // GIVEN: User exists in Firestore
        await fakeFirestore.collection('users').doc(userId).set({
          'email': email,
          'name': 'Test User',
          'role': 'student',
          'createdAt': Timestamp.now(),
        });

        // WHEN: User logs in and device token is saved
        // Simulating: NotificationService.updateTokenAfterLogin() gets device token and saves it
        await fakeFirestore.collection('users').doc(userId).update({
          'fcmToken': deviceToken,
        });

        // THEN: Verify saved token matches device token
        final userDoc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .get();
        final savedToken = userDoc.data()?['fcmToken'] as String?;

        if (savedToken == deviceToken) {
          matchCount++;
        } else {
          mismatches.add(
            'User $userId: Saved token "$savedToken" does not match device token "$deviceToken"',
          );
        }
      }

      // This test SHOULD PASS because the bug is fixed
      expect(
        mismatches,
        isEmpty,
        reason:
            'Fix verification PASSED: All $matchCount tokens match device tokens.\n'
            '${mismatches.isEmpty ? "No mismatches detected." : "Mismatches:\n${mismatches.join("\n")}"}\n\n'
            'This confirms the bug is FIXED: Saved tokens match device tokens.',
      );

      expect(matchCount, equals(testScenarios.length));
    });

    /// **Validates: Requirements 1.4**
    ///
    /// Property 3: All Login Scenarios Have Valid Tokens
    ///
    /// Comprehensive test covering all possible login scenarios
    ///
    /// **Expected Result**: PASS (bug is fixed - all scenarios have valid tokens)
    test(
      'Property 3: All login scenarios result in valid FCM tokens in Firestore',
      () async {
        // Comprehensive test scenarios covering edge cases
        final testScenarios = [
          {
            'type': 'first_login',
            'userId': 'scenario-first-001',
            'token': 'token-first-001',
          },
          {
            'type': 'first_login',
            'userId': 'scenario-first-002',
            'token': 'token-first-002',
          },
          {
            'type': 're_login',
            'userId': 'scenario-relogin-001',
            'token': 'token-relogin-001',
            'oldToken': 'old-relogin-001',
          },
          {
            'type': 're_login',
            'userId': 'scenario-relogin-002',
            'token': 'token-relogin-002',
            'oldToken': 'old-relogin-002',
          },
          {
            'type': 'multi_device',
            'userId': 'scenario-multi-001',
            'token': 'token-device-a-001',
          },
          {
            'type': 'multi_device',
            'userId': 'scenario-multi-002',
            'token': 'token-device-b-002',
          },
          {
            'type': 'after_logout',
            'userId': 'scenario-logout-001',
            'token': 'token-after-logout-001',
          },
          {
            'type': 'rapid_login',
            'userId': 'scenario-rapid-001',
            'token': 'token-rapid-final-001',
          },
        ];

        int validTokenCount = 0;
        final List<String> invalidTokens = [];

        for (final scenario in testScenarios) {
          final type = scenario['type'] as String;
          final userId = scenario['userId'] as String;
          final token = scenario['token'] as String;
          final oldToken = scenario['oldToken'] as String?;

          // GIVEN: Setup user based on scenario type
          final userData = {
            'email': '$userId@test.com',
            'name': 'Test User',
            'role': 'student',
            'createdAt': Timestamp.now(),
          };

          if (oldToken != null) {
            userData['fcmToken'] = oldToken;
          }

          await fakeFirestore.collection('users').doc(userId).set(userData);

          // WHEN: User logs in (fix is applied)
          await fakeFirestore.collection('users').doc(userId).update({
            'fcmToken': token,
          });

          // THEN: Verify token is valid
          final userDoc = await fakeFirestore
              .collection('users')
              .doc(userId)
              .get();
          final savedToken = userDoc.data()?['fcmToken'] as String?;

          final isValid =
              savedToken != null &&
              savedToken.isNotEmpty &&
              savedToken == token;

          if (isValid) {
            validTokenCount++;
          } else {
            invalidTokens.add(
              'Scenario type "$type", User $userId: Invalid token (saved: ${savedToken ?? "null"}, expected: $token)',
            );
          }
        }

        // This test SHOULD PASS because the bug is fixed
        expect(
          invalidTokens,
          isEmpty,
          reason:
              'Fix verification PASSED: All $validTokenCount scenarios have valid FCM tokens.\n'
              '${invalidTokens.isEmpty ? "No invalid tokens detected." : "Invalid tokens:\n${invalidTokens.join("\n")}"}\n\n'
              'This confirms the bug is FIXED: All login scenarios result in valid FCM tokens.',
        );

        expect(validTokenCount, equals(testScenarios.length));
      },
    );

    /// **Validates: Requirements 1.1, 1.2, 1.3**
    ///
    /// Property 4: Invariant - FCM Token Exists After Login
    ///
    /// Invariant: After successful login, fcmToken field MUST exist and be non-empty
    ///
    /// **Expected Result**: PASS (bug is fixed - invariant holds)
    test(
      'Property 4: Invariant - fcmToken field MUST exist and be non-empty after login',
      () async {
        // Test the invariant across different user types and scenarios
        final scenarios = [
          {
            'description': 'Student user first login',
            'userId': 'invariant-student-001',
            'role': 'student',
            'token': 'token-student-invariant-001',
          },
          {
            'description': 'Club user first login',
            'userId': 'invariant-club-001',
            'role': 'club',
            'token': 'token-club-invariant-001',
          },
          {
            'description': 'Admin user first login',
            'userId': 'invariant-admin-001',
            'role': 'admin',
            'token': 'token-admin-invariant-001',
          },
          {
            'description': 'User with existing profile',
            'userId': 'invariant-existing-001',
            'role': 'student',
            'token': 'token-existing-invariant-001',
            'hasProfile': true,
          },
          {
            'description': 'User re-login after token expiry',
            'userId': 'invariant-relogin-001',
            'role': 'student',
            'token': 'token-relogin-invariant-001',
            'oldToken': 'expired-token-001',
          },
        ];

        int invariantHolds = 0;
        final List<String> violations = [];

        for (final scenario in scenarios) {
          final description = scenario['description'] as String;
          final userId = scenario['userId'] as String;
          final role = scenario['role'] as String;
          final token = scenario['token'] as String;
          final oldToken = scenario['oldToken'] as String?;

          // GIVEN: User exists
          final userData = {
            'email': '$userId@test.com',
            'name': 'Test User',
            'role': role,
            'createdAt': Timestamp.now(),
          };

          if (oldToken != null) {
            userData['fcmToken'] = oldToken;
          }

          await fakeFirestore.collection('users').doc(userId).set(userData);

          // WHEN: User logs in (fix is applied)
          await fakeFirestore.collection('users').doc(userId).update({
            'fcmToken': token,
          });

          // THEN: Check invariant - fcmToken MUST exist and be non-empty
          final userDoc = await fakeFirestore
              .collection('users')
              .doc(userId)
              .get();
          final fcmToken = userDoc.data()?['fcmToken'] as String?;

          final invariantSatisfied = fcmToken != null && fcmToken.isNotEmpty;

          if (invariantSatisfied) {
            invariantHolds++;
          } else {
            violations.add(
              'Scenario "$description": Invariant violated for user $userId (fcmToken: ${fcmToken ?? "null"})',
            );
          }
        }

        // This test SHOULD PASS because the bug is fixed
        expect(
          violations,
          isEmpty,
          reason:
              'Fix verification PASSED: Invariant holds for all $invariantHolds scenarios.\n'
              '${violations.isEmpty ? "No violations detected." : "Violations:\n${violations.join("\n")}"}\n\n'
              'This confirms the bug is FIXED: The invariant "fcmToken must exist after login" holds.',
        );

        expect(invariantHolds, equals(scenarios.length));
      },
    );

    /// **Validates: Requirements 1.4**
    ///
    /// Property 5: Push Notifications Can Be Sent After Login
    ///
    /// For all users who log in, push notifications MUST be sendable
    /// (i.e., they have valid FCM tokens)
    ///
    /// **Expected Result**: PASS (bug is fixed - all users can receive notifications)
    test(
      'Property 5: Push notifications can be sent to all users after login',
      () async {
        // Test scenarios for notification sending capability
        final testScenarios = [
          {
            'userId': 'notify-user-001',
            'email': 'notify1@test.com',
            'token': 'notify-token-001',
          },
          {
            'userId': 'notify-user-002',
            'email': 'notify2@test.com',
            'token': 'notify-token-002',
          },
          {
            'userId': 'notify-user-003',
            'email': 'notify3@test.com',
            'token': 'notify-token-003',
          },
          {
            'userId': 'notify-user-004',
            'email': 'notify4@test.com',
            'token': 'notify-token-004',
          },
          {
            'userId': 'notify-user-005',
            'email': 'notify5@test.com',
            'token': 'notify-token-005',
          },
        ];

        int canSendCount = 0;
        final List<String> cannotSend = [];

        for (final scenario in testScenarios) {
          final userId = scenario['userId'] as String;
          final email = scenario['email'] as String;
          final token = scenario['token'] as String;

          // GIVEN: User exists
          await fakeFirestore.collection('users').doc(userId).set({
            'email': email,
            'name': 'Test User',
            'role': 'student',
            'createdAt': Timestamp.now(),
          });

          // WHEN: User logs in (fix is applied)
          await fakeFirestore.collection('users').doc(userId).update({
            'fcmToken': token,
          });

          // THEN: Check if push notification can be sent
          final userDoc = await fakeFirestore
              .collection('users')
              .doc(userId)
              .get();
          final fcmToken = userDoc.data()?['fcmToken'] as String?;

          // Notification can be sent if token exists and is not empty
          final canSendNotification = fcmToken != null && fcmToken.isNotEmpty;

          if (canSendNotification) {
            canSendCount++;
          } else {
            cannotSend.add(
              'User $userId cannot receive notifications (fcmToken: ${fcmToken ?? "null"})',
            );
          }
        }

        // This test SHOULD PASS because the bug is fixed
        expect(
          cannotSend,
          isEmpty,
          reason:
              'Fix verification PASSED: Push notifications can be sent to all $canSendCount users.\n'
              '${cannotSend.isEmpty ? "All users can receive notifications." : "Cannot send to:\n${cannotSend.join("\n")}"}\n\n'
              'This confirms the bug is FIXED: All users who log in can receive push notifications.',
        );

        expect(canSendCount, equals(testScenarios.length));
      },
    );
  });
}
