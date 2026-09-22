import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';
import '../../../rbac/domain/usecases/assign_role_usecase.dart';
import '../../../search/presentation/providers/search_provider.dart';
import '../../../subscriptions/domain/entities/subscription_tier_entity.dart';
import '../../../subscriptions/domain/usecases/grant_membership_feature_usecase.dart';
import '../../domain/usecases/set_account_status_usecase.dart';

class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(profileSearchResultsProvider(_query));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم المستخدم لإدارة دوره أو حالته...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? const Center(child: Text('اكتب اسمًا للبحث'))
              : resultsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
                  data: (profiles) {
                    if (profiles.isEmpty) {
                      return const Center(child: Text('لا نتائج'));
                    }
                    return ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return ExpansionTile(
                          title: ServerUsernameDisplay(
                            uid: profile.uid,
                            fallbackName: profile.displayName,
                            fallbackFontSize: 16,
                          ),
                          subtitle: Text(profile.email),
                          children: [
                            FutureBuilder<Map<String, dynamic>>(
                              future: Supabase.instance.client
                                  .rpc('admin_get_user_details', params: {'p_user_id': profile.uid})
                                  .then((value) => Map<String, dynamic>.from(value as Map)),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: LinearProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError || !snapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('تعذر تحميل بيانات الهوية الحالية للمستخدم'),
                                  );
                                }
                                final d = snapshot.data!;
                                final address = d['address']?.toString().trim() ?? '';
                                final city = d['city']?.toString().trim() ?? '';
                                final country = d['country']?.toString().trim() ?? '';
                                final ip = d['last_ip']?.toString().trim() ?? '';
                                final lat = d['latitude']?.toString().trim() ?? '';
                                final lon = d['longitude']?.toString().trim() ?? '';
                                return Card(
                                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('عنوان المستخدم: ${address.isEmpty ? 'غير مسجل' : address}',
                                            style: const TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 4),
                                        Text('الموقع: ${country.isEmpty ? '—' : country} / ${city.isEmpty ? '—' : city}'),
                                        const SizedBox(height: 4),
                                        Text('IP: ${ip.isEmpty ? 'غير متاح' : ip}'),
                                        if (lat.isNotEmpty || lon.isNotEmpty)
                                          Text('الإحداثيات: ${lat.isEmpty ? '—' : lat} , ${lon.isEmpty ? '—' : lon}'),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                                  FutureBuilder<bool>(
                                    future: Supabase.instance.client.rpc(
                                      'admin_get_platform_service_access',
                                      params: {
                                        'p_user_id': profile.uid,
                                        'p_service_key': 'garment_service_ads',
                                      },
                                    ),
                                    builder: (context, accessSnapshot) {
                                      final active = accessSnapshot.data == true;
                                      return Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          onPressed: myUid == null
                                              ? null
                                              : () async {
                                                  try {
                                                    await Supabase.instance
                                                        .client
                                                        .rpc(
                                                      'admin_set_platform_service_access',
                                                      params: {
                                                        'p_user_id': profile.uid,
                                                        'p_service_key':
                                                            'garment_service_ads',
                                                        'p_is_active': !active,
                                                      },
                                                    );
                                                    if (!context.mounted) return;
                                                    setState(() {});
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          active
                                                              ? 'تم سحب صلاحية سوق الألبسة'
                                                              : 'تم منح صلاحية سوق الألبسة',
                                                        ),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text('تعذر تغيير الصلاحية: $e'),
                                                      ),
                                                    );
                                                  }
                                                },
                                          icon: Icon(
                                            active
                                                ? Icons.lock_open_rounded
                                                : Icons.lock_outline_rounded,
                                          ),
                                          label: Text(
                                            active
                                                ? 'سوق الألبسة • مفعل'
                                                : 'سوق الألبسة • غير مفعل',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: AppRoles.all.map((roleId) {
                                      return OutlinedButton(
                                        onPressed: myUid == null
                                            ? null
                                            : () async {
                                                final useCase =
                                                    sl<AssignRoleUseCase>();
                                                final result = await useCase(
                                                  AssignRoleParams(
                                                    targetUid: profile.uid,
                                                    roleId: roleId,
                                                    requestedByUid: myUid,
                                                  ),
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      result.isRight()
                                                          ? 'تم إسناد الدور: $roleId'
                                                          : 'فشل: صلاحية غير كافية',
                                                    ),
                                                  ),
                                                );
                                              },
                                        child: Text(roleId,
                                            style:
                                                const TextStyle(fontSize: 11)),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: myUid == null
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  myUid,
                                                  profile.uid,
                                                  AccountStatus.active),
                                          child: const Text('تفعيل'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: myUid == null
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  myUid,
                                                  profile.uid,
                                                  AccountStatus.suspended),
                                          child: const Text('إيقاف'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: myUid == null
                                              ? null
                                              : () => _setStatus(
                                                  context,
                                                  myUid,
                                                  profile.uid,
                                                  AccountStatus.banned),
                                          child: const Text('حظر'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'منح مزايا عضوية خاصة (DRAGON فقط)',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        MembershipFeatureKeys.all.map((key) {
                                      return OutlinedButton(
                                        onPressed: myUid == null
                                            ? null
                                            : () async {
                                                final useCase = sl<
                                                    GrantMembershipFeatureUseCase>();
                                                final result = await useCase(
                                                  targetUid: profile.uid,
                                                  featureKey: key,
                                                  enabled: true,
                                                  requestedByUid: myUid,
                                                );
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      result.isRight()
                                                          ? 'تم منح: $key'
                                                          : 'فشل: صلاحية غير كافية',
                                                    ),
                                                  ),
                                                );
                                              },
                                        child: Text(key,
                                            style: const TextStyle(
                                                fontSize: 10.5)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _setStatus(BuildContext context, String myUid, String targetUid,
      AccountStatus status) async {
    final useCase = sl<SetAccountStatusUseCase>();
    final result = await useCase(
        targetUid: targetUid, status: status, requestedByUid: myUid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              result.isRight() ? 'تم تحديث الحالة' : 'فشل: صلاحية غير كافية')),
    );
  }
}
