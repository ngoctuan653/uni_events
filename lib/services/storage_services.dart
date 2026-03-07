import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class StorageService {
  // TODO: Replace with your actual Cloudinary cloud name
  final String cloudName = "dzp2wiyah";

  // TODO: Replace with your actual Cloudinary upload preset name
  final String uploadPreset = "uni_events_img";

  /// Uploads a file to Cloudinary and returns the secure URL
  /// [folderPath] is traditionally used to separate 'avatars' and 'events'
  Future<String?> uploadImage(File imageFile, String folderPath) async {
    try {
      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
      );

      var request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      request.fields['upload_preset'] = uploadPreset;
      // Many cloudinary presets allow overriding the folder
      request.fields['folder'] = folderPath;

      var response = await request.send();

      if (response.statusCode == 200) {
        final res = await response.stream.bytesToString();
        final data = jsonDecode(res);
        return data['secure_url'];
      } else {
        final res = await response.stream.bytesToString();
        print('Cloudinary Error: $res');
        return null;
      }
    } catch (e) {
      print('Exception uploading to Cloudinary: $e');
      return null;
    }
  }
}
