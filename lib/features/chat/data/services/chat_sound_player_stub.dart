import 'package:audioplayers/audioplayers.dart';

/// Native chat/notification sound engine.
///
/// The project already bundles a dedicated royal sound family under
/// assets/audio/royal. The previous implementation used Android's generic
/// system click/alert tones, so the app could never sound like a real chat
/// product even though the event model already distinguished mentions,
/// messages, calls, gifts and notifications.
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
      mode: PlayerMode.lowLatency,
    );
  } catch (_) {
    // Sound is non-critical and must never break chat functionality.
  }
}

/// Kept as a compatibility hook for the chat composer.
///
/// Android does not require the browser-style user-gesture audio unlock that
/// the web player does, so this simply prepares the native player.
Future<bool> unlockChatAudio() async {
  try {
    await _chatAudioPlayer.setVolume(0.0);
    await _chatAudioPlayer.play(
      AssetSource(_royalAssets['notification']!),
      volume: 0.0,
      mode: PlayerMode.lowLatency,
    );
    await _chatAudioPlayer.stop();
    await _chatAudioPlayer.setVolume(0.86);
    return true;
  } catch (_) {
    return false;
  }
}
