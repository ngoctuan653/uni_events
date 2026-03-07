# Hướng Dẫn Test Notification Không Cần Cloud Functions

## Cách Hoạt Động

Thay vì dùng Cloud Functions (cần Blaze plan), app sẽ:
1. Lắng nghe Firestore collection `notifications`
2. Khi có document mới được tạo → tự động hiển thị local notification
3. Mỗi user app đang mở sẽ nhận và hiển thị notification

## Ưu Điểm
✅ Hoàn toàn miễn phí (Spark plan)
✅ Không cần Cloud Functions
✅ Không cần Blaze plan
✅ Vẫn hoạt động tốt cho app nhỏ/vừa

## Nhược Điểm
⚠️ Chỉ hoạt động khi app đang mở (foreground/background)
⚠️ Không gửi được khi app bị tắt hoàn toàn (terminated)
⚠️ Mỗi device tự hiển thị notification (không qua FCM server)

## Cách Test

### 1. Chạy App
```bash
flutter run
```

### 2. Test Khi Club Sửa Event

**Bước 1**: Đăng nhập bằng tài khoản club
**Bước 2**: Vào màn hình quản lý events
**Bước 3**: Sửa một event (thay đổi status hoặc thời gian)
**Bước 4**: Lưu thay đổi

**Kết quả mong đợi**:
- ✅ Notification hiện trên màn hình điện thoại
- ✅ Có âm thanh và rung
- ✅ Notification xuất hiện trong NotificationsScreen

### 3. Test Với Nhiều Devices

**Device 1** (Club):
- Đăng nhập bằng tài khoản club
- Sửa event

**Device 2** (User):
- Đăng nhập bằng tài khoản user
- Mở app (foreground hoặc background)
- Sẽ nhận notification ngay lập tức

### 4. Kiểm Tra Log

Trong terminal, bạn sẽ thấy:
```
I/flutter: Showing notification from Firestore - Title: Event Updated, Body: ...
I/flutter: Notification shown successfully from Firestore
```

## Các Loại Notification

1. **Event Cancelled**: Khi club đổi status → inactive
2. **Event Reactivated**: Khi club đổi status từ inactive → active
3. **Event Updated**: Khi club thay đổi thời gian event
4. **Event Deleted**: Khi club xóa event

## Lưu Ý Quan Trọng

### Khi App Bị Tắt (Terminated)
- ❌ Notification KHÔNG hiển thị (vì app không chạy)
- ✅ Khi mở app lại, notification vẫn có trong NotificationsScreen

### Để Nhận Notification Khi App Tắt
Cần upgrade lên Blaze plan và deploy Cloud Functions. Nhưng với demo/project nhỏ, cách này đã đủ dùng.

## Troubleshooting

### Không Thấy Notification
1. Kiểm tra app có đang chạy không (foreground/background)
2. Kiểm tra quyền notification: Settings → Apps → uni_events → Notifications → ON
3. Xem log trong terminal có dòng "Showing notification from Firestore" không

### Notification Bị Trùng
- Mỗi device sẽ tự hiển thị notification
- Đây là hành vi bình thường với giải pháp này

### Muốn Gửi Khi App Tắt
- Cần upgrade lên Blaze plan (miễn phí cho usage thấp)
- Deploy Cloud Functions
- Link: https://console.firebase.google.com/project/uni-events-72162/usage/details

## So Sánh Với Cloud Functions

| Tính năng | Firestore Listener (Free) | Cloud Functions (Blaze) |
|-----------|---------------------------|-------------------------|
| Chi phí | Miễn phí | Miễn phí cho 2M calls/tháng |
| App foreground | ✅ | ✅ |
| App background | ✅ | ✅ |
| App terminated | ❌ | ✅ |
| Setup | Đơn giản | Cần deploy |
| Phù hợp | Demo, app nhỏ | Production app |

## Kết Luận

Giải pháp này phù hợp cho:
- ✅ Demo project
- ✅ App nhỏ với ít users
- ✅ Không muốn trả phí
- ✅ Users thường xuyên mở app

Nếu cần notification khi app tắt hoàn toàn, hãy upgrade lên Blaze plan (vẫn miễn phí cho usage thấp).
