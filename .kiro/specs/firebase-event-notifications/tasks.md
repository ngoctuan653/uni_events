# Implementation Plan: Firebase Cloud Messaging for Event Update Notifications

## Overview

This implementation plan covers the integration of Firebase Cloud Messaging (FCM) into the UniEvents Flutter application. The work involves enhancing the existing NotificationService, setting up background message handling, configuring local notifications for foreground display, and ensuring proper initialization in main.dart. All notifications will be persisted to Firestore and users will be able to navigate to the NotificationsScreen when tapping notifications.

## Tasks

- [x] 1. Add flutter_local_notifications dependency
  - Add `flutter_local_notifications: ^17.0.0` to pubspec.yaml
  - Run `flutter pub get` to install the dependency
  - Verify `firebase_messaging: ^16.1.2` is already present
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 2. Create background message handler
  - [x] 2.1 Implement top-level background handler function
    - Create `_firebaseMessagingBackgroundHandler` as a top-level function in lib/services/notification_service.dart
    - Add `@pragma('vm:entry-point')` annotation
    - Log background message receipt with message ID
    - _Requirements: 3.4, 7.3_
  
  - [ ]* 2.2 Write property test for background message logging
    - **Property 3: Comprehensive Message Logging**
    - **Validates: Requirements 7.1, 7.3**

- [x] 3. Enhance NotificationService for foreground notifications
  - [x] 3.1 Add flutter_local_notifications integration
    - Import `flutter_local_notifications` package
    - Add `FlutterLocalNotificationsPlugin` instance variable
    - Create `_initializeLocalNotifications()` method
    - Configure Android notification channel with high importance
    - Configure iOS notification settings (alert, badge, sound permissions)
    - _Requirements: 2.1, 2.4, 2.5, 6.1, 6.4_
  
  - [x] 3.2 Implement foreground message handler
    - Create `_setupForegroundMessageHandler()` method
    - Listen to `FirebaseMessaging.onMessage` stream
    - Extract title and body from RemoteMessage
    - Call `_showLocalNotification()` to display notification
    - Log notification receipt with message ID and title
    - _Requirements: 2.1, 2.2, 2.3, 7.1, 7.2_
  
  - [x] 3.3 Implement local notification display
    - Create `_showLocalNotification(RemoteMessage message)` method
    - Extract notification data from RemoteMessage
    - Create AndroidNotificationDetails with channel configuration
    - Create DarwinNotificationDetails for iOS
    - Show notification with unique ID using platform-specific styling
    - _Requirements: 2.1, 2.4_
  
  - [ ]* 3.4 Write property test for foreground message display
    - **Property 1: Foreground Message Display**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
  
  - [ ]* 3.5 Write unit tests for message extraction
    - Test extracting title and body from valid RemoteMessage
    - Test handling RemoteMessage with null notification
    - Test handling RemoteMessage with missing title or body
    - _Requirements: 2.2, 2.3_

- [x] 4. Implement notification tap handling
  - [x] 4.1 Set up notification tap handlers
    - Create `_setupNotificationTapHandler()` method
    - Register callback for local notification taps
    - Set up `FirebaseMessaging.onMessageOpenedApp` listener for background/terminated taps
    - Handle `getInitialMessage()` for app launch from terminated state
    - Navigate to NotificationsScreen on tap
    - _Requirements: 3.3, 8.1_
  
  - [x] 4.2 Implement Firestore persistence for FCM notifications
    - Create `createNotificationRecord(RemoteMessage message)` method
    - Extract eventId, eventName, and type from message.data
    - Create document in `user_notifications` collection
    - Set fields: userId, eventId, eventTitle, type, message, isRead (false), createdAt
    - Call this method from notification tap handlers
    - _Requirements: 8.2, 8.3, 8.4_
  
  - [ ]* 4.3 Write property test for notification tap navigation
    - **Property 4: Notification Tap Navigation**
    - **Validates: Requirements 8.1**
  
  - [ ]* 4.4 Write property test for FCM to Firestore persistence
    - **Property 5: FCM to Firestore Persistence**
    - **Validates: Requirements 8.2, 8.3, 8.4**
  
  - [ ]* 4.5 Write unit tests for Firestore persistence
    - Test document creation with all required fields
    - Test handling of missing user authentication
    - Test error logging when Firestore write fails
    - _Requirements: 8.2, 8.3_

- [x] 5. Implement topic subscription
  - [x] 5.1 Add topic subscription to init method
    - Call `FirebaseMessaging.instance.subscribeToTopic('all_events')` in init()
    - Log subscription success or failure
    - Handle subscription errors gracefully without blocking app initialization
    - _Requirements: 1.1, 1.2_
  
  - [ ]* 5.2 Write unit tests for topic subscription
    - Test successful subscription logs correctly
    - Test subscription failure logs error and continues
    - _Requirements: 1.1, 1.2_

- [x] 6. Update NotificationService.init() method
  - [x] 6.1 Orchestrate all initialization steps
    - Call `_initializeLocalNotifications()` first
    - Request notification permissions
    - Log permission grant or denial
    - Call `_setupForegroundMessageHandler()`
    - Call `_setupNotificationTapHandler()`
    - Subscribe to "all_events" topic
    - Ensure initialization completes before returning
    - _Requirements: 1.3, 6.1, 6.2, 6.3_
  
  - [ ]* 6.2 Write unit tests for initialization sequence
    - Test init() calls all setup methods in correct order
    - Test permission denial scenario continues without exception
    - Test error handling for initialization failures
    - _Requirements: 1.3, 6.1, 6.2_

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Update main.dart for FCM initialization
  - [x] 8.1 Register background message handler
    - Add `WidgetsFlutterBinding.ensureInitialized()` at start of main()
    - Ensure `Firebase.initializeApp()` is called
    - Register `FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler)` before runApp()
    - Verify initialization sequence is correct
    - _Requirements: 3.4, 5.4_
  
  - [ ]* 8.2 Write integration test for initialization sequence
    - Test background handler is registered before app starts
    - Test Firebase is initialized before FCM setup
    - _Requirements: 3.4, 5.4_

- [x] 9. Add error handling and logging
  - [x] 9.1 Wrap message processing in try-catch blocks
    - Add error handling to foreground message handler
    - Add error handling to notification tap handlers
    - Add error handling to Firestore persistence
    - Log all errors with message ID and exception details
    - _Requirements: 7.4_
  
  - [ ]* 9.2 Write unit tests for error scenarios
    - Test error logging when message processing fails
    - Test error logging when local notification display fails
    - Test error logging when Firestore write fails
    - _Requirements: 7.4_

- [ ]* 10. Write property test for event notification format validation
  - **Property 2: Event Notification Format Validation**
  - Test all four event types: cancelled, updated, deleted, reactivated
  - Verify title and body format match requirements for each type
  - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5**

- [x] 11. Final checkpoint - Verify end-to-end functionality
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The existing NotificationService class will be enhanced, not replaced
- Background and terminated state notifications are handled automatically by FCM
- All property tests should run a minimum of 100 iterations
- Property tests should be tagged with comments referencing the design property
- Integration testing will require actual Firebase project configuration
- Manual testing should cover all three app states: foreground, background, terminated
