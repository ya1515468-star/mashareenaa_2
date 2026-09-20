import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class AgoraEventHandler {
  void register(RtcEngine engine) {
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {},
        onUserJoined: (connection, remoteUid, elapsed) {},
        onUserOffline: (connection, remoteUid, reason) {},
      ),
    );
  }
}
