import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';

final storePurchasesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, userId) async {
  final rows = await Supabase.instance.client
      .rpc('get_store_purchases', params: {'p_user_id': userId});
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final purchasesVisibilityProvider = FutureProvider.autoDispose<String>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return 'nobody';
  final row = await Supabase.instance.client
      .from('profiles')
      .select('purchases_visibility')
      .eq('id', uid)
      .maybeSingle();
  return row?['purchases_visibility']?.toString() ?? 'nobody';
});

/// "مشتريات المتجر" — one place showing everything the member bought, with a
/// switch beside each item so a service can be turned off without going back
/// into the store and hunting for it.
///
/// [userId] null means "my own purchases". Passing another id is only allowed
/// by the server when that member made them visible, or when the viewer is the
/// platform owner (or an account the owner granted).
class StorePurchasesTab extends ConsumerWidget {
  final String? userId;
  const StorePurchasesTab({super.key, this.userId});

  bool get _isSelf => userId == null;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    bool enable,
  ) async {
    final kind = item['kind']?.toString();
    final key = item['item_key']?.toString() ?? '';
    try {
      final sb = Supabase.instance.client;
      if (kind == 'vip_service') {
        await sb.rpc('set_profile_service_enabled',
            params: {'p_feature_key': key, 'p_enabled': enable});
      } else if (kind == 'name_animal') {
        await sb.rpc('set_name_animation',
            params: {'p_effect_key': enable ? key : ''});
      }
      ref.invalidate(storePurchasesProvider(userId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enable ? 'تم التفعيل ✓' : 'تم الإيقاف ✓'),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التغيير: $e')));
    }
  }

  Future<void> _setVisibility(BuildContext context, WidgetRef ref, String v) async {
    try {
      await Supabase.instance.client
          .rpc('set_my_purchases_visibility', params: {'p_visibility': v});
      ref.invalidate(purchasesVisibilityProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم تحديث خصوصية المشتريات ✓'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر التحديث: $e')));
    }
  }

  IconData _iconFor(String kind) => switch (kind) {
        'vip_service' => Icons.workspace_premium,
        'name_animal' => Icons.pets,
        _ => Icons.category_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(storePurchasesProvider(userId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final msg = e.toString();
        final hidden = msg.contains('PURCHASES_HIDDEN');
        final friendsOnly = msg.contains('PURCHASES_FRIENDS_ONLY');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 34, color: AppColors.textMuted),
                const SizedBox(height: 10),
                Text(
                  hidden
                      ? 'هذا العضو يُخفي مشترياته.'
                      : friendsOnly
                          ? 'المشتريات متاحة للأصدقاء فقط.'
                          : 'تعذر تحميل المشتريات.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
      data: (items) {
        // Group by category so the list reads as sections rather than a wall.
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final it in items) {
          grouped.putIfAbsent(it['category']?.toString() ?? '—', () => []).add(it);
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_isSelf) _visibilityCard(context, ref),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: Text('لا توجد مشتريات بعد.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                child: Row(children: [
                  Container(width: 18, height: 1.6, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: AppColors.gold)),
                  const SizedBox(width: 8),
                  Text('(${entry.value.length})',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final it in entry.value) _row(context, ref, it),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _visibilityCard(BuildContext context, WidgetRef ref) {
    final vis = ref.watch(purchasesVisibilityProvider).valueOrNull ?? 'nobody';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('من يرى مشترياتك؟',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'مشترياتك تكشف إنفاقك، لذلك تبدأ مخفية عن الجميع. إدارة المنصة تراها دائمًا.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'public', label: Text('الجميع', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'friends', label: Text('الأصدقاء', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'nobody', label: Text('لا أحد', style: TextStyle(fontSize: 11))),
              ],
              selected: {vis},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _setVisibility(context, ref, s.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Map<String, dynamic> it) {
    final canToggle = it['can_toggle'] == true && _isSelf;
    final enabled = it['is_enabled'] == true;
    final kind = it['kind']?.toString() ?? '';
    final acquired = it['acquired_at']?.toString();

    return ListTile(
      dense: true,
      leading: Icon(_iconFor(kind),
          size: 20, color: enabled ? AppColors.gold : AppColors.textMuted),
      title: Text(it['name_ar']?.toString() ?? it['item_key']?.toString() ?? '',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      subtitle: Text(
        acquired == null || acquired.isEmpty
            ? (enabled ? 'مُفعّل' : 'موقوف')
            : '${enabled ? 'مُفعّل' : 'موقوف'} • مُنذ ${acquired.split('T').first}',
        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
      ),
      trailing: canToggle
          ? Switch(
              value: enabled,
              onChanged: (v) => _toggle(context, ref, it, v),
            )
          // Cosmetics are owned permanently and are switched by choosing them,
          // so a toggle here would be misleading.
          : Icon(enabled ? Icons.check_circle : Icons.remove_circle_outline,
              size: 18,
              color: enabled ? AppColors.success : AppColors.textMuted),
    );
  }
}
