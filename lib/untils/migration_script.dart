import 'package:cloud_firestore/cloud_firestore.dart';

/// Migration utility for transitioning from 'eventRegistrations' to 'registrations' collection
///
/// This script safely copies all documents from the deprecated 'eventRegistrations'
/// collection to the new 'registrations' collection while preserving all data integrity.
///
/// Features:
/// - Dry-run mode to preview changes without executing
/// - Progress logging for visibility
/// - Error handling and reporting
/// - Document ID preservation
/// - Field integrity validation
class MigrationScript {
  final FirebaseFirestore _db;

  /// Collection names
  static const String _sourceCollection = 'eventRegistrations';
  static const String _targetCollection = 'registrations';

  MigrationScript({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  /// Migrate all documents from eventRegistrations to registrations
  ///
  /// Parameters:
  /// - [dryRun]: If true, reports what would be migrated without making changes
  /// - [onProgress]: Optional callback for progress updates (current, total, message)
  ///
  /// Returns a MigrationResult with statistics and any errors encountered
  Future<MigrationResult> migrateRegistrations({
    bool dryRun = false,
    void Function(int current, int total, String message)? onProgress,
  }) async {
    final result = MigrationResult();
    final startTime = DateTime.now();

    try {
      // Step 1: Count source documents
      _log('Counting documents in $_sourceCollection...', onProgress, 0, 0);
      final sourceSnapshot = await _db.collection(_sourceCollection).get();
      final totalDocs = sourceSnapshot.docs.length;

      if (totalDocs == 0) {
        _log(
          'No documents found in $_sourceCollection collection',
          onProgress,
          0,
          0,
        );
        result.sourceCount = 0;
        result.success = true;
        return result;
      }

      _log('Found $totalDocs documents to migrate', onProgress, 0, totalDocs);
      result.sourceCount = totalDocs;

      if (dryRun) {
        _log('DRY RUN MODE: No changes will be made', onProgress, 0, totalDocs);
      }

      // Step 2: Check target collection for existing documents
      final targetSnapshot = await _db.collection(_targetCollection).get();
      final existingDocs = <String>{};
      for (var doc in targetSnapshot.docs) {
        existingDocs.add(doc.id);
      }

      _log(
        'Found ${existingDocs.length} existing documents in $_targetCollection',
        onProgress,
        0,
        totalDocs,
      );

      // Step 3: Migrate documents
      int processed = 0;
      int skipped = 0;
      int migrated = 0;

      for (var sourceDoc in sourceSnapshot.docs) {
        processed++;

        try {
          final docId = sourceDoc.id;
          final data = sourceDoc.data();

          // Check if document already exists in target
          if (existingDocs.contains(docId)) {
            skipped++;
            _log(
              'Skipping $docId (already exists in target)',
              onProgress,
              processed,
              totalDocs,
            );
            result.skippedDocs.add(docId);
            continue;
          }

          // Validate data structure
          if (!_validateRegistrationData(data)) {
            result.errors.add(
              'Invalid data structure in document $docId: missing required fields',
            );
            _log(
              'ERROR: Invalid data in $docId',
              onProgress,
              processed,
              totalDocs,
            );
            continue;
          }

          // Perform migration (or simulate in dry-run mode)
          if (!dryRun) {
            await _db.collection(_targetCollection).doc(docId).set(data);
          }

          migrated++;
          result.migratedDocs.add(docId);

          if (processed % 10 == 0 || processed == totalDocs) {
            _log(
              'Progress: $processed/$totalDocs (migrated: $migrated, skipped: $skipped)',
              onProgress,
              processed,
              totalDocs,
            );
          }
        } catch (e) {
          result.errors.add('Error migrating document ${sourceDoc.id}: $e');
          _log(
            'ERROR migrating ${sourceDoc.id}: $e',
            onProgress,
            processed,
            totalDocs,
          );
        }
      }

      // Step 4: Validate migration
      if (!dryRun) {
        _log('Validating migration...', onProgress, totalDocs, totalDocs);
        final validationResult = await validateMigration();
        result.targetCount = validationResult.targetCount;
        result.errors.addAll(validationResult.errors);

        if (validationResult.isValid) {
          _log(
            'Migration validation successful',
            onProgress,
            totalDocs,
            totalDocs,
          );
        } else {
          _log(
            'Migration validation found issues',
            onProgress,
            totalDocs,
            totalDocs,
          );
        }
      } else {
        result.targetCount = existingDocs.length;
      }

      // Step 5: Summary
      final duration = DateTime.now().difference(startTime);
      result.success = result.errors.isEmpty;
      result.durationSeconds = duration.inSeconds;

      final mode = dryRun ? 'DRY RUN' : 'COMPLETED';
      _log(
        'Migration $mode: $migrated migrated, $skipped skipped, ${result.errors.length} errors in ${duration.inSeconds}s',
        onProgress,
        totalDocs,
        totalDocs,
      );
    } catch (e) {
      result.success = false;
      result.errors.add('Migration failed: $e');
      _log('FATAL ERROR: $e', onProgress, 0, 0);
    }

    return result;
  }

  /// Validate data integrity after migration
  ///
  /// Compares document counts and validates field integrity between
  /// source and target collections.
  Future<ValidationResult> validateMigration() async {
    final result = ValidationResult();

    try {
      // Count documents in both collections
      final sourceSnapshot = await _db.collection(_sourceCollection).get();
      final targetSnapshot = await _db.collection(_targetCollection).get();

      result.sourceCount = sourceSnapshot.docs.length;
      result.targetCount = targetSnapshot.docs.length;

      // Check if all source documents exist in target
      final targetDocIds = targetSnapshot.docs.map((doc) => doc.id).toSet();

      for (var sourceDoc in sourceSnapshot.docs) {
        if (!targetDocIds.contains(sourceDoc.id)) {
          result.errors.add(
            'Document ${sourceDoc.id} exists in source but not in target',
          );
        } else {
          // Validate field integrity for documents that exist in both
          final targetDoc = targetSnapshot.docs.firstWhere(
            (doc) => doc.id == sourceDoc.id,
          );
          final sourceData = sourceDoc.data();
          final targetData = targetDoc.data();

          // Check required fields
          for (var field in ['eventId', 'userId', 'status', 'registeredAt']) {
            if (sourceData[field] != targetData[field]) {
              result.errors.add(
                'Field mismatch in ${sourceDoc.id}: $field differs between source and target',
              );
            }
          }
        }
      }

      result.isValid = result.errors.isEmpty;
    } catch (e) {
      result.errors.add('Validation failed: $e');
      result.isValid = false;
    }

    return result;
  }

  /// Validate that a document has the required registration fields
  bool _validateRegistrationData(Map<String, dynamic> data) {
    return data.containsKey('eventId') &&
        data.containsKey('userId') &&
        data.containsKey('status') &&
        data.containsKey('registeredAt');
  }

  /// Helper to log messages and call progress callback
  void _log(
    String message,
    void Function(int current, int total, String message)? onProgress,
    int current,
    int total,
  ) {
    print('[Migration] $message');
    onProgress?.call(current, total, message);
  }
}

/// Result of a migration operation
class MigrationResult {
  /// Number of documents in source collection
  int sourceCount = 0;

  /// Number of documents in target collection after migration
  int targetCount = 0;

  /// List of document IDs that were migrated
  List<String> migratedDocs = [];

  /// List of document IDs that were skipped (already existed)
  List<String> skippedDocs = [];

  /// List of errors encountered during migration
  List<String> errors = [];

  /// Whether the migration completed successfully
  bool success = false;

  /// Duration of migration in seconds
  int durationSeconds = 0;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Migration Result:');
    buffer.writeln('  Source documents: $sourceCount');
    buffer.writeln('  Target documents: $targetCount');
    buffer.writeln('  Migrated: ${migratedDocs.length}');
    buffer.writeln('  Skipped: ${skippedDocs.length}');
    buffer.writeln('  Errors: ${errors.length}');
    buffer.writeln('  Success: $success');
    buffer.writeln('  Duration: ${durationSeconds}s');

    if (errors.isNotEmpty) {
      buffer.writeln('\nErrors:');
      for (var error in errors) {
        buffer.writeln('  - $error');
      }
    }

    return buffer.toString();
  }
}

/// Result of migration validation
class ValidationResult {
  /// Number of documents in source collection
  int sourceCount = 0;

  /// Number of documents in target collection
  int targetCount = 0;

  /// Whether validation passed
  bool isValid = false;

  /// List of validation errors
  List<String> errors = [];

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Validation Result:');
    buffer.writeln('  Source count: $sourceCount');
    buffer.writeln('  Target count: $targetCount');
    buffer.writeln('  Valid: $isValid');

    if (errors.isNotEmpty) {
      buffer.writeln('\nValidation Errors:');
      for (var error in errors) {
        buffer.writeln('  - $error');
      }
    }

    return buffer.toString();
  }
}
