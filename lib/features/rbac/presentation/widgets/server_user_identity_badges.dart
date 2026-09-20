import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Canonical server-authoritative user identity used by chat/profile surfaces.
/// The optional roomId is required whenever a room-specific role/priority is
/// expected. The server remains the only authority for role/rank/permissions.
typedef ServerIdentityRequest = ({String uid, String? roomId});

Future<Map<String, dynamic>> _fetchServerIdentity(
  String uid,
  String? roomId,
) async {
  final raw = await Supabase.instance.client.rpc(
    'get_user_chat_identity',
    params: <String, dynamic>{
      'p_user_id': uid,
      'p_room_id': roomId,
    },
  );
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const <String, dynamic>{};
}

final serverUserIdentityProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, uid) async {
  return _fetchServerIdentity(uid, null);
});

final serverUserIdentityInRoomProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ServerIdentityRequest>((ref, request) async {
  return _fetchServerIdentity(request.uid, request.roomId);
});

class ServerUserIdentityBadges extends ConsumerWidget {
  final String uid;
  final String? roomId;
  final double fontSize;
  final bool showAchievements;
  final bool compact;
  final bool ownerOnlyRole;
  final bool showChatBadge;

  const ServerUserIdentityBadges({
    super.key,
    required this.uid,
    this.roomId,
    this.fontSize = 10,
    this.showAchievements = false,
    this.compact = true,
    this.ownerOnlyRole = false,
    this.showChatBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = roomId == null
        ? ref.watch(serverUserIdentityProvider(uid))
        : ref.watch(
            serverUserIdentityInRoomProvider((uid: uid, roomId: roomId)));

    return async.when(
      data: (identity) => _IdentityView(
        identity: identity,
        fontSize: fontSize,
        showAchievements: showAchievements,
        compact: compact,
        ownerOnlyRole: ownerOnlyRole,
        showChatBadge: showChatBadge,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _IdentityView extends StatelessWidget {
  final Map<String, dynamic> identity;
  final double fontSize;
  final bool showAchievements;
  final bool compact;
  final bool ownerOnlyRole;
  final bool showChatBadge;

  const _IdentityView({
    required this.identity,
    required this.fontSize,
    required this.showAchievements,
    required this.compact,
    required this.ownerOnlyRole,
    required this.showChatBadge,
  });

  static const _rankVisuals = <String, (String, String, Color)>{
    'rookie': ('◉', 'مبتدئ', Color(0xFF9E9E9E)),
    'bronze': ('◆', 'برونزي', Color(0xFFCD7F32)),
    'silver': ('◆', 'فضي', Color(0xFFC0C0C0)),
    'gold': ('★', 'ذهبي', Color(0xFFFFC107)),
    'platinum': ('✦', 'بلاتيني', Color(0xFF80CBC4)),
    'diamond': ('◇', 'ماسي', Color(0xFF7DD3FC)),
    'legend': ('♛', 'أسطورة', Color(0xFFFF8A65)),
  };

  static const _achievementLabels = <String, String>{
    'verified_email': 'موثّق',
    'first_gift_sent': 'أول هدية',
    'week_streak': 'أسبوع',
    'month_streak': 'شهر',
    'century_streak': '100 يوم',
    'referred_friend': 'دعا صديقًا',
    'first_chat': 'أول محادثة',
  };

  Widget _chip({
    required String icon,
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1.5 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: fontSize + 1, color: color)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = identity['role'] is Map
        ? Map<String, dynamic>.from(identity['role'] as Map)
        : const <String, dynamic>{};
    final rank = identity['rank'] is Map
        ? Map<String, dynamic>.from(identity['rank'] as Map)
        : const <String, dynamic>{};
    final badge = identity['chat_badge'] is Map
        ? Map<String, dynamic>.from(identity['chat_badge'] as Map)
        : const <String, dynamic>{};

    final roleCode = role['code']?.toString().trim() ?? 'user';
    final roleName = role['name']?.toString().trim() ?? '';
    final rolePriority = (role['priority'] as num?)?.toInt() ?? 0;
    final rankId = rank['id']?.toString().trim() ?? 'rookie';
    final rankLevel = (rank['level'] as num?)?.toInt() ?? 1;
    final rankName = rank['name']?.toString().trim() ??
        _rankVisuals[rankId]?.$2 ??
        rankId;
    final visual = _rankVisuals[rankId] ??
        ('◉', rankName, const Color(0xFF9E9E9E));
    final badgeUrl = badge['url']?.toString().trim();

    final isDragon = roleCode == 'dragon';
    // DRAGON is the platform owner identity, not a progression rank.
    // Every non-owner starts visibly at L1 and progresses server-side.
    final showRole = isDragon || (!ownerOnlyRole && roleCode != 'user' && roleCode != 'visitor');
    final showRank = !isDragon;

    final achievementRaw = identity['achievement_badges'];
    final achievements = achievementRaw is List
        ? achievementRaw
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .take(3)
            .toList()
        : const <String>[];

    if (!showRole &&
        !showRank &&
        (badgeUrl == null || badgeUrl.isEmpty) &&
        (!showAchievements || achievements.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showChatBadge && !isDragon && badgeUrl != null && badgeUrl.isNotEmpty)
          Container(
            width: compact ? 19 : 24,
            height: compact ? 19 : 24,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _TinyChatBadgeImage(url: badgeUrl),
            ),
          ),
        if (showRole)
          _chip(
            icon: roleCode == 'dragon' ? '👑' : '🛡️',
            label: roleCode == 'dragon' ? 'DRAGON' : roleName,
            color: roleCode == 'dragon'
                ? const Color(0xFFFFD54F)
                : const Color(0xFF8E7CFF),
          ),
        if (showRank)
          _chip(
            icon: visual.$1,
            label: '$rankName • L$rankLevel',
            color: visual.$3,
          ),
        if (showAchievements)
          // شارة "أول محادثة" مخفيّة عن الجميع بناءً على طلب صريح — تُستثنى
          // هنا فقط (لا تُحذف من بيانات gamification_stats.badges على
          // الخادم، فقط لا تُعرَض بصريًا)، بقية الإنجازات تظهر كما هي.
          for (final id in achievements.where((a) => a != 'first_chat'))
            _chip(
              icon: '🏅',
              label: _achievementLabels[id] ?? id,
              color: const Color(0xFF66BB6A),
            ),
        if (rolePriority >= 1000 && roleCode == 'dragon')
          const SizedBox.shrink(),
      ],
    );
  }
}


class _TinyChatBadgeImage extends StatefulWidget {
  final String url;
  const _TinyChatBadgeImage({required this.url});

  @override
  State<_TinyChatBadgeImage> createState() => _TinyChatBadgeImageState();
}

class _TinyChatBadgeImageState extends State<_TinyChatBadgeImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final pulse = 1 + math.sin(_controller.value * math.pi * 2) * .07;
        return Transform.scale(scale: pulse, child: child);
      },
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
