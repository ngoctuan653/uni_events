# Requirements Document

## Introduction

This document specifies the requirements for integrating Firebase Cloud Messaging (FCM) into the UniEvents Flutter application to notify users when club administrators modify events. The system will deliver push notifications in three states: foreground (app active), background (app minimized), and terminated (app closed). Users will receive real-time updates about event changes including cancellations, updates, deletions, and reactivations.

## Glossary

- **FCM**: Firebase Cloud Messaging service that delivers push notifications
- **Notification_Manager**: The component responsible for handling FCM message reception and display
- **Topic_Subscriber**: The component that subscribes the app to FCM topics
- **Local_Notification_Service**: The service that displays notifications when the app is in foreground
- **Event_Update**: Any modification to an event including cancellation, deletion, reactivation, or content changes
- **Foreground_State**: The app is active and visible to the user
- **Background_State**: The app is running but not visible (minimized)
- **Terminated_State**: The app is completely closed and not running
- **Remote_Message**: A notification payload received from FCM containing title, body, and data

## Requirements

### Requirement 1: Subscribe to Event Notifications Topic

**User Story:** As a user, I want to automatically receive notifications about all event updates, so that I stay informed about changes to events I might be interested in.

#### Acceptance Criteria

1. WHEN the application starts, THE Topic_Subscriber SHALL subscribe to the "all_events" topic
2. IF subscription fails, THEN THE Topic_Subscriber SHALL log the error and retry on next app launch
3. THE Topic_Subscriber SHALL complete subscription before the main UI is displayed

### Requirement 2: Handle Foreground Notifications

**User Story:** As a user, I want to see notifications when the app is open, so that I'm immediately aware of event changes while using the app.

#### Acceptance Criteria

1. WHEN a Remote_Message is received, WHILE the app is in Foreground_State, THE Notification_Manager SHALL display the notification using Local_Notification_Service
2. THE Notification_Manager SHALL extract the title from Remote_Message.notification.title
3. THE Notification_Manager SHALL extract the body from Remote_Message.notification.body
4. WHEN displaying a foreground notification, THE Local_Notification_Service SHALL show a visual alert with the notification title and body
5. THE Local_Notification_Service SHALL use platform-appropriate notification styling (Material Design for Android, Cupertino for iOS)

### Requirement 3: Handle Background and Terminated State Notifications

**User Story:** As a user, I want to receive notifications even when the app is closed, so that I don't miss important event updates.

#### Acceptance Criteria

1. WHEN a Remote_Message is received, WHILE the app is in Background_State, THE FCM SHALL display a system notification automatically
2. WHEN a Remote_Message is received, WHILE the app is in Terminated_State, THE FCM SHALL display a system notification automatically
3. WHEN a user taps a system notification, THE Notification_Manager SHALL open the app
4. THE Notification_Manager SHALL register a background message handler before the app initializes

### Requirement 4: Display Event Update Notification Content

**User Story:** As a user, I want notifications to clearly describe what changed, so that I can quickly understand the event update without opening the app.

#### Acceptance Criteria

1. WHEN an event is cancelled, THE Remote_Message SHALL contain title "📢 Event Cancelled" and body "{event_name} has been cancelled"
2. WHEN an event is updated, THE Remote_Message SHALL contain title "📢 Event Updated" and body "{event_name} has been modified"
3. WHEN an event is deleted, THE Remote_Message SHALL contain title "📢 Event Deleted" and body "{event_name} has been removed"
4. WHEN an event is reactivated, THE Remote_Message SHALL contain title "📢 Event Reactivated" and body "{event_name} is now active again"
5. THE Remote_Message body SHALL include the event name to identify which event changed

### Requirement 5: Integrate Required Dependencies

**User Story:** As a developer, I want the necessary FCM packages installed, so that the notification system can function properly.

#### Acceptance Criteria

1. THE application SHALL include firebase_messaging package version 14.7.0 or higher
2. THE application SHALL include flutter_local_notifications package version 17.0.0 or higher
3. WHEN building the application, THE build system SHALL successfully resolve all FCM dependencies
4. THE application SHALL initialize Firebase Core before using FCM services

### Requirement 6: Handle Notification Permissions

**User Story:** As a user, I want to be asked for notification permission, so that I can control whether I receive push notifications.

#### Acceptance Criteria

1. WHEN the app first launches, THE Notification_Manager SHALL request notification permission from the operating system
2. IF permission is denied, THEN THE Notification_Manager SHALL log the denial and continue app operation without notifications
3. IF permission is granted, THEN THE Notification_Manager SHALL enable notification reception
4. THE Notification_Manager SHALL handle permission requests according to platform guidelines (iOS requires explicit request, Android 13+ requires runtime permission)

### Requirement 7: Log Notification Events

**User Story:** As a developer, I want notification events logged, so that I can debug issues and monitor notification delivery.

#### Acceptance Criteria

1. WHEN a Remote_Message is received in any state, THE Notification_Manager SHALL log the message ID
2. WHEN a Remote_Message is received in Foreground_State, THE Notification_Manager SHALL log the notification title
3. WHEN a background message is processed, THE background handler SHALL log "Handling a background message: {message_id}"
4. IF an error occurs during notification processing, THEN THE Notification_Manager SHALL log the error details

### Requirement 8: Maintain Notification State Consistency

**User Story:** As a user, I want notifications to be marked as read in the app, so that I can track which updates I've already seen.

#### Acceptance Criteria

1. WHEN a user taps a notification, THE Notification_Manager SHALL navigate to the notifications screen
2. THE Notification_Manager SHALL pass the notification data to the existing NotificationService
3. THE existing NotificationService SHALL create a corresponding in-app notification record in Firestore
4. FOR ALL notifications received via FCM, a corresponding record SHALL exist in the user's notification collection
