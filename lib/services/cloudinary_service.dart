import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';

class CloudinaryService {
  const CloudinaryService();
  static const CloudinaryService instance = CloudinaryService();

  Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse(AppConstants.cloudinaryUploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConstants.cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final secureUrl = decoded['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        }
      }
      throw Exception('Respons Cloudinary tidak memuat URL gambar yang valid.');
    }

    throw Exception(
      'Gagal mengunggah gambar ke Cloudinary (kode: ${response.statusCode}).',
    );
  }
}
