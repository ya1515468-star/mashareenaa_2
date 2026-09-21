import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/ambient_gif_world.dart';
import '../../../admin/presentation/pages/admin_dashboard_page.dart';
import '../../../garment_hub/presentation/pages/garment_hub_page.dart';
import '../../../gamification/presentation/pages/points_store_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../pattern_studio/presentation/pages/submit_pattern_request_page.dart';
import '../../../producer_market/presentation/pages/procurement_hub_page.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../rbac/presentation/providers/rbac_provider.dart';
import '../../../rbac/presentation/widgets/permission_gate.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';
import '../widgets/quick_link_card.dart';

/// الشاشة الرئيسية: تحية بالاسم (بتأثيره)، ملخص الرتبة/الصلاحية،
/// وروابط سريعة لكل الوحدات المتاحة حاليًا. أي وحدة جديدة (Feed،
/// Categories، Notifications، Search...) تُضاف كبطاقة هنا فور بنائها.
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final roleAsync = ref.watch(currentUserRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاريعنا'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SearchPage()));
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final unread =
                  ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const NotificationsPage()));
                },
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 178,
              child: AmbientGifWorld(
                asset: 'assets/store_gifs/background/background_50.gif',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Color(0xE3140B22), Color(0xB3090713)],
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: profileAsync.when(
                    data: (profile) {
                      if (profile == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('أهلًا بعودتك،',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          ServerUsernameDisplay(uid: profile.uid, fallbackName: profile.displayName, fallbackFontSize: 24),
                          const SizedBox(height: 6),
                          roleAsync.when(
                            data: (role) => role == null
                                ? const SizedBox.shrink()
                                : Chip(label: Text(role.name)),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('الوصول السريع',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                QuickLinkCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'المحفظة',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletPage())),
                ),
                QuickLinkCard(
                  icon: Icons.factory_outlined,
                  label: 'الورش',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GarmentHubPage())),
                ),
                QuickLinkCard(
                  icon: Icons.checkroom_outlined,
                  label: 'استوديو الباترون',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SubmitPatternRequestPage())),
                ),
                QuickLinkCard(
                  icon: Icons.shopping_bag_outlined,
                  label: 'متجر النقاط',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PointsStorePage())),
                ),
                QuickLinkCard(
                  icon: Icons.gavel_rounded,
                  label: 'المناقصات والتجارة الخارجية',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ProcurementHubPage(initialScope: 'domestic'))),
                ),
                PermissionGate(
                  permission: 'view_admin_dashboard',
                  child: QuickLinkCard(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'لوحة الإدارة',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AdminDashboardPage())),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}