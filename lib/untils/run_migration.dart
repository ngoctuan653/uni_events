import 'package:firebase_core/firebase_core.dart';
import 'migration_script.dart';

/// Example script to run the migration from eventRegistrations to registrations
///
/// This file demonstrates how to use the MigrationScript utility.
///
/// USAGE:
/// 1. First run in dry-run mode to preview changes:
///    ```dart
///    await runMigration(dryRun: true);
///    ```
///
/// 2. After verifying the dry-run output, run the actual migration:
///    ```dart
///    await runMigration(dryRun: false);
///    ```
///
/// 3. After migration completes, update MigrationConfig.enableBackwardCompatibility
///    to false in lib/untils/migration_config.dart
///
/// IMPORTANT: This script should be run manually by a developer with appropriate
/// Firebase permissions. It is not intended to be run automatically or by end users.
Future<void> runMigration({bool dryRun = true}) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp();

  print('='.repeat(60));
  print('Registration Collection Migration');
  print('From: eventRegistrations → To: registrations');
  print('Mode: ${dryRun ? "DRY RUN (no changes)" : "LIVE MIGRATION"}');
  print('='.repeat(60));
  print('');

  // Create migration script instance
  final migration = MigrationScript();

  // Run migration with progress callback
  final result = await migration.migrateRegistrations(
    dryRun: dryRun,
    onProgress: (current, total, message) {
      // Progress callback - can be used to update UI or log to file
      if (total > 0) {
        final percent = (current / total * 100).toStringAsFixed(1);
        print('[$percent%] $message');
      } else {
        print(message);
      }
    },
  );

  // Print results
  print('');
  print('='.repeat(60));
  print(result.toString());
  print('='.repeat(60));

  if (dryRun) {
    print('');
    print('This was a DRY RUN - no changes were made.');
    print('To perform the actual migration, run with dryRun: false');
  } else if (result.success) {
    print('');
    print('Migration completed successfully!');
    print('');
    print('Next steps:');
    print('1. Verify the data in the registrations collection');
    print('2. Update MigrationConfig.enableBackwardCompatibility to false');
    print('3. Deploy the updated configuration');
    print('4. After confirming everything works, you can delete the');
    print('   eventRegistrations collection (keep a backup!)');
  } else {
    print('');
    print('Migration completed with errors. Please review the errors above.');
    print('Do not disable backward compatibility until issues are resolved.');
  }
}

/// Extension to repeat strings (for formatting)
extension StringRepeat on String {
  String repeat(int count) => List.filled(count, this).join();
}
