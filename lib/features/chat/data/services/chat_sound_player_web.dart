import 'package:audioplayers/audioplayers.dart';

/// Web implementation of the same royal event map used by Android/iOS.
///
/// Keeping the source names identical means mentions, replies, calls,
/// notifications, gifts and chat messages keep the same sound identity
/// regardless of the platform.
final AudioPlayer _chatAudioPlayer = AudioPlayer();

const _royalAssets = <String, String>{
  'send': 'audio/royal/crown_light.wav',
  'receive': 'audio/royal/cosmic_gate.wav',
  'publicMessage': 'audio/royal/golden_rain.wav',
  'privateMessage': 'audio/royal/diamond_storm.wav',
  'mention': 'audio/royal/phoenix_flame.wav',
  'reply': 'audio/royal/ice_dragon.wav',
  'friendRequest': 'audio/royal/lion_gold.wav',
  'gift': 'audio/royal/dragon_fire.wav',
  'notification': 'audio/royal/crown_light.wav',
  'warning': 'audio/royal/thunder_crown.wav',
  'call': 'audio/royal/lion_fire.wav',
  'transfer': 'audio/royal/diamond_storm.wav',
  'block': 'audio/royal/thunder_crown.wav',
};

Future<void> playChatSound(String event) async {
  final asset = _royalAssets[event] ?? _royalAssets['notification']!;
  try {
    await _chatAudioPlayer.stop();
    await _chatAudioPlayer.play(
      AssetSource(asset),
      volume: 0.86,
      mode: PlayerMode.mediaPlayer,
    );
  } catch (_) {
    // Browser autoplay/user-gesture restrictions are non-fatal.
  }
}

/// Call this from a user gesture (composer tap/settings) to unlock the
/// browser audio pipeline before background-style notifications are played.
Future<bool> unlockChatAudio() async {
  try {
    await _chatAudioPlayer.setVolume(0.0);
    await _chatAudioPlayer.play(
      AssetSource(_royalAssets['notification']!),
      volume: 0.0,
      mode: PlayerMode.mediaPlayer,
    );
    await _chatAudioPlayer.stop();
    await _chatAudioPlayer.setVolume(0.86);
    return true;
  } catch (_) {
    return false;
  }
}
