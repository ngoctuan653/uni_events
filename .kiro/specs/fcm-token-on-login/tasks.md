# Implementation Tasks

## Task 1: Write Bug Condition Exploration Property Test

Write a property-based test that explores the bug condition C(X): "User X không có FCM token hợp lệ trong Firestore sau khi đăng nhập thành công"

**Acceptance Criteria**:
- [ ] Create test file `test/fcm_token_bug_exploration_test.dart`
- [ ] Test MUST fail on current code (confirming bug exists)
- [ ] Test simulates user login without FCM token update
- [ ] Test checks Firestore for missing/null fcmToken field
- [ ] Test generates counterexamples showing users without tokens after login
- [ ] Test includes clear documentation of bug condition

**Files to modify**:
- `test/fcm_token_bug_exploration_test.dart` (create new)

---

## Task 2: Add updateTokenAfterLogin() Method to NotificationService

Implement the new `updateTokenAfterLogin()` method in NotificationService that retrieves and saves FCM token after user login.

**Acceptance Criteria**:
- [ ] Add `updateTokenAfterLogin()` method to `lib/services/notification_services.dart`
- [ ] Method checks if platform is web and skips if true
- [ ] Method checks if user is logged in (currentUser != null)
- [ ] Method gets current FCM token using `_fcm.getToken()`
- [ ] Method calls existing `saveTokenToDatabase()` with token
- [ ] Method includes error handling with try-catch
- [ ] Method includes logging for debugging
- [ ] Method is async and returns Future<void>

**Files to modify**:
- `lib/services/notification_services.dart`

---

## Task 3: Update AuthService.login() to Call updateTokenAfterLogin()

Modify the login method in AuthService to call NotificationService.updateTokenAfterLogin() after successful authentication.

**Acceptance Criteria**:
- [ ] Import NotificationService in `lib/services/auth_services.dart`
- [ ] Call `NotificationService().updateTokenAfterLogin()` after successful login
- [ ] Call happens AFTER user role is fetched
- [ ] Wrap call in try-catch to prevent login failure if token update fails
- [ ] Log error if token update fails but don't throw
- [ ] Login flow continues to return user role successfully

**Files to modify**:
- `lib/services/auth_services.dart`

---

## Task 4: Write Unit Tests for updateTokenAfterLogin()

Create comprehensive unit tests for the new updateTokenAfterLogin() method covering all scenarios.

**Acceptance Criteria**:
- [ ] Create test file `test/notification_service_update_token_test.dart`
- [ ] Test: updateTokenAfterLogin() with valid user and token
- [ ] Test: updateTokenAfterLogin() with no logged-in user
- [ ] Test: updateTokenAfterLogin() with null token
- [ ] Test: updateTokenAfterLogin() on web platform (skip logic)
- [ ] Test: updateTokenAfterLogin() with Firestore error
- [ ] All tests use mocks for Firebase dependencies
- [ ] All tests pass

**Files to modify**:
- `test/notification_service_update_token_test.dart` (create new)

---

## Task 5: Write Integration Test for Login Flow

Create integration test that verifies FCM token is saved to Firestore after user login.

**Acceptance Criteria**:
- [ ] Create test file `test/login_fcm_token_integration_test.dart`
- [ ] Test: Login saves FCM token to Firestore
- [ ] Test: Token in Firestore matches device token
- [ ] Test: Logout and login again updates token
- [ ] Test: Multiple logins update token correctly
- [ ] Use fake_cloud_firestore for Firestore mocking
- [ ] Use mockito for Firebase Auth and Messaging mocking
- [ ] All tests pass

**Files to modify**:
- `test/login_fcm_token_integration_test.dart` (create new)

---

## Task 6: Write Fix Verification Property Test

Write property-based test that verifies the bug is fixed: FCM token MUST be saved after login.

**Acceptance Criteria**:
- [ ] Create test file `test/fcm_token_fix_verification_test.dart`
- [ ] Test MUST pass on fixed code (confirming bug is fixed)
- [ ] Test verifies Property 1: Token saved after login
- [ ] Test verifies Property 2: Token matches device token
- [ ] Test generates random user login scenarios
- [ ] Test checks all scenarios have valid FCM tokens in Firestore
- [ ] Test includes clear documentation of fix verification

**Files to modify**:
- `test/fcm_token_fix_verification_test.dart` (create new)

---

## Task 7: Write Preservation Property Tests

Write property-based tests that verify existing behavior is preserved (no regressions).

**Acceptance Criteria**:
- [x] Create test file `test/fcm_token_preservation_test.dart`
- [x] Test: NotificationService.init() still saves token for logged-in users
- [x] Test: onTokenRefresh listener still updates token
- [x] Test: Token not saved when user is not logged in
- [x] Test: Register flow continues to work normally
- [x] All tests pass on both old and new code
- [x] Tests confirm no regressions introduced

**Files to modify**:
- `test/fcm_token_preservation_test.dart` (create new)

---

## Task 8: Manual Testing and Documentation

Perform manual testing on real devices and document results.

**Acceptance Criteria**:
- [x] Test on Android device: Fresh install → Login → Verify token in Firestore
- [x] Test on Android device: Logout → Login → Verify token updated
- [x] Test on iOS device: Fresh install → Login → Verify token in Firestore
- [x] Test on iOS device: Logout → Login → Verify token updated
- [x] Test on web: Verify FCM token update is skipped
- [x] Send test notification after login and verify delivery
- [x] Document test results in `test/MANUAL_TESTING_RESULTS.md`
- [x] Verify no "no FCM token" errors in logs after login

**Files to modify**:
- `test/MANUAL_TESTING_RESULTS.md` (create new)

---

## Task 9: Update Documentation

Update relevant documentation to reflect the FCM token update on login.

**Acceptance Criteria**:
- [x] Update `NOTIFICATION_TEST_GUIDE.md` with new login flow
- [x] Add section explaining FCM token update on login
- [x] Add troubleshooting section for token issues
- [x] Document expected behavior after login
- [x] Include code examples if needed

**Files to modify**:
- `NOTIFICATION_TEST_GUIDE.md`

---

## Summary

**Total Tasks**: 9
**Estimated Effort**: 
- Task 1: 1 hour (exploration test)
- Task 2: 1 hour (implementation)
- Task 3: 30 minutes (integration)
- Task 4: 2 hours (unit tests)
- Task 5: 2 hours (integration test)
- Task 6: 1 hour (fix verification)
- Task 7: 2 hours (preservation tests)
- Task 8: 2 hours (manual testing)
- Task 9: 30 minutes (documentation)

**Total**: ~12 hours

**Priority**: HIGH (blocks user notifications)

**Dependencies**:
- Task 2 depends on Task 1 (understand bug first)
- Task 3 depends on Task 2 (method must exist)
- Tasks 4-7 depend on Tasks 2-3 (code must exist to test)
- Task 8 depends on all previous tasks (code must be complete)
- Task 9 can be done in parallel with testing
