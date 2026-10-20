package studio.arke.arke_player

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs its own activity so the media session, the lock screen and the headset
// reach the engine that is playing (docs/decisions/0004).
class MainActivity : AudioServiceActivity()
