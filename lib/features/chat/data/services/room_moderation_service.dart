import 'package:supabase_flutter/supabase_flutter.dart';

class RoomModerationService {
  final SupabaseClient supabase;

  RoomModerationService(this.supabase);

  Future<void> muteMember({
    required String roomId,
    required String userId,
    int? durationMinutes,
    String? reason,
  }) async {
    await supabase.rpc(
      'mute_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_duration_minutes': durationMinutes,
        'p_reason': reason,
      },
    );
  }

  Future<void> banMember({
    required String roomId,
    required String userId,
    int? durationMinutes,
    String? reason,
  }) async {
    await supabase.rpc(
      'ban_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_duration_minutes': durationMinutes,
        'p_reason': reason,
      },
    );
  }

  Future<void> unbanMember({
    required String roomId,
    required String userId,
    String? reason,
  }) async {
    await supabase.rpc(
      'unban_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_reason': reason,
      },
    );
  }

  Future<void> unmuteMember({
    required String roomId,
    required String userId,
    String? reason,
  }) async {
    await supabase.rpc(
      'unmute_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_reason': reason,
      },
    );
  }

  Future<void> kickMember({
    required String roomId,
    required String userId,
    String? reason,
  }) async {
    await supabase.rpc(
      'kick_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_reason': reason,
      },
    );
  }


  Future<void> unkickMember({
    required String roomId,
    required String userId,
    String? reason,
  }) async {
    await supabase.rpc(
      'unkick_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_reason': reason,
      },
    );
  }

  Future<void> promoteMember({
    required String roomId,
    required String userId,
    required String roleId,
  }) async {
    await supabase.rpc(
      'promote_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_role_id': roleId,
      },
    );
  }

  Future<void> demoteMember({
    required String roomId,
    required String userId,
    required String roleId,
  }) async {
    await supabase.rpc(
      'demote_room_member',
      params: {
        'p_room_id': roomId,
        'p_user_id': userId,
        'p_role_id': roleId,
      },
    );
  }
}
