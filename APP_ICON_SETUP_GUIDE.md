# 📱 Hướng Dẫn Thay Đổi Icon và Tên App

## ✅ Đã Hoàn Thành

### 1. Tên App đã được đổi thành "UniEvents"
- ✅ Android: `android/app/src/main/AndroidManifest.xml`
- ✅ iOS: `ios/Runner/Info.plist`

---

## 🎨 Cách Thay Đổi Icon App

### Phương Án 1: Sử dụng flutter_launcher_icons (Khuyên dùng - Tự động)

#### Bước 1: Chuẩn bị icon
1. Tạo một icon PNG với kích thước **1024x1024px** (hoặc ít nhất 512x512px)
2. Icon nên có:
   - Nền trong suốt (transparent) hoặc màu trắng
   - Thiết kế đơn giản, dễ nhìn ở kích thước nhỏ
   - Không có text quá nhỏ

#### Bước 2: Đặt icon vào project
```
📁 Tạo thư mục: assets/icon/
📄 Đặt file icon: assets/icon/app_icon.png
```

#### Bước 3: Chạy lệnh tạo icon
```bash
# Cài đặt dependencies
flutter pub get

# Tạo icon cho tất cả platforms
flutter pub run flutter_launcher_icons
```

#### Bước 4: Build lại app
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

---

### Phương Án 2: Thay thế thủ công (Nâng cao)

Nếu bạn muốn control hoàn toàn, thay thế icon thủ công:

#### Android Icons
Cần tạo icon với các kích thước sau:

| Thư mục | Kích thước | File |
|---------|-----------|------|
| `mipmap-mdpi/` | 48x48px | `ic_launcher.png` |
| `mipmap-hdpi/` | 72x72px | `ic_launcher.png` |
| `mipmap-xhdpi/` | 96x96px | `ic_launcher.png` |
| `mipmap-xxhdpi/` | 144x144px | `ic_launcher.png` |
| `mipmap-xxxhdpi/` | 192x192px | `ic_launcher.png` |

**Đường dẫn:** `android/app/src/main/res/mipmap-[density]/ic_launcher.png`

#### iOS Icons
Thay thế icon trong: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Cần các kích thước:
- 20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024
- Mỗi kích thước cần 2-3 variants (@1x, @2x, @3x)

---

## 🛠️ Tools Hỗ Trợ Tạo Icon

### Online Tools (Miễn phí)
1. **AppIcon.co** - https://www.appicon.co/
   - Upload 1 icon, tự động tạo tất cả kích thước
   - Hỗ trợ cả Android và iOS

2. **Icon Kitchen** - https://icon.kitchen/
   - Tạo adaptive icons cho Android
   - Preview trên nhiều devices

3. **MakeAppIcon** - https://makeappicon.com/
   - Tạo icon cho cả Android và iOS
   - Export dưới dạng zip

### Design Tools
- **Figma** - Thiết kế icon chuyên nghiệp
- **Canva** - Tạo icon đơn giản, nhanh chóng
- **Adobe Illustrator** - Cho designer chuyên nghiệp

---

## 📋 Checklist

### Tên App
- [x] Đổi tên trong `AndroidManifest.xml` → "UniEvents"
- [x] Đổi tên trong `Info.plist` → "UniEvents"

### Icon App
- [ ] Chuẩn bị icon 1024x1024px
- [ ] Đặt icon vào `assets/icon/app_icon.png`
- [ ] Chạy `flutter pub get`
- [ ] Chạy `flutter pub run flutter_launcher_icons`
- [ ] Build lại app
- [ ] Test trên thiết bị thật

---

## 🎯 Lưu Ý Quan Trọng

### Android
- Icon nên có nền trong suốt hoặc màu trắng
- Android 8.0+ hỗ trợ **Adaptive Icons** (icon có thể thay đổi hình dạng)
- Nếu dùng adaptive icon, cần chuẩn bị:
  - **Foreground**: Phần icon chính (nên nhỏ hơn 1024x1024 một chút)
  - **Background**: Màu nền hoặc pattern

### iOS
- Icon KHÔNG được có alpha channel (nền trong suốt)
- iOS tự động bo tròn góc icon
- Cần icon 1024x1024px cho App Store

### Testing
Sau khi đổi icon, nhớ:
1. **Uninstall app cũ** trên thiết bị
2. **Build lại** từ đầu
3. **Install app mới** để thấy icon mới
4. Kiểm tra trên nhiều devices khác nhau

---

## 🚀 Quick Start

```bash
# 1. Tạo thư mục assets
mkdir -p assets/icon

# 2. Đặt icon vào assets/icon/app_icon.png
# (Bạn cần tự copy file icon vào đây)

# 3. Cài đặt dependencies
flutter pub get

# 4. Tạo icon
flutter pub run flutter_launcher_icons

# 5. Build app
flutter build apk  # Android
# hoặc
flutter build ios  # iOS

# 6. Chạy app
flutter run
```

---

## ❓ Troubleshooting

### Icon không đổi sau khi build?
- Uninstall app cũ hoàn toàn
- Clean build: `flutter clean`
- Build lại: `flutter build apk`

### Icon bị vỡ/mờ?
- Đảm bảo icon gốc có độ phân giải cao (ít nhất 512x512px)
- Sử dụng PNG với chất lượng cao
- Không scale up từ icon nhỏ

### Adaptive icon không hoạt động?
- Kiểm tra `adaptive_icon_foreground` và `adaptive_icon_background` trong `pubspec.yaml`
- Foreground nên nhỏ hơn 1024x1024 để tránh bị cắt

---

## 📚 Tài Liệu Tham Khảo

- [Flutter Launcher Icons Package](https://pub.dev/packages/flutter_launcher_icons)
- [Android Icon Guidelines](https://developer.android.com/guide/practices/ui_guidelines/icon_design_launcher)
- [iOS Icon Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Material Design Icons](https://material.io/design/iconography/product-icons.html)

---

## 💡 Tips

1. **Giữ icon đơn giản**: Icon phức tạp khó nhìn ở kích thước nhỏ
2. **Test trên nhiều nền**: Icon nên rõ ràng trên cả nền sáng và tối
3. **Tránh text nhỏ**: Text trong icon thường khó đọc
4. **Sử dụng màu tương phản**: Giúp icon nổi bật hơn
5. **Consistent branding**: Icon nên phù hợp với brand của app

---

**Tạo bởi:** Kiro AI Assistant  
**Ngày:** 2024  
**Project:** UniEvents - University Event Management App
