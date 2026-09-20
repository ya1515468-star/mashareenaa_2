import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/garment_business_profile_entity.dart';
import '../../../chat/presentation/widgets/mini_chat_overlay.dart';

/// ConsumerWidget بدل StatelessWidget للوصول إلى ref، اللازم لفتح المراسلة
/// كنافذة عائمة (المسار الوحيد المعتمد للمحادثات الخاصة في التطبيق).
class GarmentBusinessDetailsPage extends ConsumerWidget {
  final GarmentBusinessProfileEntity business;
  final String? currentUid;

  const GarmentBusinessDetailsPage({
    super.key,
    required this.business,
    this.currentUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(business.businessName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(business: business),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'عن النشاط',
              child: Text(
                business.description.isEmpty
                    ? 'لا يوجد وصف مضاف'
                    : business.description,
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'نوع النشاط',
              child: Chip(
                label: Text(business.businessType.label),
              ),
            ),
            const SizedBox(height: 12),
            if (business.specialties.isNotEmpty)
              _SectionCard(
                title: 'التخصصات',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: business.specialties
                      .map(
                        (item) => Chip(
                          label: Text(item),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'القدرة الإنتاجية',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الطاقة الشهرية: ${business.monthlyCapacity}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'الحد الأدنى للطلب: ${business.minOrderQuantity}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'الموقع والتواصل',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (business.city != null)
                    Text(
                      'المدينة: ${business.city}',
                    ),
                  if (business.country != null)
                    Text(
                      'الدولة: ${business.country}',
                    ),
                  if (business.contactPhone != null)
                    Text(
                      'الهاتف: ${business.contactPhone}',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (currentUid != null && currentUid != business.uid)
              ElevatedButton.icon(
                icon: const Icon(Icons.chat_outlined),
                label: const Text('مراسلة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                ),
                onPressed: () {
                  openPrivateChat(
                    context,
                    ref,
                    threadId: _threadId(currentUid!, business.uid),
                    peerUid: business.uid,
                    peerName: business.businessName,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _threadId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

class _HeaderCard extends StatelessWidget {
  final GarmentBusinessProfileEntity business;

  const _HeaderCard({
    required this.business,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 35,
              child: Icon(
                Icons.factory_outlined,
                size: 40,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              business.businessName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              business.businessType.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
