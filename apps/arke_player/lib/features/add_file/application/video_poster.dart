import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

import 'file_importer.dart';

/// A film's poster, taken by the platform's own decoder (MediaMetadataRetriever on Android) at
/// 640 by 360 at most, which covers a Continue card at 2x.
class NativeVideoPoster implements VideoPoster {
  const NativeVideoPoster();

  @override
  Future<bool> save(String video, String jpeg) =>
      FcNativeVideoThumbnail().saveThumbnailToFile(srcFile: video, destFile: jpeg, width: 640, height: 360, format: 'jpeg', quality: 82);
}
