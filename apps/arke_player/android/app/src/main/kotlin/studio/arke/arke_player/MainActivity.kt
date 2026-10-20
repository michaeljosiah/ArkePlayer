package studio.arke.arke_player

import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// audio_service needs its own activity so the media session, the lock screen and the headset
// reach the engine that is playing (docs/decisions/0004).
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The space a file would take is checked against what is free before anything is copied,
        // so a file too large is refused with both numbers rather than failing half-way (P7 rule 3).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "studio.arke.player/storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "freeBytes" -> {
                    val path = call.argument<String>("path") ?: filesDir.path
                    result.success(StatFs(path).availableBytes)
                }
                "totalBytes" -> {
                    val path = call.argument<String>("path") ?: filesDir.path
                    result.success(StatFs(path).totalBytes)
                }
                else -> result.notImplemented()
            }
        }
    }
}
