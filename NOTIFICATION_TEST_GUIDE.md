# Hướng dẫn Test Firebase Cloud Messaging

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
