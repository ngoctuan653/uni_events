/// Migration configuration for collection name changes
///
/// This file controls backward compatibility behavior during the migration
/// from 'eventRegistrations' to 'registrations' collection.
class MigrationConfig {
  /// Enable backward compatibility reads from old 'eventRegistrations' collection
  ///
  /// When true, the system will check both 'eventRegistrations' and 'registrations'
  /// collections when reading data. This allows for a gradual migration.
  ///
  /// When false, only the new 'registrations' collection will be used.
  ///
  /// Set to false after migration is complete for better performance.
  static const bool enableBackwardCompatibility = true;

  /// Log warnings when reading from deprecated collections
  ///
  /// When true, logs will be printed whenever data is read from the old
  /// 'eventRegistrations' collection during backward compatibility mode.
  static const bool logDeprecatedReads = true;
}
