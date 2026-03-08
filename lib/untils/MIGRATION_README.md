# Collection Migration Guide

This directory contains utilities for migrating data from the deprecated `eventRegistrations` collection to the new `registrations` collection.

## Overview

As part of the code structure refactor, we're renaming the `eventRegistrations` collection to `registrations` to follow Firebase naming conventions. This migration must be performed carefully to ensure no data loss.

## Files

- **migration_script.dart**: Core migration utility with dry-run support, validation, and error handling
- **run_migration.dart**: Example script demonstrating how to use the migration utility
- **migration_config.dart**: Configuration for backward compatibility behavior

## Migration Process

### Step 1: Verify Current State

Before running the migration, verify your current data:

1. Check the number of documents in `eventRegistrations` collection
2. Ensure you have a backup of your Firestore database
3. Review the migration script to understand what it will do

### Step 2: Run Dry-Run Migration

First, run the migration in dry-run mode to preview what will happen:

```dart
import 'package:uni_events/untils/run_migration.dart';

void main() async {
  // This will NOT make any changes
  await runMigration(dryRun: true);
}
```

The dry-run will:
- Count documents in source collection
- Report what would be migrated
- Identify any potential issues
- NOT make any actual changes

Review the output carefully. It should show:
- Total documents to migrate
- Any validation errors
- Estimated time

### Step 3: Run Actual Migration

After verifying the dry-run output, run the actual migration:

```dart
import 'package:uni_events/untils/run_migration.dart';

void main() async {
  // This WILL make changes
  await runMigration(dryRun: false);
}
```

The migration will:
- Copy all documents from `eventRegistrations` to `registrations`
- Preserve document IDs and all fields
- Skip documents that already exist in target
- Validate data integrity after migration
- Report progress and any errors

### Step 4: Verify Migration

After migration completes successfully:

1. Check that document counts match between source and target
2. Verify a few sample documents to ensure data integrity
3. Test the app to ensure registration functionality works
4. Monitor logs for any issues

### Step 5: Disable Backward Compatibility

Once you've verified the migration is successful:

1. Update `lib/untils/migration_config.dart`:
   ```dart
   static const bool enableBackwardCompatibility = false;
   ```

2. Deploy the updated configuration

3. Monitor the app for any issues

### Step 6: Clean Up (Optional)

After confirming everything works with backward compatibility disabled:

1. Keep the old `eventRegistrations` collection for a grace period (e.g., 1-2 weeks)
2. Create a backup of the old collection
3. Delete the `eventRegistrations` collection from Firestore

**WARNING**: Do not delete the old collection until you're absolutely certain the migration was successful and the app is working correctly!

## Migration Features

### Dry-Run Mode

The migration script supports dry-run mode, which simulates the migration without making any changes. This allows you to:
- Preview what will be migrated
- Identify potential issues
- Verify document counts
- Test the migration process

### Progress Logging

The migration script provides detailed progress logging:
- Document counting
- Migration progress (every 10 documents)
- Validation status
- Error reporting
- Summary statistics

### Error Handling

The migration script handles various error scenarios:
- Invalid data structures (missing required fields)
- Firestore connection issues
- Document write failures
- Validation failures

All errors are logged and included in the migration result.

### Document Preservation

The migration script preserves:
- Document IDs (same ID in source and target)
- All document fields (including extra fields)
- Field values (exact copies)
- Timestamps (converted properly)

### Skip Existing Documents

If a document already exists in the target collection (same document ID), the migration script will:
- Skip the document (not overwrite)
- Log the skip
- Include it in the skipped count

This allows you to:
- Re-run the migration safely
- Migrate in batches
- Handle partial migrations

### Data Validation

After migration, the script validates:
- Document counts match
- All source documents exist in target
- Field values match between source and target
- Required fields are present

## Backward Compatibility

During the migration period, the app maintains backward compatibility by:

1. **Reading**: Checks both `eventRegistrations` and `registrations` collections
2. **Writing**: Writes only to `registrations` collection
3. **Logging**: Logs warnings when reading from deprecated collection

This is controlled by `MigrationConfig.enableBackwardCompatibility` in `migration_config.dart`.

### Why Backward Compatibility?

Backward compatibility allows:
- Zero-downtime migration
- Gradual rollout
- Easy rollback if issues occur
- Testing in production with real data

### When to Disable

Disable backward compatibility after:
- Migration is complete
- Data validation passes
- App is tested and working
- Monitoring shows no issues

Disabling backward compatibility improves performance by eliminating redundant queries.

## Troubleshooting

### Migration Fails with Errors

If the migration fails:

1. Review the error messages in the output
2. Check Firestore permissions
3. Verify network connectivity
4. Check for invalid data in source collection
5. Re-run the migration (it will skip already-migrated documents)

### Document Count Mismatch

If validation reports a document count mismatch:

1. Check if some documents have invalid data (they won't be migrated)
2. Review the error log for specific document IDs
3. Manually inspect problematic documents
4. Fix invalid data and re-run migration

### App Not Working After Migration

If the app has issues after migration:

1. Check that `MigrationConfig.enableBackwardCompatibility` is still `true`
2. Review app logs for specific errors
3. Verify Firestore indexes are created
4. Test registration functionality manually
5. If needed, you can rollback by re-enabling backward compatibility

### Performance Issues

If you experience performance issues:

1. Ensure backward compatibility is disabled after migration
2. Verify Firestore indexes are created for `registrations` collection
3. Check query patterns in EventService
4. Monitor Firestore usage in Firebase Console

## Required Firestore Indexes

After migration, ensure these indexes exist for the `registrations` collection:

1. **Composite index**: `(eventId, userId)`
   - Used for checking if a user is registered for an event

2. **Single field index**: `userId`
   - Used for querying a user's registrations

3. **Single field index**: `eventId`
   - Used for querying an event's registrations

These indexes should be created automatically when queries are first executed, but you can create them manually in the Firebase Console for better performance.

## Testing

The migration script includes comprehensive unit tests in `test/migration_script_test.dart`:

- Empty collection handling
- Dry-run mode
- Document preservation
- Field integrity
- Skip existing documents
- Error handling
- Progress callbacks
- Large batch handling
- Validation

Run tests with:
```bash
flutter test test/migration_script_test.dart
```

## Support

If you encounter issues during migration:

1. Review this documentation
2. Check the test files for examples
3. Review the migration script source code
4. Check Firebase Console for Firestore status
5. Review app logs for specific errors

## Summary Checklist

- [ ] Backup Firestore database
- [ ] Run dry-run migration
- [ ] Review dry-run output
- [ ] Run actual migration
- [ ] Verify document counts
- [ ] Test app functionality
- [ ] Monitor for issues
- [ ] Disable backward compatibility
- [ ] Deploy updated config
- [ ] Monitor for issues
- [ ] Create backup of old collection
- [ ] Delete old collection (after grace period)

## Important Notes

- **Always run dry-run first**: Never run the actual migration without reviewing dry-run output
- **Keep backups**: Always maintain backups of your Firestore database
- **Monitor closely**: Watch for issues after migration and be ready to rollback
- **Grace period**: Keep the old collection for at least 1-2 weeks after migration
- **Test thoroughly**: Test all registration-related functionality after migration
