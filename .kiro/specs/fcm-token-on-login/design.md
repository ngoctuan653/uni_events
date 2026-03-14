# Bugfix Design Document

## Root Cause Analysis

### Bug Condition C(X)

**C(X)**: User X không có FCM token hợp lệ trong Firestore (`users/{userId}.fcmToken` là null hoặc không tồn tại) SAU KHI đăng nhập thành công

**Điều kiện xảy ra bug**:
- User đăng nhập thành công trên thiết bị mới
- User đăng nhập lại trên thiết bị đã sử dụng
- FCM token không được cập nhật vào Firestore sau khi đăng nhập

**Hậu quả**:
- Hệ thống không thể gửi push notification đến user
- Log lỗi: "Cannot send push: user {userId} has no FCM token"
- User bỏ lỡ các thông báo quan trọng về sự kiện

### Root Cause

**Nguyên nhân gốc**: Logic lấy và lưu FCM token chỉ được thực thi trong `NotificationService.init()` khi app khởi động, KHÔNG được thực thi sau khi user đăng nhập thành công.

**Phân tích chi tiết**:

1. **Flow hiện tại**:
   ```
   App Start → main.dart → NotificationService.init()
   ├─ Request permission
   ├─ Get FCM token
   ├─ Save token IF user is logged in (_auth.currentUser != null)
   └─ Listen to token refresh
   
   User Login → AuthService.login()
   ├─ Sign in with email/password
   ├─ Fetch user role
   └─ Return role (NO FCM token update)
   ```

2. **Vấn đề**:
   - Khi user đăng nhập, `_auth.currentUser` đã có giá trị
   - Nhưng FCM token đã được lấy TRƯỚC ĐÓ (khi chưa có user)
   - Token không được lưu vào Firestore vì không có userId tại thời điểm đó
   - Sau khi login, không có logic nào gọi lại `saveTokenToDatabase()`

3. **Kịch bản cụ thể**:
   ```
   Scenario A: User đăng nhập lần đầu trên thiết bị mới
   1. App start → NotificationService.init() → Get token "ABC123"
   2. currentUser = null → Token KHÔNG được lưu
   3. User login → currentUser = "user123"
   4. Token "ABC123" vẫn KHÔNG được lưu vào Firestore
   5. Backend cố gửi notification → Lỗi "no FCM token"
   
   Scenario B: User đăng nhập lại
   1. App start → NotificationService.init() → Get token "XYZ789"
   2. currentUser = null → Token KHÔNG được lưu
   3. User login → currentUser = "user456"
   4. Token "XYZ789" vẫn KHÔNG được lưu
   5. Backend cố gửi notification → Lỗi "no FCM token"
   ```

## Fix Design

### Fix Strategy

**Chiến lược**: Thêm logic cập nhật FCM token ngay sau khi user đăng nhập thành công

**Nguyên tắc**:
1. Không thay đổi logic hiện tại trong `NotificationService.init()` (preservation)
2. Thêm một điểm gọi mới để cập nhật token sau login
3. Đảm bảo token luôn được cập nhật cho user hiện tại

### Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    App Lifecycle                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  App Start                                                    │
│    ↓                                                          │
│  NotificationService.init()                                   │
│    ├─ Request permission                                     │
│    ├─ Get FCM token                                          │
│    ├─ Save token IF currentUser != null (EXISTING)          │
│    └─ Listen to token refresh (EXISTING)                    │
│                                                               │
│  User Login                                                   │
│    ↓                                                          │
│  AuthService.login()                                          │
│    ├─ Sign in with email/password                           │
│    ├─ Fetch user role                                        │
│    └─ [NEW] Call NotificationService.updateTokenAfterLogin()│
│                                                               │
│  NotificationService.updateTokenAfterLogin() [NEW METHOD]    │
│    ├─ Check if on web platform → skip                       │
│    ├─ Get current FCM token                                 │
│    └─ Save token to Firestore for current user              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Details

#### 1. New Method in NotificationService

**Method**: `updateTokenAfterLogin()`

**Purpose**: Lấy và lưu FCM token sau khi user đăng nhập thành công

**Implementation**:
```dart
/// Update FCM token after user login
/// This ensures the token is saved to Firestore for the newly logged-in user
Future<void> updateTokenAfterLogin() async {
  // Skip on web platform
  if (kIsWeb) {
    print('Skipping FCM token update on web platform');
    return;
  }

  // Check if user is logged in
  User? user = _auth.currentUser;
  if (user == null) {
    print('Cannot update FCM token: No user logged in');
    return;
  }

  try {
    // Get current FCM token
    String? token = await _fcm.getToken();
    if (token != null) {
      print('Updating FCM token after login: $token');
      await saveTokenToDatabase(token);
      print('FCM token updated successfully for user: ${user.uid}');
    } else {
      print('Cannot update FCM token: Token is null');
    }
  } catch (e) {
    print('Error updating FCM token after login: $e');
  }
}
```

**Key points**:
- Reuses existing `saveTokenToDatabase()` method
- Handles web platform check
- Handles null user check
- Handles null token check
- Includes error handling

#### 2. Update AuthService.login()

**Change**: Call `NotificationService.updateTokenAfterLogin()` after successful login

**Implementation**:
```dart
/// LOGIN
Future<String> login({
  required String email,
  required String password,
}) async {
  UserCredential credential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );

  // Fetch user role
  DocumentSnapshot userDoc = await _db
      .collection('users')
      .doc(credential.user!.uid)
      .get();
  
  String role = 'student'; // Default role
  if (userDoc.exists) {
    Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
    role = data['role'] ?? 'student';
  }
  
  // [NEW] Update FCM token after successful login
  try {
    final notificationService = NotificationService();
    await notificationService.updateTokenAfterLogin();
  } catch (e) {
    print('Error updating FCM token after login: $e');
    // Don't throw - login should succeed even if token update fails
  }
  
  return role;
}
```

**Key points**:
- Call after successful authentication
- Call after fetching user role
- Wrap in try-catch to prevent login failure if token update fails
- Don't throw error - token update is not critical for login success

### Fix Verification

#### Bug Condition Checking

**Property 1: Token Saved After Login**
```dart
// GIVEN: User logs in successfully
// WHEN: Login completes
// THEN: FCM token MUST be saved to Firestore

Future<bool> verifyTokenSavedAfterLogin(String userId) async {
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  final fcmToken = userDoc.data()?['fcmToken'] as String?;
  return fcmToken != null && fcmToken.isNotEmpty;
}
```

**Property 2: Token Matches Device Token**
```dart
// GIVEN: User logs in successfully
// WHEN: Token is saved
// THEN: Saved token MUST match current device token

Future<bool> verifyTokenMatchesDevice(String userId) async {
  final savedToken = (await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get()).data()?['fcmToken'] as String?;
  
  final deviceToken = await FirebaseMessaging.instance.getToken();
  
  return savedToken == deviceToken;
}
```

#### Preservation Checking

**Property 3: Init Flow Unchanged**
```dart
// GIVEN: App starts with logged-in user
// WHEN: NotificationService.init() is called
// THEN: Token MUST still be saved (existing behavior preserved)

Future<bool> verifyInitFlowPreserved() async {
  // This is tested by existing behavior
  // No changes to init() method
  return true;
}
```

**Property 4: Token Refresh Unchanged**
```dart
// GIVEN: FCM token is refreshed by Firebase
// WHEN: onTokenRefresh event fires
// THEN: New token MUST be saved (existing behavior preserved)

Future<bool> verifyTokenRefreshPreserved() async {
  // This is tested by existing onTokenRefresh listener
  // No changes to token refresh logic
  return true;
}
```

### Edge Cases

1. **User logs in on web platform**
   - Solution: Skip FCM token update (web doesn't support FCM)
   - Handled by: `if (kIsWeb) return;` check

2. **FCM token is null**
   - Solution: Log error and continue (don't fail login)
   - Handled by: `if (token != null)` check

3. **Firestore update fails**
   - Solution: Log error and continue (don't fail login)
   - Handled by: try-catch in `saveTokenToDatabase()`

4. **User logs out and logs in again**
   - Solution: Token is updated for new user
   - Handled by: `updateTokenAfterLogin()` uses `_auth.currentUser`

5. **Multiple rapid logins**
   - Solution: Each login updates token (last one wins)
   - Handled by: Firestore update is idempotent

## Testing Strategy

### Unit Tests

1. **Test updateTokenAfterLogin() with valid user**
   - Mock: FirebaseAuth.currentUser returns valid user
   - Mock: FirebaseMessaging.getToken() returns valid token
   - Assert: saveTokenToDatabase() is called with correct token

2. **Test updateTokenAfterLogin() with no user**
   - Mock: FirebaseAuth.currentUser returns null
   - Assert: saveTokenToDatabase() is NOT called

3. **Test updateTokenAfterLogin() with null token**
   - Mock: FirebaseMessaging.getToken() returns null
   - Assert: saveTokenToDatabase() is NOT called

4. **Test updateTokenAfterLogin() on web platform**
   - Mock: kIsWeb = true
   - Assert: Method returns early without calling getToken()

### Integration Tests

1. **Test login flow updates token**
   - Action: Call AuthService.login()
   - Assert: User document in Firestore has fcmToken field
   - Assert: fcmToken matches device token

2. **Test token persists after login**
   - Action: Login → Logout → Login again
   - Assert: Token is updated on second login

3. **Test notification can be sent after login**
   - Action: Login → Send push notification
   - Assert: Notification is delivered successfully
   - Assert: No "no FCM token" error in logs

### Manual Testing

1. **Test on fresh install**
   - Install app → Login → Check Firestore for token
   - Send test notification → Verify received

2. **Test on existing device**
   - Logout → Login → Check Firestore for updated token
   - Send test notification → Verify received

3. **Test on multiple devices**
   - Login on device A → Check token A
   - Login on device B → Check token B
   - Send notification → Verify both devices receive

## Rollout Plan

### Phase 1: Code Changes
1. Add `updateTokenAfterLogin()` method to NotificationService
2. Update `AuthService.login()` to call new method
3. Add unit tests
4. Add integration tests

### Phase 2: Testing
1. Run all tests
2. Manual testing on Android
3. Manual testing on iOS
4. Test on web (verify skip logic)

### Phase 3: Deployment
1. Deploy to staging
2. Test with real users
3. Monitor logs for errors
4. Deploy to production

### Phase 4: Monitoring
1. Monitor "no FCM token" errors (should decrease)
2. Monitor notification delivery rate (should increase)
3. Monitor login success rate (should remain 100%)

## Success Criteria

1. ✅ No "Cannot send push: user has no FCM token" errors for users who have logged in
2. ✅ FCM token is saved to Firestore after every successful login
3. ✅ Saved token matches current device token
4. ✅ Existing init() flow continues to work
5. ✅ Token refresh listener continues to work
6. ✅ Login success rate remains 100%
7. ✅ All tests pass
