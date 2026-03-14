# Bugfix Requirements Document

## Introduction

Khi user đăng nhập trên thiết bị mới hoặc đăng nhập lại, FCM token không được cập nhật vào Firestore, dẫn đến lỗi "Cannot send push: user has no FCM token" khi hệ thống cố gắng gửi push notification. Bug này ngăn cản user nhận được thông báo về các sự kiện quan trọng.

Hiện tại, FCM token chỉ được lấy và lưu khi app khởi động (trong `main.dart` → `NotificationService.init()`), nhưng không có logic nào để cập nhật token khi user đăng nhập. Điều này tạo ra khoảng trống trong việc quản lý token, đặc biệt khi user đăng nhập trên thiết bị mới.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN user đăng nhập thành công trên thiết bị mới THEN hệ thống không lấy và lưu FCM token của thiết bị đó vào Firestore

1.2 WHEN user đăng nhập lại trên thiết bị đã sử dụng THEN hệ thống không cập nhật FCM token mới nhất vào Firestore

1.3 WHEN hệ thống cố gắng gửi push notification đến user không có FCM token THEN hệ thống log lỗi "Cannot send push: user has no FCM token" và không gửi được notification

### Expected Behavior (Correct)

2.1 WHEN user đăng nhập thành công trên thiết bị mới THEN hệ thống SHALL lấy FCM token của thiết bị hiện tại và lưu vào field `fcmToken` trong document `users/{userId}`

2.2 WHEN user đăng nhập lại trên thiết bị đã sử dụng THEN hệ thống SHALL cập nhật FCM token mới nhất vào field `fcmToken` trong document `users/{userId}`

2.3 WHEN hệ thống gửi push notification đến user có FCM token hợp lệ THEN hệ thống SHALL gửi notification thành công đến thiết bị của user

### Unchanged Behavior (Regression Prevention)

3.1 WHEN app khởi động và user đã đăng nhập THEN hệ thống SHALL CONTINUE TO lấy và lưu FCM token như hiện tại trong `NotificationService.init()`

3.2 WHEN FCM token được refresh tự động bởi Firebase THEN hệ thống SHALL CONTINUE TO lắng nghe và cập nhật token mới thông qua `onTokenRefresh` listener

3.3 WHEN user chưa đăng nhập THEN hệ thống SHALL CONTINUE TO không lưu FCM token vào Firestore (vì chưa có userId)

3.4 WHEN user đăng ký tài khoản mới THEN hệ thống SHALL CONTINUE TO hoạt động bình thường với flow hiện tại
