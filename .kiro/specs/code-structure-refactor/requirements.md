# Requirements Document

## Introduction

This document specifies requirements for refactoring the university event management app codebase to follow Flutter and Firebase best practices. The refactor addresses inconsistent naming conventions, missing model abstractions, and tight coupling between services and data structures. The goal is to establish a clean, maintainable architecture that supports current features and prepares for future enhancements like QR-based check-in and attendance tracking.

## Glossary

- **System**: The university event management Flutter application
- **Firestore**: Cloud Firestore database service
- **Registration**: A record indicating a student has signed up for an event
- **CheckIn**: A record indicating a student has physically attended an event (future feature)
- **Model**: A Dart class representing a data entity with serialization methods
- **Service**: A Dart class providing business logic and data access operations
- **Collection**: A Firestore collection storing documents of a specific type
- **Migration**: The process of transitioning from old structure to new structure
- **Backward_Compatibility**: Ability to read existing data during transition period

## Requirements

### Requirement 1: Rename eventRegistrations Collection

**User Story:** As a developer, I want consistent collection naming, so that the codebase follows Firebase naming conventions.

#### Acceptance Criteria

1. THE System SHALL rename the `eventRegistrations` collection to `registrations`
2. WHEN accessing registration data, THE System SHALL use the `registrations` collection name
3. DURING migration, THE System SHALL maintain backward compatibility by reading from both `eventRegistrations` and `registrations` collections
4. THE System SHALL provide a migration utility that copies data from `eventRegistrations` to `registrations`

### Requirement 2: Create RegistrationModel

**User Story:** As a developer, I want a proper RegistrationModel class, so that registration data has type safety and consistent serialization.

#### Acceptance Criteria

1. THE System SHALL create a RegistrationModel class with fields: id, eventId, userId, status, registeredAt
2. THE RegistrationModel SHALL implement a fromFirestore factory method that deserializes Firestore documents
3. THE RegistrationModel SHALL implement a toMap method that serializes to Firestore-compatible format
4. WHEN deserializing timestamps, THE RegistrationModel SHALL convert Firestore Timestamp objects to DateTime objects
5. THE RegistrationModel SHALL provide default values for optional fields to prevent null errors

### Requirement 3: Create CheckInModel

**User Story:** As a developer, I want a CheckInModel class, so that the system is prepared for future QR-based attendance tracking.

#### Acceptance Criteria

1. THE System SHALL create a CheckInModel class with fields: id, eventId, userId, checkedInAt, checkedInBy
2. THE CheckInModel SHALL implement a fromFirestore factory method that deserializes Firestore documents
3. THE CheckInModel SHALL implement a toMap method that serializes to Firestore-compatible format
4. WHEN deserializing timestamps, THE CheckInModel SHALL convert Firestore Timestamp objects to DateTime objects
5. THE CheckInModel SHALL support optional checkedInBy field for manual check-ins by staff

### Requirement 4: Create ClubModel

**User Story:** As a developer, I want a ClubModel class, so that club information has proper type safety and can be extended independently from UserModel.

#### Acceptance Criteria

1. THE System SHALL create a ClubModel class with fields: id, name, description, leaderId, history, introduction, avatar, createdAt, updatedAt
2. THE ClubModel SHALL implement a fromFirestore factory method that deserializes Firestore documents
3. THE ClubModel SHALL implement a toMap method that serializes to Firestore-compatible format
4. THE ClubModel SHALL reference the club leader via leaderId field linking to users collection
5. WHERE club data is stored separately, THE System SHALL use a `clubs` collection

### Requirement 5: Update EventService to Use New Models

**User Story:** As a developer, I want EventService to use the new model classes, so that the service layer has proper type safety and maintainability.

#### Acceptance Criteria

1. WHEN registering for events, THE EventService SHALL use RegistrationModel instead of raw maps
2. WHEN querying registrations, THE EventService SHALL deserialize results using RegistrationModel.fromFirestore
3. WHEN creating registrations, THE EventService SHALL serialize using RegistrationModel.toMap
4. THE EventService SHALL update all registration-related methods to use the `registrations` collection name
5. THE EventService SHALL maintain existing method signatures to avoid breaking changes in UI code

### Requirement 6: Establish Consistent Collection Structure

**User Story:** As a developer, I want a well-defined collection structure, so that the database schema is clear and maintainable.

#### Acceptance Criteria

1. THE System SHALL use the following collection names: `users`, `events`, `registrations`, `checkins`, `clubs`, `user_notifications`, `notifications`
2. THE System SHALL document the purpose and schema of each collection in code comments
3. WHERE a collection stores user-specific data, THE System SHALL include a userId field for querying
4. WHERE a collection stores event-specific data, THE System SHALL include an eventId field for querying
5. THE System SHALL use singular nouns for collection names except where plural form is conventional (users, events, registrations, checkins, clubs)

### Requirement 7: Maintain Backward Compatibility During Migration

**User Story:** As a developer, I want backward compatibility during migration, so that the app continues functioning while data is being migrated.

#### Acceptance Criteria

1. DURING migration, WHEN reading registration data, THE System SHALL check both `eventRegistrations` and `registrations` collections
2. DURING migration, WHEN writing registration data, THE System SHALL write to the `registrations` collection only
3. THE System SHALL provide a migration flag or configuration to control backward compatibility behavior
4. AFTER migration completion, THE System SHALL allow disabling backward compatibility reads for performance
5. THE System SHALL log warnings when reading from deprecated `eventRegistrations` collection

### Requirement 8: Prepare Structure for QR Check-In Feature

**User Story:** As a developer, I want the data structure to support future QR check-in functionality, so that attendance tracking can be implemented without major refactoring.

#### Acceptance Criteria

1. THE System SHALL create a `checkins` collection for storing attendance records
2. THE CheckInModel SHALL support storing QR code validation data in future implementations
3. WHEN a student registers for an event, THE System SHALL create a registration record in `registrations` collection
4. WHEN a student checks in at an event, THE System SHALL create a separate check-in record in `checkins` collection
5. THE System SHALL maintain separation between registration (intent to attend) and check-in (actual attendance)

### Requirement 9: Update Service Layer Dependencies

**User Story:** As a developer, I want services to depend on models rather than raw data structures, so that the codebase is maintainable and type-safe.

#### Acceptance Criteria

1. THE EventService SHALL import and use RegistrationModel for all registration operations
2. THE EventService SHALL import and use CheckInModel for future check-in operations
3. WHERE services query Firestore, THE System SHALL deserialize results using model fromFirestore methods
4. WHERE services write to Firestore, THE System SHALL serialize data using model toMap methods
5. THE System SHALL eliminate direct use of Map<String, dynamic> for entity data in service methods

### Requirement 10: Provide Migration Utilities

**User Story:** As a developer, I want migration utilities, so that I can safely transition existing data to the new structure.

#### Acceptance Criteria

1. THE System SHALL provide a migration script that copies documents from `eventRegistrations` to `registrations`
2. THE migration script SHALL preserve all existing fields and document IDs during migration
3. THE migration script SHALL validate data integrity after migration by comparing document counts
4. THE migration script SHALL provide a dry-run mode that reports what would be migrated without making changes
5. THE migration script SHALL log progress and any errors encountered during migration
