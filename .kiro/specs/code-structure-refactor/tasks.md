# Implementation Plan: Code Structure Refactor

## Overview

This implementation plan refactors the Flutter/Firebase codebase to introduce proper model abstractions, rename collections following Firebase conventions, and prepare the structure for future QR-based check-in functionality. The refactor maintains backward compatibility during migration and establishes a clean, type-safe service layer architecture.

## Tasks

- [x] 1. Create new model classes
  - [x] 1.1 Create RegistrationModel class
    - Create `lib/models/registration_model.dart` file
    - Implement fields: id, eventId, userId, status, registeredAt
    - Implement `fromFirestore` factory method with Timestamp to DateTime conversion
    - Implement `toMap` method with DateTime to Timestamp conversion
    - Add default values for optional fields
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  
  - [x] 1.2 Create CheckInModel class
    - Create `lib/models/checkin_model.dart` file
    - Implement fields: id, eventId, userId, checkedInAt, checkedInBy
    - Implement `fromFirestore` factory method with Timestamp to DateTime conversion
    - Implement `toMap` method with DateTime to Timestamp conversion
    - Support optional checkedInBy field for manual check-ins
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  
  - [x] 1.3 Create ClubModel class
    - Create `lib/models/club_model.dart` file
    - Implement fields: id, name, description, leaderId, history, introduction, avatar, createdAt, updatedAt
    - Implement `fromFirestore` factory method with Timestamp to DateTime conversion
    - Implement `toMap` method with DateTime to Timestamp conversion
    - Add documentation for club leader reference via leaderId
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 2. Update EventService to use RegistrationModel
  - [x] 2.1 Update collection references from 'eventRegistrations' to 'registrations'
    - Replace all instances of `_db.collection('eventRegistrations')` with `_db.collection('registrations')`
    - Add backward compatibility flag/configuration
    - _Requirements: 1.1, 1.2, 5.4_
  
  - [x] 2.2 Implement backward compatibility read logic
    - Create helper method to check both 'eventRegistrations' and 'registrations' collections
    - Add logging when reading from deprecated collection
    - Implement migration flag to control backward compatibility behavior
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_
  
  - [x] 2.3 Update registerForEvent method
    - Import RegistrationModel
    - Use RegistrationModel.toMap() when creating registration documents
    - Write only to 'registrations' collection
    - Maintain existing method signature
    - _Requirements: 5.1, 5.3, 5.5, 9.1, 9.4_
  
  - [x] 2.4 Update unregisterFromEvent method
    - Use RegistrationModel for querying existing registrations
    - Update to use 'registrations' collection with backward compatibility
    - Maintain existing method signature
    - _Requirements: 5.1, 5.4, 5.5_
  
  - [x] 2.5 Update isRegisteredStream method
    - Use RegistrationModel.fromFirestore() for deserialization
    - Query 'registrations' collection with backward compatibility fallback
    - Maintain existing method signature and return type
    - _Requirements: 5.2, 5.4, 5.5, 9.2, 9.3_
  
  - [x] 2.6 Update getRegisteredEvents method
    - Use RegistrationModel.fromFirestore() for deserialization
    - Query 'registrations' collection with backward compatibility fallback
    - Maintain existing method signature and return type
    - _Requirements: 5.2, 5.4, 5.5, 9.2, 9.3_
  
  - [x] 2.7 Write unit tests for EventService registration methods
    - Test registration creation with RegistrationModel
    - Test backward compatibility reads
    - Test collection name updates
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 7.1, 7.2_

- [x] 3. Checkpoint - Verify EventService refactor
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Create migration utilities
  - [x] 4.1 Create migration script for eventRegistrations → registrations
    - Create `lib/utils/migration_script.dart` or similar utility file
    - Implement function to copy documents from 'eventRegistrations' to 'registrations'
    - Preserve all existing fields and document IDs
    - Implement dry-run mode that reports changes without executing
    - Add progress logging and error handling
    - _Requirements: 1.4, 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [x] 4.2 Add data integrity validation to migration script
    - Compare document counts between source and destination collections
    - Validate field integrity for migrated documents
    - Report any discrepancies or errors
    - _Requirements: 10.3_
  
  - [x] 4.3 Write tests for migration utilities
    - Test dry-run mode
    - Test document preservation
    - Test error handling
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [x] 5. Update Firestore collection structure documentation
  - [x] 5.1 Add code comments documenting collection schemas
    - Document 'registrations' collection schema in EventService
    - Document 'checkins' collection schema (for future use)
    - Document 'clubs' collection schema if implementing separate club storage
    - Add comments explaining userId and eventId indexing requirements
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_
  
  - [x] 5.2 Document Firestore index requirements
    - Create or update documentation listing required composite indexes
    - Document indexes for registrations: (eventId, userId), userId, eventId
    - Document indexes for checkins: (eventId, userId), userId, eventId (future)
    - _Requirements: 6.3, 6.4_

- [x] 6. Prepare check-in infrastructure
  - [x] 6.1 Create checkins collection structure
    - Add code comments in EventService documenting 'checkins' collection
    - Document separation between registration and check-in concepts
    - Add placeholder methods for future check-in functionality (commented out)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [x] 6.2 Document registration vs check-in separation
    - Add comments explaining registration (intent) vs check-in (attendance)
    - Document that registrations are mutable, check-ins are immutable
    - Explain future QR code integration points
    - _Requirements: 8.3, 8.4, 8.5_

- [x] 7. Final integration and cleanup
  - [x] 7.1 Remove direct Map<String, dynamic> usage in EventService
    - Replace all raw map operations with model-based operations
    - Ensure all Firestore queries use model deserialization
    - Ensure all Firestore writes use model serialization
    - _Requirements: 9.3, 9.4, 9.5_
  
  - [x] 7.2 Verify no breaking changes to UI layer
    - Confirm all EventService method signatures remain unchanged
    - Test that existing screens continue to function
    - Verify backward compatibility during migration period
    - _Requirements: 5.5, 7.1, 7.2, 7.3_
  
  - [x] 7.3 Write integration tests for refactored service layer
    - Test end-to-end registration flow with new models
    - Test backward compatibility reads
    - Test migration scenarios
    - _Requirements: 5.1, 5.2, 5.3, 7.1, 7.2_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster implementation
- All model classes use Dart with Flutter/Firebase conventions
- Backward compatibility is maintained during migration to avoid breaking existing functionality
- The refactor prepares the codebase for future QR check-in feature without implementing it
- UI layer remains unchanged - only service and model layers are refactored
- Migration script should be run manually by developer after code changes are deployed
