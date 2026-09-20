import 'package:supabase_flutter/supabase_flutter.dart';

/// يعثر على UID مالك المنصة من RBAC في Supabase.
/// لا يعتمد على بريد ثابت ولا على Supabase Cloud Functions.
class PlatformAdminLookupService {
  static String? _cachedUid;

  static Future<String?> resolveAdminUid() async {
    if (_cachedUid != null) {
      return _cachedUid;
    }

    try {
      final result = await Supabase.instance.client.rpc(
        'get_platform_admin_uid',
      );

      if (result == null) {
        return null;
      }

      final uid = result.toString();

      if (uid.isEmpty) {
        return null;
      }

      _cachedUid = uid;
      return uid;
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
