import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Menyalin gambar pilihan pengguna (image_picker) ke folder dokumen aplikasi.
/// File dari image_picker berada di cache sementara dan bisa hilang kapan saja,
/// sehingga tidak boleh disimpan langsung sebagai referensi permanen.
class ImageStorageService {
  ImageStorageService._();

  /// Mengembalikan path file hasil salinan. Nama file unik (memakai timestamp)
  /// agar `FileImage` tidak menampilkan gambar lama dari cache.
  static Future<String> saveImage(
    File source, {
    required String folder,
    required String prefix,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$folder');
    await dir.create(recursive: true);

    final dot = source.path.lastIndexOf('.');
    final ext = (dot != -1 && source.path.length - dot <= 6)
        ? source.path.substring(dot + 1)
        : 'jpg';
    final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final saved = await source.copy('${dir.path}${Platform.pathSeparator}$name');
    return saved.path;
  }

  /// Menghapus file gambar bila ada. Tidak melempar error jika gagal.
  static Future<void> deleteImage(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Abaikan: file sisa tidak membahayakan.
    }
  }
}
