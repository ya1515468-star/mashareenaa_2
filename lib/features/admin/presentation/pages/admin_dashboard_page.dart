import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../pattern_studio/presentation/pages/admin_pattern_studio_tab.dart';
import '../../../rbac/presentation/widgets/permission_gate.dart';
import 'admin_audit_log_tab.dart';
import 'admin_broadcast_tab.dart';
import 'admin_feedback_tab.dart';
import 'admin_reports_tab.dart';
import 'admin_roles_tab.dart';
import 'admin_store_tab.dart';
import 'admin_users_tab.dart';
import 'admin_virtual_presence_tab.dart';
import 'admin_platform_requests_tab.dart';
import 'profile_cosmetic_admin_tab.dart';
import '../../../producer_market/presentation/pages/producer_market_admin_page.dart';
import 'admin_login_announcement_tab.dart';
import 'admin_chat_badges_tab.dart';
import 'admin_user_titles_tab.dart';
import 'name_animation_admin_tab.dart';
import 'dragon_control_tab.dart';

/// لوحة الإدارة — يجب ألا يصل إليها المستخدم إطلاقًا إلا عبر
/// [PermissionGate] الذي يغلّف زر الوصول إليها (انظر HomeDashboardPage)؛
/// وهنا أيضًا حماية مضاعفة على مستوى الشاشة نفسها في حال تم فتحها
/// بأي طريق آخر (رابط مباشر مثلًا).
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      permission: 'view_admin_dashboard',
      fallback: const Scaffold(
        body: Center(
          child: Text('لا تملك صلاحية الوصول إلى لوحة الإدارة',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
      child: DefaultTabController(
        length: 17,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('لوحة الإدارة'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'البلاغات'),
                Tab(text: 'المستخدمون'),
                Tab(text: 'الأدوار والصلاحيات'),
                Tab(text: 'سجل التدقيق'),
                Tab(text: 'استوديو الباترون'),
                Tab(text: 'بث DRAGON'),
                Tab(text: 'اقتراحات الأعضاء'),
                Tab(text: 'متجر الميزات'),
                Tab(text: 'DRAGON / Platform Owner'),
                Tab(text: 'الحضور الافتراضي'),
                Tab(text: 'طلبات الأفكار والبث'),
                Tab(text: 'متجر الشات والأسعار'),
                Tab(text: 'إعلانات تسجيل الدخول'),
                Tab(text: 'شارة العضو'),
                Tab(text: 'ألقاب المستخدمين'),
                Tab(text: 'حيوانات فوق الاسم'),
                Tab(icon: Icon(Icons.home_repair_service_outlined), text: 'إدارة الورش'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              AdminReportsTab(),
              AdminUsersTab(),
              AdminRolesTab(),
              AdminAuditLogTab(),
              AdminPatternStudioTab(),
              AdminBroadcastTab(),
              AdminFeedbackTab(),
              AdminStoreTab(),
              DragonControlTab(),
              AdminVirtualPresenceTab(),
              AdminPlatformRequestsTab(),
              ProfileCosmeticAdminTab(),
              AdminLoginAnnouncementTab(),
              AdminChatBadgesTab(),
              AdminUserTitlesTab(),
              NameAnimationAdminTab(),
              ProducerMarketAdminPage(),
            ],
          ),
        ),
      ),
    );
  }
}