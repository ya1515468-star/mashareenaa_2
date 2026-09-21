import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/monitoring/error_monitor.dart';

final _errorsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, bool>((ref, includeResolved) async {
  final rows = await Supabase.instance.client.rpc('admin_list_client_errors',
      params: {'p_include_resolved': includeResolved, 'p_limit': 200});
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _diagnosticsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client.rpc('run_system_diagnostics');
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _incidentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('platform_incidents')
      .select('id,incident_key,category,severity,status,title,summary,source,last_seen_at,occurrences,affected_users,remediation_key,remediation_status,remediation_attempts,last_remediation_at')
      .order('last_seen_at', ascending: false)
      .limit(100);
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _securityAlertsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('security_alerts')
      .select('id,alert_key,event_type,severity,user_id,risk_score_before,risk_score_after,source,evidence,state,created_at')
      .order('created_at', ascending: false)
      .limit(100);
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _securityRulesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('security_detection_rules')
      .select('rule_key,name_ar,event_type,min_occurrences,window_seconds,risk_delta,enabled,remediation_key,remediation_config,updated_at')
      .order('updated_at', ascending: false);
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

final _flagsRawProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await Supabase.instance.client
      .from('feature_flags')
      .select('flag_key,is_enabled,name_ar')
      .order('flag_key');
  return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
});

/// Owner-only: what is actually failing for real users, plus the switches to
/// disable a broken feature instantly without shipping a new build.
class ErrorMonitorPage extends ConsumerStatefulWidget {
  const ErrorMonitorPage({super.key});
  @override
  ConsumerState<ErrorMonitorPage> createState() => _ErrorMonitorPageState();
}

class _ErrorMonitorPageState extends ConsumerState<ErrorMonitorPage> {
  bool _includeResolved = false;

  /// Maps a recorded failure to a concrete, human-readable next step.
  /// Online remediation is controlled separately by explicit server-side
  /// allow-listed rules; this text is diagnostic guidance only.
  String? _suggestFix(Map<String, dynamic> e) {
    final msg = (e['message'] ?? '').toString().toLowerCase();
    final src = (e['source'] ?? '').toString().toLowerCase();
    if (msg.contains('agora_server_not_configured')) {
      return 'أسرار Agora غير مضبوطة على الخادم. اضبط AGORA_APP_ID و AGORA_APP_CERTIFICATE.';
    }
    if (msg.contains('does not exist') && msg.contains('column')) {
      return 'الاستعلام يطلب عمودًا غير موجود. صحّح اسم العمود في الاستعلام.';
    }
    if (msg.contains('permission denied')) {
      return 'صلاحية ناقصة على جدول أو دالة. راجع منح الصلاحيات لهذا المورد.';
    }
    if (msg.contains('row-level security') || msg.contains('violates row-level')) {
      return 'سياسة RLS تمنع العملية. راجع سياسة الجدول المعني.';
    }
    if (src.contains('_empty')) {
      return 'لا يوجد خطأ تقني — المصدر أعاد صفر عنصر. تحقق من وجود البيانات وتفعيلها.';
    }
    if (msg.contains('infinite width') || msg.contains('unbounded') ||
        msg.contains('infinite size')) {
      return 'ودجت حصل على عرض/ارتفاع بلا حدود. غالبًا داخل Row/Column أو '
          'Positioned بجهة واحدة. الحل: تحديد عرض أو استخدام Expanded/Flexible.';
    }
    if (msg.contains('انهيار تخطيط متسلسل')) {
      return 'هذه نتيجة لخطأ تخطيط آخر — ابحث عن أول خطأ تخطيط في القائمة وأصلحه، '
          'وستختفي هذه تلقائيًا.';
    }
    if (msg.contains('Agora') || msg.contains('AGORA')) {
      return 'أسرار Agora غير مضبوطة على الخادم: AGORA_APP_ID و AGORA_APP_CERTIFICATE.';
    }
    if (msg.contains('الملف الشخصي غير موجود') || msg.contains('PROFILE_NOT_FOUND')) {
      return 'العضو مفعّل خدمة إخفاء الملف الشخصي — هذا سلوك صحيح لا خلل.';
    }
    if (msg.contains('FEATURE_REQUIRED')) {
      return 'الميزة تتطلب خدمة VIP غير مملوكة — سلوك صحيح، لا خلل.';
    }
    if (msg.contains('FORBIDDEN')) {
      return 'الخادم رفض العملية لنقص صلاحية — تحقق أن المستخدم يملك الصلاحية فعلًا.';
    }
    return null;
  }

  String _reportText(Map<String, dynamic> e) {
    final fix = (e['suggested_fix']?.toString().trim().isNotEmpty == true)
        ? e['suggested_fix'].toString()
        : (_suggestFix(e) ?? '—');
    return '''
[${e['severity']}] ${e['category'] ?? ''}
الرسالة: ${e['message'] ?? ''}
الشاشة: ${e['screen'] ?? '—'}
المصدر: ${e['source'] ?? '—'}
المنصة: ${e['platform'] ?? '—'}   الإصدار: ${e['app_version'] ?? '—'}
التكرار: ${e['occurrences'] ?? 1}   المتأثرون: ${e['affected_users'] ?? 1}
أول ظهور: ${e['first_seen_at'] ?? '—'}
آخر ظهور: ${e['last_seen_at'] ?? '—'}
الإصلاح المقترح: $fix
--- التفاصيل التقنية ---
${e['details'] ?? '—'}
'''
        .trim();
  }

  Future<void> _copyReport(Map<String, dynamic> e) async {
    await Clipboard.setData(ClipboardData(text: _reportText(e)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('تم نسخ تقرير الخطأ ✓'),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _copyAll(List<Map<String, dynamic>> errors) async {
    final buffer = StringBuffer()
      ..writeln('تقرير أخطاء MASHAREENA — ${DateTime.now().toIso8601String()}')
      ..writeln('عدد الأخطاء: ${errors.length}')
      ..writeln('=' * 40);
    for (final e in errors) {
      buffer
        ..writeln(_reportText(e))
        ..writeln('=' * 40);
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تم نسخ ${errors.length} خطأ ✓'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _setResolved(String id, bool resolved) async {
    try {
      await Supabase.instance.client.rpc('admin_resolve_client_error',
          params: {'p_id': id, 'p_resolved': resolved});
      if (!mounted) return;
      ref.invalidate(_errorsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر التحديث: $e')));
      }
    }
  }

  Future<void> _setIncidentStatus(String id, String status) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_set_platform_incident_status',
        params: {'p_id': id, 'p_status': status},
      );
      if (!mounted) return;
      ref.invalidate(_incidentsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث حالة الحادثة إلى $status ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الحادثة: $e')),
        );
      }
    }
  }

  Future<void> _setAlertState(String id, String state) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_set_security_alert_state',
        params: {'p_id': id, 'p_state': state},
      );
      if (!mounted) return;
      ref.invalidate(_securityAlertsProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث التنبيه الأمني إلى $state ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث التنبيه: $e')),
        );
      }
    }
  }

  Future<void> _toggleFlag(String key, bool enabled) async {
    try {
      await Supabase.instance.client.rpc('admin_set_feature_flag',
          params: {'p_flag_key': key, 'p_enabled': enabled});
      if (!mounted) return;
      ref.invalidate(_flagsRawProvider);
      ref.invalidate(featureFlagsProvider);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(enabled ? 'تم تفعيل الميزة ✓' : 'تم تعطيل الميزة ✓'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذر التغيير: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorsAsync = ref.watch(_errorsProvider(_includeResolved));
    final flagsAsync = ref.watch(_flagsRawProvider);
    final incidentsAsync = ref.watch(_incidentsProvider);
    final alertsAsync = ref.watch(_securityAlertsProvider);
    final rulesAsync = ref.watch(_securityRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراقبة الأخطاء'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(_errorsProvider);
              ref.invalidate(_flagsRawProvider);
              ref.invalidate(_incidentsProvider);
              ref.invalidate(_securityAlertsProvider);
              ref.invalidate(_securityRulesProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---------------- Security control plane ----------------
          _monitoringOverview(
            incidentsAsync: incidentsAsync,
            alertsAsync: alertsAsync,
            rulesAsync: rulesAsync,
          ),

          const Divider(height: 28),

          // ---------------- Feature switches ----------------
          const Text('مفاتيح إيقاف الميزات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),

          const SizedBox(height: 6),
          flagsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('تعذر تحميل المفاتيح: $e',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            data: (flags) => Column(
              children: [
                for (final f in flags)
                  SwitchListTile(
                    value: f['is_enabled'] == true,
                    onChanged: (v) => _toggleFlag(f['flag_key'].toString(), v),
                    title: Text(
                      (f['name_ar'] ?? f['flag_key']).toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(f['flag_key'].toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    dense: true,
                  ),
              ],
            ),
          ),

          const Divider(height: 28),

          // ---------------- Proactive diagnostics ----------------
          Row(children: [
            const Expanded(
              child: Text('الفحص الذاتي للنظام',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            IconButton(
              tooltip: 'إعادة الفحص',
              onPressed: () => ref.invalidate(_diagnosticsProvider),
              icon: const Icon(Icons.play_circle_outline, size: 20),
            ),
          ]),

          const SizedBox(height: 6),
          ref.watch(_diagnosticsProvider).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(14),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  e.toString().contains('FORBIDDEN')
                      ? 'الفحص الذاتي للمالك فقط.'
                      : 'تعذر تشغيل الفحص: $e',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        Icon(Icons.verified, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('النظام سليم — لا ملاحظات.',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    );
                  }
                  final fatal =
                      rows.where((r) => r['severity'] == 'fatal').length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'النتيجة: ${rows.length} ملاحظة'
                        '${fatal > 0 ? '  •  منها $fatal حرجة' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: fatal > 0 ? Colors.redAccent : Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final r in rows.take(40))
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              r['severity'] == 'fatal'
                                  ? Icons.dangerous
                                  : Icons.warning_amber_rounded,
                              color: r['severity'] == 'fatal'
                                  ? Colors.redAccent
                                  : Colors.amber,
                              size: 20,
                            ),
                            title: Text(
                              '${r['category']} — ${r['object_name']}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${r['detail']}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white54)),
                          ),
                        ),
                    ],
                  );
                },
              ),

          const Divider(height: 28),

          // ---------------- Errors ----------------
          Row(
            children: [
              const Expanded(
                child: Text('الأخطاء المسجّلة',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              TextButton.icon(
                onPressed: () {
                  final rows = ref.read(_errorsProvider(_includeResolved)).valueOrNull;
                  if (rows != null && rows.isNotEmpty) _copyAll(rows);
                },
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('نسخ الكل', style: TextStyle(fontSize: 11)),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _includeResolved = !_includeResolved),
                icon: Icon(_includeResolved ? Icons.visibility_off : Icons.visibility, size: 16),
                label: Text(_includeResolved ? 'إخفاء المعالَجة' : 'إظهار المعالَجة',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          errorsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                e.toString().contains('FORBIDDEN')
                    ? 'هذه الشاشة للمالك فقط.'
                    : 'تعذر تحميل الأخطاء: $e',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            data: (errors) {
              if (errors.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('لا توجد أخطاء مسجّلة 🎉',
                        style: TextStyle(color: Colors.white60)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final e in errors) _errorCard(e),
                ],
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _monitoringOverview({
    required AsyncValue<List<Map<String, dynamic>>> incidentsAsync,
    required AsyncValue<List<Map<String, dynamic>>> alertsAsync,
    required AsyncValue<List<Map<String, dynamic>>> rulesAsync,
  }) {
    final incidents = incidentsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final alerts = alertsAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final rules = rulesAsync.valueOrNull ?? const <Map<String, dynamic>>[];
    final openIncidents = incidents.where((e) => e['status'] != 'resolved').length;
    final criticalAlerts = alerts.where((e) => e['severity'] == 'critical').length;
    final automaticFixes = incidents.where((e) => e['remediation_status'] == 'succeeded').length;
    final enabledRules = rules.where((e) => e['enabled'] == true).length;

    Widget metric(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withValues(alpha: .04),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مركز المراقبة الخادمي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),

            const SizedBox(height: 10),
            if (incidentsAsync.isLoading || alertsAsync.isLoading || rulesAsync.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 9),
            Row(
              children: [
                metric('حوادث مفتوحة', '$openIncidents', Icons.error_outline_rounded),
                const SizedBox(width: 7),
                metric('تنبيهات حرجة', '$criticalAlerts', Icons.gpp_bad_outlined),
                const SizedBox(width: 7),
                metric('إصلاحات آمنة', '$automaticFixes', Icons.auto_fix_high_rounded),
                const SizedBox(width: 7),
                metric('قواعد مفعّلة', '$enabledRules', Icons.rule_folder_outlined),
              ],
            ),
            const SizedBox(height: 12),
            if (incidents.isNotEmpty) ...[
              const Text('آخر الحوادث', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final e in incidents.take(8))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e['severity'] == 'critical' || e['severity'] == 'fatal'
                        ? Icons.dangerous_outlined
                        : Icons.warning_amber_rounded,
                    color: e['severity'] == 'critical' || e['severity'] == 'fatal'
                        ? Colors.redAccent
                        : Colors.amber,
                    size: 20,
                  ),
                  title: Text(
                    e['title']?.toString() ?? e['incident_key'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${e['category']} • ${e['status']} • تكرار ${e['occurrences'] ?? 1} • إصلاح: ${e['remediation_status'] ?? '—'}',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'تغيير الحالة',
                    onSelected: (status) => _setIncidentStatus(e['id'].toString(), status),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('مفتوحة')),
                      PopupMenuItem(value: 'acknowledged', child: Text('تم الاستلام')),
                      PopupMenuItem(value: 'mitigated', child: Text('تم الاحتواء')),
                      PopupMenuItem(value: 'resolved', child: Text('تم الحل')),
                    ],
                  ),
                ),
            ] else if (!incidentsAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا توجد حوادث مُجمّعة في مركز المراقبة.', style: TextStyle(fontSize: 10.5, color: Colors.white54)),
              ),
            if (alerts.isNotEmpty) ...[
              const Divider(height: 18),
              const Text('آخر التنبيهات الأمنية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              for (final a in alerts.take(6))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    a['severity'] == 'critical' ? Icons.shield_outlined : Icons.security_outlined,
                    color: a['severity'] == 'critical' ? Colors.redAccent : Colors.orangeAccent,
                    size: 19,
                  ),
                  title: Text(a['event_type']?.toString() ?? 'security', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    'الخطورة ${a['severity']} • المخاطر ${a['risk_score_before'] ?? 0} → ${a['risk_score_after'] ?? 0} • ${a['state']}',
                    style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'إدارة التنبيه',
                    onSelected: (state) => _setAlertState(a['id'].toString(), state),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'reviewed', child: Text('تمت المراجعة')),
                      PopupMenuItem(value: 'contained', child: Text('تم الاحتواء')),
                      PopupMenuItem(value: 'resolved', child: Text('تم الحل')),
                      PopupMenuItem(value: 'false_positive', child: Text('إنذار كاذب')),
                    ],
                  ),
                ),
            ],
            if (rules.isNotEmpty) ...[
              const Divider(height: 18),
              Text(
                'قواعد الكشف المفعّلة: $enabledRules / ${rules.length}',
                style: const TextStyle(fontSize: 10.5, color: Colors.white60),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorCard(Map<String, dynamic> e) {
    final severity = (e['severity'] ?? 'error').toString();
    final resolved = e['resolved'] == true;
    final color = switch (severity) {
      'fatal' => Colors.red,
      'error' => Colors.orangeAccent,
      'warning' => Colors.amber,
      _ => Colors.blueAccent,
    };
    final fix = (e['suggested_fix']?.toString().trim().isNotEmpty == true)
        ? e['suggested_fix'].toString()
        : _suggestFix(e);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color),
                  ),
                  child: Text(severity,
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('×${e['occurrences'] ?? 1}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                if (resolved)
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
              ],
            ),
            const SizedBox(height: 6),
            Text(e['message']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'المستخدم: ${(e['last_user_display_name'] ?? e['last_user_username'] ?? 'غير معروف').toString()}'
              '  •  ${e['last_user_username'] != null ? '@${e['last_user_username']}' : ''}'
              '  •  الشاشة: ${e['screen'] ?? '—'}  •  المصدر: ${e['source'] ?? '—'}  •  '
              '${e['platform'] ?? '—'}  •  مستخدمون: ${e['affected_users'] ?? 1}',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
            Text('آخر ظهور: ${e['last_seen_at'] ?? '—'}',
                style: const TextStyle(fontSize: 10, color: Colors.white38)),
            if (fix != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 15, color: Colors.lightBlueAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('الإصلاح المقترح: $fix',
                          style: const TextStyle(fontSize: 11, color: Colors.lightBlueAccent)),
                    ),
                  ],
                ),
              ),
            ],
            if ((e['details']?.toString().trim().isNotEmpty ?? false))
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('التفاصيل التقنية',
                      style: TextStyle(fontSize: 11, color: Colors.white54)),
                  children: [
                    SelectableText(
                      e['details'].toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: () => _setResolved(e['id'].toString(), !resolved),
                  child: Text(resolved ? 'إعادة فتح' : 'تحديد كمُعالَج',
                      style: const TextStyle(fontSize: 11)),
                ),
                const Spacer(),
                // Copies the FULL report (message + screen + source + counts +
                // stack trace) as one block, so it can be pasted somewhere
                // useful instead of being retyped from a screenshot.
                TextButton.icon(
                  onPressed: () => _copyReport(e),
                  icon: const Icon(Icons.copy_all, size: 15),
                  label: const Text('نسخ الخطأ', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
