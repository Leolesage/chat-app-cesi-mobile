import 'package:audioplayers/audioplayers.dart';

class NotificationSoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playIncomingMessage() async {
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/notify.wav'),
        mode: PlayerMode.lowLatency,
        volume: 1.0,
      );
    } catch (_) {
      // silent
    }
  }
}
