import 'package:just_audio/just_audio.dart';
import 'package:matrix/matrix.dart';

/// Manages call notification sounds (ringtone, call-end tone).
///
/// Uses the same `just_audio` package that upstream FluffyChat uses
/// for its existing VoIP ringtone support.
class CallNotificationService {
  AudioPlayer? _ringtonePlayer;
  bool _isRinging = false;

  /// Start playing the incoming call ringtone in a loop.
  Future<void> startRingtone() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      _ringtonePlayer ??= AudioPlayer();
      await _ringtonePlayer!.setAsset('assets/sounds/call.ogg');
      await _ringtonePlayer!.setLoopMode(LoopMode.one);
      await _ringtonePlayer!.play();
    } catch (e) {
      Logs().w('[LetsYak] Failed to play ringtone', e);
    }
  }

  /// Stop the ringtone.
  Future<void> stopRingtone() async {
    _isRinging = false;
    try {
      await _ringtonePlayer?.stop();
    } catch (_) {}
  }

  /// Play the call-connected sound.
  Future<void> playConnectedSound() async {
    try {
      final player = AudioPlayer();
      await player.setAsset('assets/sounds/call.ogg');
      await player.play();
      // Let it finish, then dispose
      player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          player.dispose();
        }
      });
    } catch (e) {
      Logs().w('[LetsYak] Failed to play connected sound', e);
    }
  }

  void dispose() {
    _ringtonePlayer?.dispose();
    _ringtonePlayer = null;
  }
}
