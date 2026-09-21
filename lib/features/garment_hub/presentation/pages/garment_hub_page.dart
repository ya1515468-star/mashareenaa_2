import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../producer_market/data/producer_market_repository.dart';

class GarmentHubPage extends StatefulWidget {
  const GarmentHubPage({super.key});

  @override
  State<GarmentHubPage> createState() => _GarmentHubPageState();
}

class _GarmentHubPageState extends State<GarmentHubPage> {
  final repo = ProducerMarketRepository.instance;

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> publishedServices = [];
  List<Map<String, dynamic>> businesses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([
        repo.garmentServiceCatalog(),
        repo.garmentPublishedServices(),
        Supabase.instance.client
            .from('garment_businesses')
            .select(
              'id,owner_uid,business_name,sector_key,description,city,is_verified,'
              'is_published,views_count,created_at,updated_at',
            )
            .eq('is_published', true)
            .order('created_at', ascending: false)
            .limit(100),
      ]);

      if (!mounted) return;
      setState(() {
        services = List<Map<String, dynamic>>.from(result[0] as List);
        publishedServices = List<Map<String, dynamic>>.from(result[1] as List);
        businesses = List<Map<String, dynamic>>.from(result[2] as List);
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'content_cut':
        return Icons.content_cut;
      case 'cut':
        return Icons.cut;
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'gesture':
        return Icons.gesture;
      case 'print':
        return Icons.print;
      case 'format_paint':
        return Icons.format_paint;
      case 'iron':
        return Icons.iron;
      case 'inventory_2':
        return Icons.inventory_2_outlined;
      case 'label':
        return Icons.label_outline;
      case 'architecture':
        return Icons.architecture;
      case 'design_services':
        return Icons.design_services_outlined;
      case 'grid_4x4':
        return Icons.grid_4x4;
      case 'handyman':
        return Icons.handyman_outlined;
      case 'texture':
        return Icons.texture;
      case 'precision_manufacturing':
        return Icons.precision_manufacturing_outlined;
      case 'layers':
        return Icons.layers_outlined;
      case 'category':
        return Icons.category_outlined;
      case 'home_repair_service':
        return Icons.home_repair_service_outlined;
      case 'factory':
        return Icons.factory_outlined;
      case 'local_shipping':
        return Icons.local_shipping_outlined;
      case 'warehouse':
        return Icons.warehouse_outlined;
      case 'storefront':
        return Icons.storefront_outlined;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.checkroom_outlined;
    }
  }

  String _sectorName(String key) {
    final found = services.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['sector_key']?.toString() == key,
          orElse: () => null,
        );
    return found?['name_ar']?.toString() ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الورش'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث من الخادم',
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 52),
                        const SizedBox(height: 10),
                        Text(
                          'تعذر تحميل بيانات الورش من الخادم.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'خدمات الألبسة',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'كل الخدمات النشطة من كتالوج الخادم تظهر هنا دون إسقاط عناصر.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: services.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.35,
                        ),
                        itemBuilder: (_, index) {
                          final service = services[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _iconFor(service['icon_key']?.toString()),
                                    size: 30,
                                    color: AppColors.gold,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    service['name_ar']?.toString() ??
                                        service['service_key']?.toString() ??
                                        'خدمة',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    service['description_ar']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'الخدمات المنشورة • ' + publishedServices.length.toString(),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (publishedServices.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'لا توجد خدمات منشورة حاليًا، لكن كتالوج الخدمات الكامل ظاهر أعلاه.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...publishedServices.map(
                          (item) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.home_repair_service_outlined),
                              ),
                              title: Text(
                                item['title']?.toString() ?? 'خدمة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                (item['business_name']?.toString() ?? '') +
                                    ' • ' +
                                    _sectorName(
                                      item['sector_key']?.toString() ?? '',
                                    ),
                              ),
                              trailing: item['price_minor_units'] == null
                                  ? null
                                  : Text(
                                      item['price_minor_units'].toString() +
                                          ' ' +
                                          (item['currency']?.toString() ?? ''),
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      Text(
                        'الورش والمعامل والمورّدون • ' +
                            businesses.length.toString(),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (businesses.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'لا توجد ورش أو معامل منشورة حاليًا.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...businesses.map(
                          (business) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.gold.withValues(alpha: .14),
                                child: const Icon(
                                  Icons.factory_outlined,
                                  color: AppColors.gold,
                                ),
                              ),
                              title: Text(
                                business['business_name']?.toString() ??
                                    'ورشة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                (business['city']?.toString() ?? '') +
                                    ' • ' +
                                    _sectorName(
                                      business['sector_key']?.toString() ?? '',
                                    ),
                              ),
                              trailing: business['is_verified'] == true
                                  ? const Icon(
                                      Icons.verified_rounded,
                                      color: AppColors.gold,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
