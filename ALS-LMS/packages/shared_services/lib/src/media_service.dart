import 'dart:typed_data';

import 'package:shared_models/shared_models.dart';
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
}
