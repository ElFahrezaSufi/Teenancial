import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';
import 'connectivity_service.dart';

class CloudinaryService {
  const CloudinaryService();
  static const CloudinaryService instance = CloudinaryService();

  static const Duration _uploadTimeout = Duration(seconds: 20);

  Future<String> uploadImage(File imageFile) async {
    if (ConnectivityService.instance.isOffline) {
      throw const OfflineException(
        'Tidak ada koneksi internet. Hubungkan ke internet untuk mengunggah gambar.',
      );
    }

    final uri = Uri.parse(AppConstants.cloudinaryUploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConstants.cloudinaryUploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      final response = await request.send().timeout(_uploadTimeout);
      final responseBody =
          await response.stream.bytesToString().timeout(_uploadTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) {
          final secureUrl = decoded['secure_url'] as String?;
          if (secureUrl != null && secureUrl.isNotEmpty) {
            return secureUrl;
          }
        }
        throw Exception(
          'Respons Cloudinary tidak memuat URL gambar yang valid.',
        );
      }

      throw Exception(
        'Gagal mengunggah gambar ke Cloudinary (kode: ${response.statusCode}).',
      );
    } on TimeoutException {
      ConnectivityService.instance.markOfflineFromError();
      throw const OfflineException(
        'Waktu unggah gambar habis. Periksa koneksi internetmu dan coba lagi.',
      );
    } on SocketException {
      ConnectivityService.instance.markOfflineFromError();
      throw const OfflineException(
        'Tidak ada koneksi internet. Hubungkan ke internet untuk mengunggah gambar.',
      );
    }
  }
}
