# Firestore Index Requirements

This document lists all required Firestore indexes for the university event management application. These indexes must be created in the Firebase Console to ensure optimal query performance.

## Overview

Firestore requires composite indexes for queries that filter or sort on multiple fields. Single-field indexes are created automatically, but composite indexes must be manually configured.

## Required Indexes

### 1. Registrations Collection

The `registrations` collection stores user registrations for events (intent to attend).

#### Composite Indexes

**Index 1: Event-User Lookup**
- **Collection:** `registrations`
- **Fields:**
  - `eventId` (Ascending)
  - `userId` (Ascending)
- **Purpose:** Check if a specific user is registered for a specific event
- **Used by:** `isRegisteredStream()` method in EventService
- **Query example:** `registrations.where('eventId', '==', eventId).where('userId', '==', userId)`

#### Single-Field Indexes

**Index 2: User's Registrations**
- **Collection:** `registrations`
- **Field:** `userId` (Ascending)
- **Purpose:** Query all events a user is registered for
- **Used by:** `getRegisteredEvents()` method in EventService
- **Query example:** `registrations.where('userId', '==', userId)`

**Index 3: Event's Registrations**
- **Collection:** `registrations`
- **Field:** `eventId` (Ascending)
- **Purpose:** Query all users registered for an event
- **Used by:** Event participant list queries
- **Query example:** `registrations.where('eventId', '==', eventId)`

**Note:** Single-field indexes are typically created automatically by Firestore, but are listed here for completeness.

---

### 2. Check-ins Collection (Future Feature)

The `checkins` collection will store user check-ins at events (actual attendance). This collection is prepared for future QR-based check-in functionality.

#### Composite Indexes

**Index 1: Event-User Check-in Lookup**
- **Collection:** `checkins`
- **Fields:**
  - `eventId` (Ascending)
  - `userId` (Ascending)
- **Purpose:** Check if a specific user has checked into a specific event
- **Used by:** Future `isCheckedInStream()` method
- **Query example:** `checkins.where('eventId', '==', eventId).where('userId', '==', userId)`

#### Single-Field Indexes

**Index 2: User's Check-ins**
- **Collection:** `checkins`
- **Field:** `userId` (Ascending)
- **Purpose:** Query all events a user has checked into
- **Used by:** Future user attendance history queries
- **Query example:** `checkins.where('userId', '==', userId)`

**Index 3: Event's Check-ins**
- **Collection:** `checkins`
- **Field:** `eventId` (Ascending)
- **Purpose:** Query all users who checked into an event
- **Used by:** Future event attendance reports
- **Query example:** `checkins.where('eventId', '==', eventId)`

**Status:** These indexes are not yet required but should be created when the QR check-in feature is implemented.

---

## How to Create Indexes

### Method 1: Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `uni-events-72162`
3. Navigate to **Firestore Database** → **Indexes** tab
4. Click **Create Index**
5. Configure the index:
   - **Collection ID:** Enter the collection name (e.g., `registrations`)
   - **Fields to index:** Add fields in order with sort direction
   - **Query scope:** Collection
6. Click **Create**

### Method 2: Automatic Creation via Error Message

When you run a query that requires a composite index, Firestore will throw an error with a direct link to create the required index. Click the link to automatically configure the index.

Example error:
```
The query requires an index. You can create it here: https://console.firebase.google.com/...
```

### Method 3: firestore.indexes.json (Advanced)

Create a `firestore.indexes.json` file in your project root with the following content:

```json
{
  "indexes": [
    {
      "collectionGroup": "registrations",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "eventId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy indexes using Firebase CLI:
```bash
firebase deploy --only firestore:indexes
```

---

## Migration Notes

### Legacy Collection: eventRegistrations

If you're migrating from the old `eventRegistrations` collection to the new `registrations` collection:

1. **During migration period:** Indexes on both collections may be needed if backward compatibility is enabled
2. **After migration:** Only `registrations` indexes are required
3. **Cleanup:** Old `eventRegistrations` indexes can be deleted after migration is complete and backward compatibility is disabled

### Verifying Indexes

To verify that indexes are working correctly:

1. Check the **Indexes** tab in Firebase Console
2. Ensure all indexes show status: **Enabled** (not Building or Error)
3. Run your application and monitor for index-related errors in logs
4. Test queries that use composite indexes (e.g., checking registration status)

---

## Performance Considerations

### Index Size

- Each composite index increases storage costs slightly
- Indexes are automatically maintained by Firestore
- The indexes listed here are essential for query performance

### Query Optimization

- Use composite indexes for queries with multiple equality filters
- Single-field indexes are sufficient for single-field queries
- Avoid queries that require too many indexes (consider data model changes)

### Monitoring

Monitor index usage in Firebase Console:
- **Firestore** → **Usage** tab shows query performance
- Slow queries may indicate missing indexes
- Unused indexes can be safely deleted

---

## Related Documentation

- **Code Documentation:** See `lib/models/registration_model.dart` and `lib/models/checkin_model.dart` for index requirements in code comments
- **Service Documentation:** See `lib/services/event_services.dart` for collection schema and index documentation
- **Migration Guide:** See `lib/untils/MIGRATION_README.md` for migration-specific index considerations

---

## Summary

**Currently Required (Production):**
- ✅ `registrations` collection: composite index `(eventId, userId)`

**Future Requirements (When QR Check-in is Implemented):**
- ⏳ `checkins` collection: composite index `(eventId, userId)`

**Note:** Single-field indexes on `userId` and `eventId` are typically created automatically by Firestore when you first query those fields.
