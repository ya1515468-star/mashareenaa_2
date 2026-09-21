import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/media_upload_service.dart';
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
  bool canPublish = false;
  String? error;
  Map<String, dynamic> serviceFee = const {};
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> publishedServices = [];
  List<Map<String, dynamic>> businesses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    List<Map<String, dynamic>> nextServices = const [];
    List<Map<String, dynamic>> nextPublishedServices = const [];
    List<Map<String, dynamic>> nextBusinesses = const [];
    final failures = <Object>[];

    // Each section talks to the canonical production RPC independently.
    // One failed endpoint must not hide valid data returned by the others.
    try {
      nextServices = await repo.garmentServiceCatalog();
    } catch (e) {
      failures.add(e);
    }

    try {
      nextPublishedServices = await repo.garmentPublishedServices();
    } catch (e) {
      failures.add(e);
    }

    try {
      nextBusinesses = await repo.garmentDirectory(limit: 100);
    } catch (e) {
      failures.add(e);
    }

    var nextCanPublish = false;
    try {
      nextCanPublish = await Supabase.instance.client.rpc(
            'has_platform_service_access',
            params: {'p_service_key': 'garment_service_ads'},
          ) ==
          true;
    } catch (_) {}

    Map<String, dynamic> nextFee = const {};
    try {
      final fees = await repo.garmentPublicationFees();
      nextFee = fees.firstWhere(
        (row) => row['content_type']?.toString() == 'garment_service',
        orElse: () => <String, dynamic>{},
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      services = nextServices;
      publishedServices = nextPublishedServices;
      businesses = nextBusinesses;
      canPublish = nextCanPublish;
      serviceFee = nextFee;
      error = failures.length == 3 ? 'تعذر تحميل البيانات من الخادم.' : null;
      loading = false;
    });
  }


  Future<void> _openPublishDialog() async {
    if (!canPublish || services.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final serviceKeys = services
        .map((row) => row['service_key']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
    var selectedService = serviceKeys.first;
    var selectedCurrency = 'points';
    final title = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final unit = TextEditingController();
    final minQty = TextEditingController();
    final city = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController();
    final whatsapp = TextEditingController();
    final specs = TextEditingController();
    var images = <PlatformFile>[];
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          final selectedRow = services.firstWhere(
            (row) => row['service_key']?.toString() == selectedService,
            orElse: () => services.first,
          );
          final pointsFee =
              (serviceFee['points_cost'] as num?)?.toInt() ?? 0;
          final gemsFee = (serviceFee['gems_cost'] as num?)?.toInt() ?? 0;
          final currentFee =
              selectedCurrency == 'points' ? pointsFee : gemsFee;

          Future<void> pickImages() async {
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
              allowMultiple: true,
              withData: true,
            );
            if (result != null) {
              setDialog(() => images = result.files.take(8).toList());
            }
          }

          Future<void> publish() async {
            final cleanTitle = title.text.trim();
            if (busy || cleanTitle.isEmpty) return;
            setDialog(() => busy = true);
            final uploaded = <String>[];
            try {
              for (final file in images) {
                uploaded.add(
                  await MediaUploadService(bucket: 'garment-service-media')
                      .uploadFile(file: file.xFile, folder: uid, uid: uid),
                );
              }
              final specMap = <String, dynamic>{};
              for (final line in specs.text.split('\n')) {
                final i = line.indexOf('=');
                if (i <= 0) continue;
                final key = line.substring(0, i).trim();
                final value = line.substring(i + 1).trim();
                if (key.isNotEmpty && value.isNotEmpty) specMap[key] = value;
              }
              final result = await Supabase.instance.client.rpc(
                'publish_garment_service_ad',
                params: {
                  'p_service_key': selectedService,
                  'p_sector_key': selectedRow['sector_key']?.toString() ?? '',
                  'p_title': cleanTitle,
                  'p_description': description.text.trim(),
                  'p_price_minor_units': int.tryParse(price.text.trim()),
                  'p_currency': 'sham_cash',
                  'p_unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
                  'p_min_qty': int.tryParse(minQty.text.trim()),
                  'p_city': city.text.trim().isEmpty ? null : city.text.trim(),
                  'p_address':
                      address.text.trim().isEmpty ? null : address.text.trim(),
                  'p_phone':
                      phone.text.trim().isEmpty ? null : phone.text.trim(),
                  'p_whatsapp': whatsapp.text.trim().isEmpty
                      ? null
                      : whatsapp.text.trim(),
                  'p_images': uploaded,
                  'p_specs': specMap,
                  'p_publication_currency': selectedCurrency,
                  'p_request_id': const Uuid().v4(),
                },
              );
              if (result is Map && result['ok'] == true) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              }
            } catch (e) {
              for (final url in uploaded) {
                try {
                  await MediaUploadService(bucket: 'garment-service-media')
                      .deleteFile(url);
                } catch (_) {}
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('فشل نشر الإعلان: $e')),
                );
              }
            } finally {
              if (dialogContext.mounted) setDialog(() => busy = false);
            }
          }

          return AlertDialog(
            title: const Text('إضافة إعلان خدمة ألبسة'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedService,
                      decoration: const InputDecoration(labelText: 'الخدمة'),
                      items: [
                        for (final row in services)
                          DropdownMenuItem<String>(
                            value: row['service_key']?.toString(),
                            child: Text(
                              row['name_ar']?.toString() ??
                                  row['service_key']?.toString() ??
                                  '',
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialog(() => selectedService = value);
                              }
                            },
                    ),
                    TextField(
                      controller: title,
                      decoration:
                          const InputDecoration(labelText: 'عنوان الإعلان'),
                    ),
                    TextField(
                      controller: description,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: price,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'السعر'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: unit,
                            decoration:
                                const InputDecoration(labelText: 'الوحدة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: minQty,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'أقل كمية'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: city,
                            decoration:
                                const InputDecoration(labelText: 'المدينة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: address,
                            decoration:
                                const InputDecoration(labelText: 'العنوان'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'الهاتف'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: whatsapp,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'واتساب'),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: specs,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'المواصفات'),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'points',
                          label: Text('نقاط'),
                          icon: Icon(Icons.star_rounded),
                        ),
                        ButtonSegment(
                          value: 'gems',
                          label: Text('جواهر'),
                          icon: Icon(Icons.diamond_rounded),
                        ),
                      ],
                      selected: {selectedCurrency},
                      onSelectionChanged: busy
                          ? null
                          : (value) =>
                              setDialog(() => selectedCurrency = value.first),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'رسوم النشر: $currentFee',
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : pickImages,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          images.isEmpty
                              ? 'إضافة صور'
                              : 'الصور المضافة: ${images.length}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : publish,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: const Text('نشر'),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    description.dispose();
    price.dispose();
    unit.dispose();
    minQty.dispose();
    city.dispose();
    address.dispose();
    phone.dispose();
    whatsapp.dispose();
    specs.dispose();
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
        title: const Text('خدمات الألبسة'),
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
                        'الخدمات',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                         'الخدمات المنشورة • ${publishedServices.length}',
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
                                '${item['business_name']?.toString() ?? ''} • ${_sectorName(item['sector_key']?.toString() ?? '')}',
                              ),
                              trailing: item['price_minor_units'] == null
                                  ? null
                                  : Text(
                                      '${item['price_minor_units']} ${item['currency']?.toString() ?? ''}',
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
                        'الورش والمعامل والمورّدون • ${businesses.length}',
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
                                '${business['city']?.toString() ?? ''} • ${_sectorName(business['sector_key']?.toString() ?? '')}',
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
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: _openPublishDialog,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('إضافة إعلان'),
            )
          : null,
    );
  }
}
