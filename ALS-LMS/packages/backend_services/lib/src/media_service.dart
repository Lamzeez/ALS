import 'dart:typed_data';

import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';

class MediaService {
  Future<void> deleteMedia(LessonMedia media) async {
    await SupabaseConfig.client
        .from('lesson_media')
        .delete()
        .eq('id', media.id);
    try {
      await SupabaseConfig.client.storage
          .from('lessons-media')
          .remove([media.storageUrl]);
    } catch (_) {}
  }

  Future<void> uploadLessonMedia({
    required List<int> file,
    required String fileName,
    required String lessonId,
    required MediaFileType type,
  }) async {
    final path = '$lessonId/$fileName';
    await SupabaseConfig.client.storage
        .from('lessons-media')
        .uploadBinary(path, Uint8List.fromList(file));
    final storageUrl =
        SupabaseConfig.client.storage.from('lessons-media').getPublicUrl(path);
    await SupabaseConfig.client.from('lesson_media').insert({
      'lesson_id': lessonId,
      'storage_url': storageUrl,
      'file_name': fileName,
      'file_type': type.toJson(),
    });
  }

  /// 📤 Upload QR Code for a course
  Future<String> uploadQrCode(String courseId, List<int> qrImageBytes) async {
    return SupabaseConfig.withRetry(
      () async {
        final path = 'courses/$courseId/qr.png';
        await SupabaseConfig.client.storage.from('qr-codes').uploadBinary(
              path,
              Uint8List.fromList(qrImageBytes),
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/png'),
            );

        final publicUrl =
            SupabaseConfig.client.storage.from('qr-codes').getPublicUrl(path);

        // Update course with QR code URL
        await SupabaseConfig.client
            .from('courses')
            .update({'qr_code_url': publicUrl}).eq('id', courseId);

        return publicUrl;
      },
      operationName: 'uploadQrCode',
      timeout: SupabaseConfig.longTimeout,
    );
  }
}

