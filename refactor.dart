import 'dart:io';

const screenFolders = {
  'login_screen.dart': 'auth',
  'register_screen.dart': 'auth',
  'auth_resolver.dart': 'auth',
  'admin_dashboard.dart': 'admin',
  'manage_users_screen.dart': 'admin',
  'club_dashboard_screen.dart': 'club',
  'club_profile_screen.dart': 'club',
  'create_edit_event_screen.dart': 'event',
  'create_event_screen.dart': 'event',
  'event_detail_screen.dart': 'event',
  'events_screen.dart': 'event',
  'my_events_screen.dart': 'event',
  'edit_profile_screen.dart': 'profile',
  'profile_screen.dart': 'profile',
  'main_screen.dart': 'home',
};

void main() async {
  final libDir = Directory('lib');
  final screensDir = Directory('lib/screens');

  if (!screensDir.existsSync()) {
    print('lib/screens does not exist!');
    return;
  }

  // 1. Create subdirectories
  final folders = screenFolders.values.toSet();
  for (final folder in folders) {
    final d = Directory('lib/screens/$folder');
    if (!d.existsSync()) d.createSync();
  }

  final dartFiles = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  for (final file in dartFiles) {
    if (file.path.endsWith('refactor.dart')) continue;

    String content = file.readAsStringSync();
    String newContent = content;
    final isScreenPath =
        file.path.contains(r'lib\screens\') ||
        file.path.contains('lib/screens/');
    final currentFilename = file.uri.pathSegments.last;
    final willMove =
        isScreenPath &&
        screenFolders.containsKey(currentFilename) &&
        !file.path.contains(screenFolders[currentFilename]!);

    // Phase 1: Update outside-in references and package references
    screenFolders.forEach((targetFilename, targetFolder) {
      newContent = newContent.replaceAll(
        "'screens/$targetFilename'",
        "'screens/$targetFolder/$targetFilename'",
      );
      newContent = newContent.replaceAll(
        '"screens/$targetFilename"',
        '"screens/$targetFolder/$targetFilename"',
      );

      newContent = newContent.replaceAll(
        "'../screens/$targetFilename'",
        "'../screens/$targetFolder/$targetFilename'",
      );
      newContent = newContent.replaceAll(
        '"../screens/$targetFilename"',
        '"../screens/$targetFolder/$targetFilename"',
      );

      newContent = newContent.replaceAll(
        "'package:uni_events/screens/$targetFilename'",
        "'package:uni_events/screens/$targetFolder/$targetFilename'",
      );
      newContent = newContent.replaceAll(
        '"package:uni_events/screens/$targetFilename"',
        '"package:uni_events/screens/$targetFolder/$targetFilename"',
      );
    });

    if (willMove) {
      // Phase 2: Update structural imports that are moving one level deeper
      // 'import "../services/...""' -> 'import "../../services/..."'
      newContent = newContent.replaceAllMapped(
        RegExp(r'''import\s+['"](\.\./[^'"]+)['"]'''),
        (match) {
          final path = match.group(1)!;
          return "import '../$path'";
        },
      );

      // Phase 3: Sibling imports moving to folders
      // 'import "login_screen.dart"' -> 'import "../auth/login_screen.dart"'
      screenFolders.forEach((targetFilename, targetFolder) {
        newContent = newContent.replaceAllMapped(
          RegExp(r'''import\s+['"]''' + targetFilename + r'''['"]'''),
          (match) {
            return "import '../$targetFolder/$targetFilename'";
          },
        );
      });
    }

    if (content != newContent) {
      print('Updating imports in ${file.path}');
      file.writeAsStringSync(newContent);
    }
  }

  // 3. Move files
  screenFolders.forEach((filename, folder) {
    final file = File('lib/screens/$filename');
    if (file.existsSync()) {
      final target = 'lib/screens/$folder/$filename';
      file.renameSync(target);
      print('Moved $filename to $folder/');
    }
  });

  print('Done!');
}
