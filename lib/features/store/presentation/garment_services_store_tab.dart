import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../producer_market/data/producer_market_repository.dart';

/// Server-driven garment services inside the store.
///
/// The client only collects input. Catalog, publication fees, business
/// ownership, publication state, limits and wallet charging are enforced by
/// Supabase RPCs.
class GarmentServicesStoreTab extends StatefulWidget {
  final bool owner;

  const GarmentServicesStoreTab({super.key, this.owner = false});

  @override
  State<GarmentServicesStoreTab> createState() => _GarmentServicesStoreTabState();
}

class _GarmentServicesStoreTabState extends State<GarmentServicesStoreTab> {
  final repo = ProducerMarketRepository.instance;
  final searchController = TextEditingController();

  List<Map<String, dynamic>> catalog = const [];
  List<Map<String, dynamic>> services = const [];
  List<Map<String, dynamic>> businesses = const [];
  List<Map<String, dynamic>> fees = const [];
  List<Map<String, dynamic>> ads = const [];
  String? selectedSector;
  String publicationCurrency = 'points';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final result = await Future.wait([
        repo.garmentServiceCatalog(),
        repo.garmentPublishedServices(sectorKey: selectedSector),
        repo.myGarmentBusinesses(),
        repo.garmentPublicationFees(),
        repo.garmentServiceAds(sectorKey: selectedSector),
      ]);
      if (!mounted) return;
      setState(() {
        catalog = List<Map<String, dynamic>>.from(result[0] as List);
        services = List<Map<String, dynamic>>.from(result[1] as List);
        businesses = List<Map<String, dynamic>>.from(result[2] as List);
        fees = List<Map<String, dynamic>>.from(result[3] as List);
        ads = List<Map<String, dynamic>>.from(result[4] as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _snack(_friendly(e));
    }
  }

  Map<String, dynamic>? _feeFor(String contentType) {
    for (final row in fees) {
      if (row['content_type']?.toString() == contentType) return row;
    }
    return null;
  }

  IconData _iconFor(String key) => switch (key) {
        'content_cut' || 'cut' => Icons.content_cut_rounded,
        'local_laundry_service' => Icons.local_laundry_service_rounded,
        'gesture' => Icons.gesture_rounded,
        'print' => Icons.print_rounded,
        'format_paint' => Icons.format_paint_rounded,
        'iron' => Icons.build_rounded,
        'inventory_2' => Icons.inventory_2_rounded,
        'label' => Icons.label_rounded,
        'architecture' => Icons.architecture_rounded,
        'design_services' => Icons.design_services_rounded,
        'grid_4x4' => Icons.grid_4x4_rounded,
        'handyman' => Icons.handyman_rounded,
        'texture' => Icons.texture_rounded,
        'precision_manufacturing' => Icons.precision_manufacturing_rounded,
        'local_shipping' => Icons.local_shipping_rounded,
        'warehouse' => Icons.warehouse_rounded,
        'storefront' => Icons.storefront_rounded,
        'school' => Icons.school_rounded,
        'layers' => Icons.layers_rounded,
        'category' => Icons.category_rounded,
        'factory' => Icons.factory_outlined,
        _ => Icons.checkroom_rounded,
      };

  String _sectorName(String? key) {
    for (final row in catalog) {
      if (row['sector_key']?.toString() == key) {
        return row['name_ar']?.toString() ?? key ?? 'خدمة';
      }
    }
    return key ?? 'خدمة';
  }

  @override
  Widget build(BuildContext context) {
    final q = searchController.text.trim().toLowerCase();
    final visibleServices = services.where((row) {
      if (q.isEmpty) return true;
      final text = '${row['title'] ?? ''} ${row['description'] ?? ''} ${row['business_name'] ?? ''}'.toLowerCase();
      return text.contains(q);
    }).toList(growable: false);

    final serviceFee = _feeFor('garment_service');
    final num selectedCost = publicationCurrency == 'points'
        ? ((serviceFee?['points_cost'] ?? 0) as num)
        : ((serviceFee?['gems_cost'] ?? 0) as num);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _header(serviceFee),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'ابحث عن قص، تطريز، طباعة، غسيل، كحت، تفصيل…',
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            _sectorChips(),
            const SizedBox(height: 12),
            if (widget.owner)
              FilledButton.icon(
                onPressed: _openOwnerFeeEditor,
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('تحكم المالك في خدمات الألبسة والرسوم'),
              ),
            if (businesses.isEmpty) ...[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 44, color: AppColors.gold),
                      const SizedBox(height: 8),
                      const Text('لا يوجد نشاط لك. أنشئ مسودة أولًا ثم انشرها برسوم الخدمة المناسبة.'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _createBusiness,
                        icon: const Icon(Icons.add_business_rounded),
                        label: const Text('إنشاء نشاط تجاري'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _createService,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('نشر خدمة جديدة'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibleServices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: Text('لا توجد خدمات منشورة ضمن الاختيار الحالي.')),
              )
            else
              ...visibleServices.map(_serviceCard),
            const SizedBox(height: 18),
            _adsSection(),
            const SizedBox(height: 18),
            if (businesses.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('أنشطتك', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 8),
              ...businesses.map(_businessCard),
            ],
            const SizedBox(height: 16),
            Text(
              'رسم النشر: $selectedCost ${publicationCurrency == 'points' ? 'نقطة' : 'جوهرة'}',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic>? fee) => Card(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF17110A), Color(0xFF2A1E0F)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.checkroom_rounded, size: 29, color: AppColors.gold),
                  SizedBox(width: 10),
                  Expanded(child: Text('خدمات الألبسة والإنتاج', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21))),
                ],
              ),
              const SizedBox(height: 8),
              const Text('خياطة وتفصيل، قص، كحت وقص ليزر، غسيل ومعالجة، تطريز، طباعة، صباغة، كوي وتشطيب، تغليف، ليبل، باترون، تصميم، جلود، مكائن، شحن وأكثر — جميعها من الكتالوج.'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(Icons.stars_rounded, '${fee?['points_cost'] ?? 0} نقطة'),
                  _pill(Icons.diamond_rounded, '${fee?['gems_cost'] ?? 0} جوهرة'),
                  _pill(Icons.security_rounded, 'الدفع'),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _pill(IconData icon, String text) => Chip(avatar: Icon(icon, size: 16, color: AppColors.gold), label: Text(text));

  Widget _sectorChips() => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: catalog.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, index) {
            if (index == 0) {
              return ChoiceChip(
                label: const Text('الكل'),
                selected: selectedSector == null,
                onSelected: (_) {
                  setState(() => selectedSector = null);
                  unawaited(_load());
                },
              );
            }
            final row = catalog[index - 1];
            final key = row['sector_key']?.toString();
            return ChoiceChip(
              avatar: Icon(_iconFor(row['icon_key']?.toString() ?? 'checkroom'), size: 16),
              label: Text(row['name_ar']?.toString() ?? key ?? 'خدمة'),
              selected: selectedSector == key,
              onSelected: (_) {
                setState(() => selectedSector = key);
                unawaited(_load());
              },
            );
          },
        ),
      );

  Widget _serviceCard(Map<String, dynamic> row) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: AppColors.gold.withValues(alpha: .12),
            child: const Icon(Icons.miscellaneous_services_rounded, color: AppColors.gold),
          ),
          title: Text(row['title']?.toString() ?? 'خدمة', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['business_name']?.toString() ?? 'نشاط', style: const TextStyle(color: AppColors.goldMuted, fontSize: 12)),
              const SizedBox(height: 3),
              Text(row['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                children: [
                  Chip(label: Text(_sectorName(row['sector_key']?.toString()))),
                  if (row['price_minor_units'] != null) Chip(label: Text('${row['price_minor_units']} ${row['currency'] ?? ''}')),
                  if ((row['unit']?.toString() ?? '').trim().isNotEmpty) Chip(label: Text('الوحدة: ${row['unit']}')),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _businessCard(Map<String, dynamic> row) {
    final published = row['is_published'] == true;
    return Card(
      child: ListTile(
        leading: Icon(Icons.storefront_rounded, color: published ? AppColors.gold : Colors.white54),
        title: Text(row['business_name']?.toString() ?? 'نشاط'),
        subtitle: Text('${_sectorName(row['sector_key']?.toString())} • ${published ? 'منشور' : 'مسودة'}'),
        trailing: published
            ? const Icon(Icons.check_circle_rounded, color: AppColors.gold)
            : IconButton(
                tooltip: 'نشر بالنقاط أو الجواهر',
                onPressed: () => _publishBusiness(row),
                icon: const Icon(Icons.publish_rounded),
              ),
      ),
    );
  }


  Widget _adsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('إعلانات خدمات الألبسة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            FilledButton.icon(
              onPressed: catalog.isEmpty ? null : _createAd,
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('إضافة إعلان'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ads.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('لا توجد إعلانات خدمات معروضة ضمن الاختيار الحالي.')))
        else
          ...ads.map(_adCard),
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> row) {
    final images = row['images'] is List ? List<dynamic>.from(row['images'] as List) : const <dynamic>[];
    final status = row['status']?.toString() ?? 'pending';
    final image = images.isEmpty ? null : images.first?.toString();
    final specs = row['specs'] is Map ? Map<String, dynamic>.from(row['specs'] as Map) : <String, dynamic>{};
    final location = (row['city']?.toString().isNotEmpty == true) ? ' • ${row['city']}' : '';
    final details = (specs['details']?.toString().isNotEmpty == true) ? ' • ${specs['details']}' : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: SizedBox(
          width: 58, height: 58,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image != null && image.isNotEmpty
                ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.checkroom_rounded))
                : const Icon(Icons.checkroom_rounded),
          ),
        ),
        title: Text(row['title']?.toString() ?? 'إعلان خدمة', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${_sectorName(row['sector_key']?.toString())} • $status$location$details', maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Future<void> _createAd() async {
    if (catalog.isEmpty) return;
    final title = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final unit = TextEditingController(text: 'طلب');
    final minQty = TextEditingController();
    final city = TextEditingController();
    final address = TextEditingController();
    final phone = TextEditingController();
    final whatsapp = TextEditingController();
    final details = TextEditingController();
    var serviceKey = catalog.first['service_key']?.toString() ?? '';
    var sectorKey = catalog.first['sector_key']?.toString() ?? 'tailoring';
    var currency = publicationCurrency;
    final imageUrls = <String>[];

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) {
            final fee = _feeFor('garment_service');
            final cost = currency == 'points' ? (fee?['points_cost'] ?? 0) : (fee?['gems_cost'] ?? 0);
            final enabled = fee?['is_enabled'] == true && (cost as num) > 0;
            return AlertDialog(
              title: const Text('إضافة إعلان خدمة ألبسة — نشر مدفوع'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                      initialValue: serviceKey,
                      items: [
                        for (final row in catalog)
                          DropdownMenuItem(
                            value: row['service_key']?.toString(),
                            child: Text(row['name_ar']?.toString() ?? row['service_key']?.toString() ?? ''),
                          ),
                      ],
                      onChanged: (v) {
                        final chosen = catalog.firstWhere((e) => e['service_key']?.toString() == v, orElse: () => catalog.first);
                        setDialog(() {
                          serviceKey = v ?? serviceKey;
                          sectorKey = chosen['sector_key']?.toString() ?? sectorKey;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'الخدمة'),
                    ),
                    TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الإعلان')),
                    TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'وصف الخدمة')),
                    Row(children: [
                      Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة'))),
                    ]),
                    Row(children: [
                      Expanded(child: TextField(controller: minQty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأدنى للكمية'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة'))),
                    ]),
                    TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان التفصيلي')),
                    Row(children: [
                      Expanded(child: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'واتساب'))),
                    ]),
                    TextField(controller: details, maxLines: 4, decoration: const InputDecoration(labelText: 'المواصفات والتفاصيل الإضافية')),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: Text('صور الإعلان (${imageUrls.length}/5)', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ...imageUrls.map((u) => ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(u, width: 62, height: 62, fit: BoxFit.cover))),
                        if (imageUrls.length < 5)
                          OutlinedButton.icon(
                            onPressed: () async {
                              final file = await repo.pickImage();
                              if (file == null) return;
                              try {
                                final url = await repo.uploadGarmentServiceImage(file);
                                setDialog(() => imageUrls.add(url));
                              } catch (e) {
                                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(_friendly(e))));
                              }
                            },
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('رفع صورة'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'points', label: Text('نقاط')),
                        ButtonSegment(value: 'gems', label: Text('جواهر')),
                      ],
                      selected: {currency},
                      onSelectionChanged: (v) => setDialog(() => currency = v.first),
                    ),
                    const SizedBox(height: 5),
                    Text('رسم النشر: $cost${currency == 'points' ? ' نقطة' : ' جوهرة'}'),
                    if (!enabled) const Text('الخدمة متوقفة أو رسمها غير مضبوط من لوحة المالك.', style: TextStyle(color: Colors.orangeAccent)),
                  ]),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: !enabled || title.text.trim().isEmpty ? null : () async {
                    try {
                      await repo.publishGarmentServiceAd(
                        serviceKey: serviceKey,
                        sectorKey: sectorKey,
                        title: title.text.trim(),
                        description: description.text.trim(),
                        priceMinorUnits: int.tryParse(price.text.trim()),
                        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
                        minQty: int.tryParse(minQty.text.trim()),
                        city: city.text.trim().isEmpty ? null : city.text.trim(),
                        address: address.text.trim().isEmpty ? null : address.text.trim(),
                        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                        whatsapp: whatsapp.text.trim().isEmpty ? null : whatsapp.text.trim(),
                        images: imageUrls,
                        specs: {'details': details.text.trim()},
                        publicationCurrency: currency,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(_friendly(e))));
                    }
                  },
                  child: const Text('دفع ونشر'),
                ),
              ],
            );
          },
        ),
      );
      if (result == true) await _load();
    } finally {
      title.dispose(); description.dispose(); price.dispose(); unit.dispose();
      minQty.dispose(); city.dispose(); address.dispose(); phone.dispose(); whatsapp.dispose(); details.dispose();
    }
  }

  Future<void> _createBusiness() async {
    if (catalog.isEmpty) return;
    final name = TextEditingController();
    final description = TextEditingController();
    final city = TextEditingController();
    final phone = TextEditingController();
    String sector = catalog.first['sector_key']?.toString() ?? 'tailoring';
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Text('إنشاء نشاط تجاري'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم النشاط')),
                TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
                TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة')),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف')),
                DropdownButtonFormField<String>(
                  initialValue: sector,
                  items: [for (final row in catalog) DropdownMenuItem(value: row['sector_key']?.toString(), child: Text(row['name_ar']?.toString() ?? ''))],
                  onChanged: (v) => setDialog(() => sector = v ?? sector),
                  decoration: const InputDecoration(labelText: 'القطاع الرئيسي'),
                ),
                const SizedBox(height: 8),
                const Text('سيُحفظ كمسودة.', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    await repo.upsertGarmentBusiness(
                      businessName: name.text.trim(),
                      sectorKey: sector,
                      description: description.text.trim(),
                      city: city.text.trim(),
                      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(_friendly(e))));
                  }
                },
                child: const Text('حفظ المسودة'),
              ),
            ],
          ),
        ),
      );
      if (result == true) await _load();
    } finally {
      name.dispose();
      description.dispose();
      city.dispose();
      phone.dispose();
    }
  }

  Future<void> _publishBusiness(Map<String, dynamic> row) async {
    final currency = await _chooseCurrency('garment_business');
    if (currency == null) return;
    try {
      await repo.publishGarmentBusiness(
        businessId: row['id'].toString(),
        publicationCurrency: currency,
        requestId: const Uuid().v4(),
      );
      await _load();
    } catch (e) {
      _snack(_friendly(e));
    }
  }

  Future<void> _createService() async {
    if (businesses.where((e) => e['is_published'] == true).isEmpty || catalog.isEmpty) {
      _snack('يجب نشر ملف نشاط تجاري أولًا قبل دفع رسم الخدمة.');
      return;
    }

    final title = TextEditingController();
    final description = TextEditingController();
    final price = TextEditingController();
    final unit = TextEditingController(text: 'طلب');
    String business = businesses.firstWhere((e) => e['is_published'] == true)['id'].toString();
    String sector = catalog.first['sector_key']?.toString() ?? 'tailoring';

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) {
            final fee = _feeFor('garment_service');
            final amount = publicationCurrency == 'points' ? (fee?['points_cost'] ?? 0) : (fee?['gems_cost'] ?? 0);
            final canPublishService = fee?['is_enabled'] == true && (amount as num) > 0;
            return AlertDialog(
              title: const Text('نشر خدمة ألبسة'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                    initialValue: business,
                    items: [for (final row in businesses.where((e) => e['is_published'] == true)) DropdownMenuItem(value: row['id']?.toString(), child: Text(row['business_name']?.toString() ?? 'نشاط'))],
                    onChanged: (v) => setDialog(() => business = v ?? business),
                    decoration: const InputDecoration(labelText: 'النشاط المنشور'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: sector,
                    items: [for (final row in catalog) DropdownMenuItem(value: row['sector_key']?.toString(), child: Text(row['name_ar']?.toString() ?? ''))],
                    onChanged: (v) => setDialog(() => sector = v ?? sector),
                    decoration: const InputDecoration(labelText: 'نوع الخدمة'),
                  ),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم الخدمة')),
                  TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
                  TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الخدمة')),
                  TextField(controller: unit, decoration: const InputDecoration(labelText: 'الوحدة')),
                  const SizedBox(height: 8),
                  Text('رسوم النشر: $amount ${publicationCurrency == 'points' ? 'نقطة' : 'جوهرة'}'),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'points', label: Text('نقاط')),
                      ButtonSegment(value: 'gems', label: Text('جواهر')),
                    ],
                    selected: {publicationCurrency},
                    onSelectionChanged: (v) => setDialog(() => publicationCurrency = v.first),
                  ),
                  const SizedBox(height: 5),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: !canPublishService ? null : () async {
                    try {
                      await repo.upsertGarmentService(
                        businessId: business,
                        title: title.text.trim(),
                        description: description.text.trim(),
                        sectorKey: sector,
                        priceMinorUnits: int.tryParse(price.text.trim()),
                        unit: unit.text.trim(),
                        published: true,
                        publicationCurrency: publicationCurrency,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(_friendly(e))));
                    }
                  },
                  child: const Text('دفع ونشر'),
                ),
              ],
            );
          },
        ),
      );
      if (result == true) await _load();
    } finally {
      title.dispose();
      description.dispose();
      price.dispose();
      unit.dispose();
    }
  }

  Future<String?> _chooseCurrency(String contentType) {
    String value = publicationCurrency;
    final fee = _feeFor(contentType);
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('اختيار عملة النشر'),
          content: RadioGroup<String>(
            groupValue: value,
            onChanged: (v) => setDialog(() => value = v ?? value),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              RadioListTile<String>(
                value: 'points',
                selected: value == 'points',
                title: Text('${fee?['points_cost'] ?? 0} نقطة'),
              ),
              RadioListTile<String>(
                value: 'gems',
                selected: value == 'gems',
                title: Text('${fee?['gems_cost'] ?? 0} جوهرة'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('متابعة')),
          ],
        ),
      ),
    );
  }

  Future<void> _openOwnerFeeEditor() async {
    if (!widget.owner) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدارة رسوم النشر'),
        content: const SizedBox.shrink(),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _friendly(Object e) => e.toString().replaceFirst('PostgrestException(message: ', '').replaceFirst(RegExp(r', code:.*'), '').replaceAll('Exception: ', '');
}
