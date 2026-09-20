import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/providers/report_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportsTab extends ConsumerWidget {
  const AdminReportsTab({super.key});

  String _targetLabel(ReportTargetType type) {
    switch (type) {
      case ReportTargetType.post:
        return 'منشور';
      case ReportTargetType.comment:
        return 'تعليق';
      case ReportTargetType.user:
        return 'مستخدم';
      case ReportTargetType.chatMessage:
        return 'رسالة';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(allReportsProvider(ReportStatus.pending));
    final myUid = ref.watch(authControllerProvider).valueOrNull?.uid;

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('تعذر تحميل البيانات الآن. تحقق من الاتصال ثم أعد المحاولة.')),
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(
            child: Text('لا توجد بلاغات قيد المراجعة',
                style: TextStyle(color: AppColors.textSecondary)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(_targetLabel(report.targetType))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('المعرّف: ${report.targetId}',
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(report.reason),
                    if (report.evidenceUrl != null &&
                        report.evidenceUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          report.evidenceUrl!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: myUid == null
                              ? null
                              : () => ref
                                  .read(reportControllerProvider.notifier)
                                  .resolveReport(
                                    reportId: report.id,
                                    newStatus: ReportStatus.dismissed,
                                    resolvedBy: myUid,
                                  ),
                          child: const Text('تجاهل'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: myUid == null
                              ? null
                              : () => ref
                                  .read(reportControllerProvider.notifier)
                                  .resolveReport(
                                    reportId: report.id,
                                    newStatus: ReportStatus.resolved,
                                    resolvedBy: myUid,
                                  ),
                          child: const Text('معالجة'),
                        ),
                        if (report.targetType == ReportTargetType.user) ...[
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: myUid == null
                                ? null
                                : () async {
                                    final title = TextEditingController(
                                        text: 'تحذير أمان');
                                    final details = TextEditingController(
                                        text: report.reason);
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('نشر تحذير أمان'),
                                        content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                  controller: title,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText:
                                                              'العنوان')),
                                              TextField(
                                                  controller: details,
                                                  maxLines: 4,
                                                  decoration:
                                                      const InputDecoration(
                                                          labelText:
                                                              'التفاصيل')),
                                            ]),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, false),
                                              child: const Text('إلغاء')),
                                          FilledButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, true),
                                              child: const Text('نشر')),
                                        ],
                                      ),
                                    );
                                    if (ok != true) {
                                      title.dispose();
                                      details.dispose();
                                      return;
                                    }
                                    try {
                                      await Supabase.instance.client.rpc(
                                          'publish_platform_safety_warning',
                                          params: {
                                            'p_target_user_id': report.targetId,
                                            'p_title': title.text.trim(),
                                            'p_details': details.text.trim(),
                                            'p_evidence_url':
                                                report.evidenceUrl,
                                            'p_source_report_id': report.id,
                                          });
                                    } finally {
                                      title.dispose();
                                      details.dispose();
                                    }
                                  },
                            icon: const Icon(Icons.publish_rounded),
                            label: const Text('نشر التحذير'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
