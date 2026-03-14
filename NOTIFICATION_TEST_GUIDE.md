# Hướng dẫn Test Firebase Cloud Messaging

## FCM Token Update on Login

### Cách hoạt động

Kể từ phiên bản mới, FCM token được tự động cập nhật vào Firestore trong 2 trường hợp:

1. **Khi app khởi động** (flow hiện tại):
   - `NotificationService.init()` được gọi trong `main.dart`
   - Nếu user đã đăng nhập, token được lưu vào Firestore

2. **Khi user đăng nhập** (flow mới):
   - Sau khi đăng nhập thành công, `AuthService.login()` tự động gọi `NotificationService.updateTokenAfterLogin()`
   - Token được lấy và lưu vào field `fcmToken` trong document `users/{userId}`
   - Đảm bảo user luôn có token hợp lệ ngay sau khi đăng nhập

### Khi nào token được cập nhật?

- ✅ User đăng nhập lần đầu trên thiết bị mới
- ✅ User đăng nhập lại trên thiết bị đã sử dụng
- ✅ App khởi động với user đã đăng nhập
- ✅ FCM token được refresh tự động bởi Firebase
- ❌ User chưa đăng nhập (không có userId để lưu token)
- ❌ Web platform (FCM không được hỗ trợ trên web)

### Console logs mong đợi khi đăng nhập

```
User granted permission
FCM Token: [YOUR_TOKEN_HERE]
Successfully subscribed to topic: all_events
Updating FCM token after login: [YOUR_TOKEN_HERE]
FCM token updated successfully for user: [USER_ID]
```

## Bước 1: Kiểm tra FCM Token

Khi chạy app, check console log để lấy FCM Token:
```
User granted permission
FCM Token: [YOUR_TOKEN_HERE]
Successfully subscribed to topic: all_events
```

## Bước 2: Test từ Firebase Console

1. Vào Firebase Console: https://console.firebase.google.com
2. Chọn project của bạn
3. Vào **Messaging** (Cloud Messaging)
4. Click **Send your first message** hoặc **New campaign**
5. Chọn **Firebase Notification messages**

### Cấu hình Notification:

**Notification title:**
```
📢 Event Updated
```

**Notification text:**
```
AI Workshop has been cancelled
```

**Target:**
- Chọn **Topic**
- Nhập: `all_events`

**Additional options > Custom data:**
- Key: `eventId`, Value: `event_123`
- Key: `eventName`, Value: `AI Workshop`
- Key: `type`, Value: `event_cancelled`

## Bước 3: Test bằng cURL (Backend)

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "/topics/all_events",
    "notification": {
      "title": "📢 Event Updated",
      "body": "AI Workshop has been cancelled"
    },
    "data": {
      "eventId": "event_123",
      "eventName": "AI Workshop",
      "type": "event_cancelled"
    }
  }'
```

**Lấy Server Key:**
1. Firebase Console > Project Settings
2. Cloud Messaging tab
3. Copy **Server key**

## Bước 4: Test các trường hợp

### Test 1: App đang mở (Foreground)
1. Mở app
2. Gửi notification từ Firebase Console
3. **Kết quả mong đợi:**
   - Thấy notification hiển thị trên màn hình
   - Console log: "Received foreground message: [message_id]"
   - Notification được lưu vào Firestore

### Test 2: App ở background
1. Mở app rồi nhấn Home button (app vẫn chạy background)
2. Gửi notification
3. **Kết quả mong đợi:**
   - Thấy system notification trên notification tray
   - Tap vào notification → app mở và navigate đến NotificationsScreen

### Test 3: App đã tắt (Terminated)
1. Force close app (swipe away từ recent apps)
2. Gửi notification
3. **Kết quả mong đợi:**
   - Thấy system notification trên notification tray
   - Tap vào notification → app mở và navigate đến NotificationsScreen

### Test 4: FCM Token Update on Login (NEW)
1. **Test fresh install:**
   - Cài app mới hoặc clear app data
   - Mở app (chưa login)
   - Login với tài khoản
   - **Kết quả mong đợi:**
     - Console log: "Updating FCM token after login: [token]"
     - Console log: "FCM token updated successfully for user: [userId]"
     - Firestore `users/{userId}` có field `fcmToken`
     - Gửi test notification → nhận được thành công

2. **Test re-login:**
   - Logout khỏi app
   - Login lại
   - **Kết quả mong đợi:**
     - Console log: "Updating FCM token after login: [token]"
     - Token trong Firestore được cập nhật
     - Gửi test notification → nhận được thành công

3. **Test multiple devices:**
   - Login cùng tài khoản trên device A
   - Login cùng tài khoản trên device B
   - **Kết quả mong đợi:**
     - Mỗi device có token riêng trong Firestore
     - Token của device B ghi đè token của device A (expected behavior)
     - Chỉ device B nhận notification (device cuối cùng login)

4. **Test login failure doesn't break app:**
   - Simulate token update failure (tắt internet sau khi login)
   - **Kết quả mong đợi:**
     - Console log: "Error updating FCM token after login: [error]"
     - Login vẫn thành công
     - App vẫn hoạt động bình thường
     - Token sẽ được cập nhật khi app restart với internet

### Test 5: Check-in Success Notification (NEW)
1. **Test QR code check-in:**
   - Student đăng ký event
   - Staff scan QR code của student
   - **Kết quả mong đợi:**
     - Check-in thành công
     - Student nhận notification: "✅ Check-in Successful"
     - Body: "You have successfully checked in to [Event Name]"
     - Notification xuất hiện ngay lập tức
     - In-app notification được lưu vào `user_notifications`

2. **Test manual check-in:**
   - Student đăng ký event nhưng không có QR
   - Staff thực hiện manual check-in
   - **Kết quả mong đợi:**
     - Check-in thành công
     - Student nhận notification tương tự QR check-in
     - Notification type: `checkin_success`

3. **Test check-in notification failure doesn't break check-in:**
   - Simulate notification failure (user không có FCM token)
   - **Kết quả mong đợi:**
     - Console log: "Error sending check-in notification: [error]"
     - Check-in vẫn thành công (không throw error)
     - Check-in record được lưu vào Firestore
     - Staff vẫn thấy confirmation

## Bước 5: Debug nếu không nhận được notification

### Implementation Details (for developers)

**How FCM token update works:**

```dart
// In AuthService.login() - lib/services/auth_services.dart
Future<String> login({
  required String email,
  required String password,
}) async {
  // 1. Authenticate user
  UserCredential credential = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );

  // 2. Fetch user role
  DocumentSnapshot userDoc = await _db
      .collection('users')
      .doc(credential.user!.uid)
      .get();
  
  String role = 'student';
  if (userDoc.exists) {
    Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
    role = data['role'] ?? 'student';
  }
  
  // 3. Update FCM token after successful login (NEW)
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

**The updateTokenAfterLogin() method:**

```dart
// In NotificationService - lib/services/notification_services.dart
Future<void> updateTokenAfterLogin() async {
  // Skip on web platform (FCM not supported)
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
    // Get current FCM token from device
    String? token = await _fcm.getToken();
    if (token != null) {
      print('Updating FCM token after login: $token');
      // Save to Firestore users/{userId}.fcmToken
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

**Key points:**
- Token update happens AFTER successful authentication
- Token update happens AFTER user role is fetched
- If token update fails, login still succeeds (non-blocking)
- Token is saved to Firestore field `users/{userId}.fcmToken`
- Web platform is skipped (FCM not supported on web)

## Bước 5: Debug nếu không nhận được notification

### Check 1: Permission
```dart
// Trong console log phải thấy:
User granted permission
```

Nếu thấy "User declined", vào Settings > Apps > uni_events > Notifications > Bật ON

### Check 2: Topic subscription
```dart
// Trong console log phải thấy:
Successfully subscribed to topic: all_events
```

### Check 3: FCM Token
```dart
// Phải có token:
FCM Token: [long_string]
```

### Check 4: Background handler
```dart
// Khi app tắt và nhận notification, console log phải thấy:
Handling a background message: [message_id]
```

### Check 5: Notification format từ backend
Backend PHẢI gửi có phần `notification`:
```json
{
  "notification": {  // ← BẮT BUỘC
    "title": "...",
    "body": "..."
  },
  "data": { ... }
}
```

Nếu chỉ gửi `data` thì app tắt sẽ KHÔNG hiển thị notification!

## Các loại notification format

### Check-in Success (NEW)
```json
{
  "notification": {
    "title": "✅ Check-in Successful",
    "body": "You have successfully checked in to \"AI Workshop\""
  },
  "data": {
    "eventId": "event_123",
    "eventName": "AI Workshop",
    "type": "checkin_success",
    "checkedInAt": "2024-03-14T10:30:00.000Z"
  }
}
```

### Event Cancelled
```json
{
  "notification": {
    "title": "📢 Event Cancelled",
    "body": "AI Workshop has been cancelled"
  },
  "data": {
    "eventId": "event_123",
    "eventName": "AI Workshop",
    "type": "event_cancelled"
  }
}
```

### Event Updated
```json
{
  "notification": {
    "title": "📢 Event Updated",
    "body": "AI Workshop has been modified"
  },
  "data": {
    "eventId": "event_123",
    "eventName": "AI Workshop",
    "type": "event_updated"
  }
}
```

### Event Deleted
```json
{
  "notification": {
    "title": "📢 Event Deleted",
    "body": "AI Workshop has been removed"
  },
  "data": {
    "eventId": "event_123",
    "eventName": "AI Workshop",
    "type": "event_deleted"
  }
}
```

### Event Reactivated
```json
{
  "notification": {
    "title": "📢 Event Reactivated",
    "body": "AI Workshop is now active again"
  },
  "data": {
    "eventId": "event_123",
    "eventName": "AI Workshop",
    "type": "event_reactivated"
  }
}
```

## Troubleshooting

### Lỗi: "User declined permission"
**Giải pháp:** Vào Settings > Apps > uni_events > Notifications > Bật ON, sau đó restart app

### Lỗi: "Failed to subscribe to topic"
**Giải pháp:** Kiểm tra internet connection, restart app

### App tắt không nhận notification
**Nguyên nhân:** Backend gửi thiếu phần `notification`
**Giải pháp:** Đảm bảo backend gửi đúng format có cả `notification` và `data`

### Notification không lưu vào Firestore
**Nguyên nhân:** User chưa login
**Giải pháp:** Login vào app trước khi test

### iOS không nhận notification
**Giải pháp:** 
1. Kiểm tra APNs certificate trong Firebase Console
2. Test trên real device (không test trên simulator)
3. Đảm bảo đã enable Push Notifications trong Xcode

### Lỗi: "Cannot send push: user has no FCM token"

**Nguyên nhân có thể:**
1. User chưa đăng nhập lần nào sau khi cài app
2. User đã xóa permission notification
3. Token chưa được cập nhật vào Firestore

**Giải pháp:**
1. Đảm bảo user đã đăng nhập ít nhất 1 lần
2. Check console log xem có thấy "FCM token updated successfully" không
3. Kiểm tra Firestore collection `users/{userId}` có field `fcmToken` không
4. Nếu không có token, thử logout và login lại
5. Kiểm tra permission notification đã được cấp chưa

**Cách verify token trong Firestore:**
1. Vào Firebase Console > Firestore Database
2. Mở collection `users`
3. Tìm document với userId của user
4. Kiểm tra field `fcmToken` có giá trị không
5. Token phải là string dài (khoảng 150+ ký tự)

**Expected behavior sau khi login:**
- Console log hiển thị: "Updating FCM token after login: [token]"
- Console log hiển thị: "FCM token updated successfully for user: [userId]"
- Firestore document `users/{userId}` có field `fcmToken` với giá trị hợp lệ
- Backend có thể gửi notification thành công đến user

### Token không được cập nhật sau khi login

**Kiểm tra:**
1. Check console log có thấy "Updating FCM token after login" không
2. Nếu thấy "Cannot update FCM token: Token is null", có thể:
   - Permission notification chưa được cấp
   - Firebase Messaging chưa khởi tạo đúng
   - Thiết bị không hỗ trợ FCM (ví dụ: emulator không có Google Play Services)

**Giải pháp:**
1. Cấp permission notification cho app
2. Restart app để khởi tạo lại Firebase Messaging
3. Test trên real device thay vì emulator
4. Kiểm tra internet connection

### Web platform không nhận notification

**Expected behavior:**
- Web platform KHÔNG hỗ trợ FCM trong app này
- Console log sẽ hiển thị: "Skipping FCM initialization on web platform"
- Console log sẽ hiển thị: "Skipping FCM token update on web platform"
- Đây là behavior đúng, không phải lỗi

**Lý do:**
- FCM trên web yêu cầu service worker và HTTPS
- App hiện tại chưa implement FCM cho web
- Chỉ mobile platforms (Android/iOS) được hỗ trợ
