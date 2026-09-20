import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mashareena/core/services/media_upload_service.dart';
import '../../../core/data/supabase_document_compat.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../gamification/domain/entities/points_package_entity.dart';
import '../../gamification/presentation/providers/gamification_provider.dart';
import '../../gamification/domain/usecases/purchase_points_package_usecase.dart';
import '../domain/entities/store_item_entity.dart';
import '../domain/usecases/store_usecases.dart';
import '../presentation/store_features_tab.dart' show storeCatalogProvider;

class StoreAdminPanel extends ConsumerWidget {
  const StoreAdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authControllerProvider).valueOrNull?.uid;
    final catalog = ref.watch(storeCatalogProvider).valueOrNull ??
        const <StoreItemEntity>[];
    final packages = ref.watch(pointsPackagesProvider).valueOrNull ??
        const <PointsPackageEntity>[];
    if (uid == null) return const SizedBox.shrink();
    return AlertDialog(
      title: const Text('إدارة متجر مالك المنصة'),
      content: SizedBox(
        width: 760,
        height: 620,
        child: DefaultTabController(
          length: 3,
          child: Column(children: [
            const TabBar(tabs: [
              Tab(text: 'عناصر المتجر'),
              Tab(text: 'GIF متحركة'),
              Tab(text: 'النقاط والجواهر')
            ]),
            Expanded(
                child: TabBarView(children: [
              Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.only(bottom: 70),
                    itemCount: catalog.length,
                    itemBuilder: (_, i) {
                      final item = catalog[i];
                      return ListTile(
                        leading: CircleAvatar(
                            backgroundColor: item.colors.first,
                            child: Icon(
                                item.category == StoreItemCategory.avatarFrame
                                    ? Icons.crop_square
                                    : Icons.auto_awesome)),
                        title: Text(item.nameAr),
                        subtitle: Text(
                            '${item.pricePoints} نقطة • ${item.category.labelAr}'),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.card_giftcard),
                              onPressed: () => _giftStoreItem(context, item)),
                          IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _editStoreItem(context, uid, item))
                        ]),
                      );
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: FilledButton.icon(
                      onPressed: () => _createItem(context, uid),
                      icon: const Icon(Icons.add_box),
                      label: const Text('إضافة عنصر جديد'),
                    ),
                  ),
                ],
              ),
              Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.only(bottom: 70),
                    itemCount: catalog
                        .where((item) => item.assetType.toLowerCase() == 'gif')
                        .length,
                    itemBuilder: (_, i) {
                      final gifs = catalog
                          .where(
                              (item) => item.assetType.toLowerCase() == 'gif')
                          .toList(growable: false);
                      final item = gifs[i];
                      return ListTile(
                        leading: item.assetUrl == null
                            ? const CircleAvatar(
                                child: Icon(Icons.gif_box_outlined))
                            : SizedBox(
                                width: 48,
                                height: 48,
                                child: Image.network(item.assetUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined))),
                        title: Text(item.nameAr),
                        subtitle: Text(
                            '${item.pricePoints} نقطة • ${item.category.labelAr}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.upload_file_outlined),
                          tooltip: 'استبدال GIF',
                          onPressed: () => _replaceGif(context, uid, item, ref),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: FilledButton.icon(
                      onPressed: () => _createGifItem(context, uid, ref),
                      icon: const Icon(Icons.gif_box_outlined),
                      label: const Text(
                          'إضافة فئة GIF جديدة — السعر الافتراضي 14000 نقطة'),
                    ),
                  ),
                ],
              ),
              Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.only(bottom: 70),
                    itemCount: packages.length,
                    itemBuilder: (_, i) {
                      final p = packages[i];
                      return ListTile(
                        leading:
                            Text(p.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(p.title),
                        subtitle: Text(
                            '${p.pointsGranted} ${p.category.label} • ${p.price.formatted}'),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.card_giftcard),
                              onPressed: () => _giftPackage(context, p)),
                          IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editPackage(context, uid, p))
                        ]),
                      );
                    },
                  ),
                  Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: FilledButton.icon(
                          onPressed: () => _createPackage(context),
                          icon: const Icon(Icons.add_box),
                          label: const Text('إضافة حزمة جديدة'))),
                ],
              ),
            ])),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))
      ],
    );
  }

  Future<void> _giftStoreItem(
      BuildContext context, StoreItemEntity item) async {
    final c = TextEditingController();
    final target = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: Text('إهداء ${item.nameAr}'),
                content: TextField(
                    controller: c,
                    decoration:
                        const InputDecoration(labelText: 'UID المستلم')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, c.text.trim()),
                      child: const Text('إهداء'))
                ]));
    c.dispose();
    if (target == null || target.isEmpty) return;
    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('adminGrantStoreItem')
          .call({'targetUid': target, 'itemId': item.id});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إهداء ${item.nameAr}')));
    } on SupabaseFunctionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'تعذّر الإهداء')));
    }
  }

  Future<void> _giftPackage(
      BuildContext context, PointsPackageEntity package) async {
    final c = TextEditingController();
    final target = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: Text('إهداء ${package.title}'),
                content: TextField(
                    controller: c,
                    decoration:
                        const InputDecoration(labelText: 'UID المستلم')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, c.text.trim()),
                      child: const Text('إهداء'))
                ]));
    c.dispose();
    if (target == null || target.isEmpty) return;
    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('adminGrantPointsPackage')
          .call({'targetUid': target, 'packageId': package.id});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تم إهداء ${package.title}')));
    } on SupabaseFunctionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? 'تعذّر الإهداء')));
    }
  }

  Future<String?> _pickAndUploadGif(String uid) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gif'],
      withData: true,
    );
    if (picked == null || picked.files.single.bytes == null) return null;
    final bytes = picked.files.single.bytes!;
    final path =
        '$uid/${DateTime.now().microsecondsSinceEpoch}_${picked.files.single.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
    try {
      final url = await MediaUploadService(bucket: 'media').uploadBytesAtPath(
        bytes: bytes,
        fileName: picked.files.single.name,
        path: path,
        contentType: 'image/gif',
      );
      return url;
    } catch (e, st) {
      debugPrint('[StoreAdminPanel] failed uploading GIF: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  Future<void> _createGifItem(
      BuildContext context, String uid, WidgetRef ref) async {
    final id = TextEditingController(
        text: 'gif_${DateTime.now().millisecondsSinceEpoch}');
    final name = TextEditingController();
    final price = TextEditingController(text: '14000');
    var category = StoreItemCategory.animatedBackground;
    String? assetUrl;

    final result = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('إضافة عنصر GIF من مالك المنصة'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: id,
                  decoration: const InputDecoration(labelText: 'ID فريد')),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم العنصر')),
              TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'السعر بالنقاط')),
              DropdownButtonFormField<StoreItemCategory>(
                initialValue: category,
                items: StoreItemCategory.values
                    .map((v) =>
                        DropdownMenuItem(value: v, child: Text(v.labelAr)))
                    .toList(),
                onChanged: (v) => setLocal(() => category = v ?? category),
                decoration: const InputDecoration(labelText: 'الفئة'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final url = await _pickAndUploadGif(uid);
                    setLocal(() => assetUrl = url);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تعذّر رفع GIF: $e')));
                    }
                  }
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(
                    assetUrl == null ? 'اختيار GIF ورفعه' : 'تم رفع GIF ✓'),
              ),
              if (assetUrl != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                    height: 110,
                    child: Image.network(assetUrl!, fit: BoxFit.contain)),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed:
                    assetUrl == null ? null : () => Navigator.pop(d, true),
                child: const Text('حفظ في المتجر')),
          ],
        ),
      ),
    );

    final itemId = id.text.trim();
    final itemName = name.text.trim();
    final itemPrice = int.tryParse(price.text.trim());
    id.dispose();
    name.dispose();
    price.dispose();
    if (result != true ||
        itemId.isEmpty ||
        itemName.isEmpty ||
        itemPrice == null ||
        itemPrice < 0 ||
        assetUrl == null) {
      if (assetUrl != null) {
        try {
          await MediaUploadService(bucket: 'media').deleteFile(assetUrl!);
        } catch (_) {}
      }
      return;
    }

    final item = StoreItemEntity(
      id: itemId,
      category: category,
      nameAr: itemName,
      pricePoints: itemPrice,
      priceGems: 0,
      colors: const [Color(0xFFD4AF37)],
      enabled: true,
      isFeatured: true,
      rarity: 'legendary',
      assetUrl: assetUrl,
      assetType: 'gif',
      previewAsset: assetUrl,
    );
    final resultCreate = await sl<CreateStoreItemUseCase>()
        .call(item: item, requestedByUid: uid);
    final failed = resultCreate.isLeft();
    if (failed && assetUrl != null) {
      try {
        await MediaUploadService(bucket: 'media').deleteFile(assetUrl!);
      } catch (_) {}
    }
    if (!context.mounted) return;
    ref.invalidate(storeCatalogProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resultCreate.fold((f) => f.message,
            (_) => 'تم حفظ GIF في قاعدة البيانات والمتجر ✓'))));
  }

  Future<void> _replaceGif(BuildContext context, String uid,
      StoreItemEntity item, WidgetRef ref) async {
    try {
      final url = await _pickAndUploadGif(uid);
      if (url == null) return;
      final dbId = int.tryParse(item.id);
      try {
        if (dbId == null) {
          final row = await Supabase.instance.client
              .from('store_items')
              .select('id')
              .eq('code', item.id)
              .maybeSingle();
          if (row == null) throw Exception('العنصر غير موجود');
          await Supabase.instance.client
              .rpc('dragon_update_store_item_asset', params: {
            'p_item_id': (row['id'] as num).toInt(),
            'p_asset_url': url,
            'p_asset_type': 'gif'
          });
        } else {
          await Supabase.instance.client.rpc('dragon_update_store_item_asset',
              params: {
                'p_item_id': dbId,
                'p_asset_url': url,
                'p_asset_type': 'gif'
              });
        }
      } catch (_) {
        try {
          await MediaUploadService(bucket: 'media').deleteFile(url);
        } catch (_) {}
        rethrow;
      }
      try {
        await MediaUploadService(bucket: 'media').deleteFile(item.assetUrl ?? '');
      } catch (_) {}
      if (!context.mounted) return;
      ref.invalidate(storeCatalogProvider);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث GIF وحفظه في المتجر ✓')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر تحديث GIF: $e')));
    }
  }

  Future<void> _createPackage(BuildContext context) async {
    final id = TextEditingController();
    final title = TextEditingController();
    final qty = TextEditingController(text: '100');
    final price = TextEditingController(text: '5.00');
    var category = 'points';
    final result = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('إضافة حزمة نقاط/جواهر'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: id,
                decoration: const InputDecoration(labelText: 'ID')),
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(
                controller: qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية')),
            TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'السعر شام كاش')),
            DropdownButtonFormField<String>(
              initialValue: category,
              items: const [
                DropdownMenuItem(value: 'points', child: Text('نقاط')),
                DropdownMenuItem(value: 'gems', child: Text('جواهر')),
                DropdownMenuItem(value: 'mixed', child: Text('مختلطة')),
                DropdownMenuItem(value: 'bulk', child: Text('جملة')),
                DropdownMenuItem(value: 'daily', child: Text('يومية'))
              ],
              onChanged: (value) =>
                  setLocal(() => category = value ?? category),
              decoration: const InputDecoration(labelText: 'الفئة'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    final newId = id.text.trim();
    final newTitle = title.text.trim();
    final q = int.tryParse(qty.text.trim());
    final pr = double.tryParse(price.text.trim());
    id.dispose();
    title.dispose();
    qty.dispose();
    price.dispose();
    if (result != true ||
        newId.isEmpty ||
        newTitle.isEmpty ||
        q == null ||
        q <= 0 ||
        pr == null ||
        pr < 0) {
      return;
    }
    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('adminCreatePointsPackage')
          .call({
        'id': newId,
        'title': newTitle,
        'pointsGranted': q,
        'priceMinorUnits': (pr * 100).round(),
        'currency': 'shamCash',
        'category': category,
        'rarity': 'rare',
        'icon': category == 'gems' ? '💎' : '⭐',
        'isFeatured': true,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تمت إضافة الحزمة')));
    } on SupabaseFunctionException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'تعذّر إنشاء الحزمة')));
    }
  }

  Future<void> _createItem(BuildContext context, String uid) async {
    final id = TextEditingController();
    final name = TextEditingController();
    final price = TextEditingController(text: '100');
    var category = StoreItemCategory.usernameGlow;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('إضافة عنصر متجر '),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: id,
                decoration: const InputDecoration(labelText: 'ID فريد')),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم العربي')),
            TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعر بالنقاط')),
            const SizedBox(height: 8),
            DropdownButtonFormField<StoreItemCategory>(
              initialValue: category,
              items: StoreItemCategory.values
                  .map((value) => DropdownMenuItem(
                      value: value, child: Text(value.labelAr)))
                  .toList(),
              onChanged: (value) =>
                  setLocal(() => category = value ?? category),
              decoration: const InputDecoration(labelText: 'القسم'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    final newId = id.text.trim();
    final newName = name.text.trim();
    final newPrice = int.tryParse(price.text.trim());
    id.dispose();
    name.dispose();
    price.dispose();
    if (result != true ||
        newId.isEmpty ||
        newName.isEmpty ||
        newPrice == null ||
        newPrice < 0) {
      return;
    }
    final item = StoreItemEntity(
      id: newId,
      category: category,
      nameAr: newName,
      pricePoints: newPrice,
      colors: const [Color(0xFFD4AF37)],
      enabled: true,
      isFeatured: true,
      rarity: 'legendary',
    );
    final r = await sl<CreateStoreItemUseCase>()
        .call(item: item, requestedByUid: uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.fold((f) => f.message, (_) => 'تمت إضافة العنصر'))));
  }

  Future<void> _editStoreItem(
      BuildContext context, String uid, StoreItemEntity item) async {
    final pointsController = TextEditingController(
      text: item.pricePoints.toString(),
    );

    final gemsController = TextEditingController(
      text: (item.priceGems ?? 0).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('أسعار ${item.nameAr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر بالنقاط',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gemsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر بالجواهر',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != true) {
      pointsController.dispose();
      gemsController.dispose();
      return;
    }

    final pricePoints = int.tryParse(pointsController.text.trim());

    final priceGems = int.tryParse(gemsController.text.trim());

    pointsController.dispose();
    gemsController.dispose();

    if (pricePoints == null ||
        priceGems == null ||
        pricePoints < 0 ||
        priceGems < 0) {
      return;
    }

    final r = await sl<UpdateStoreItemUseCase>().call(
      itemId: item.id,
      pricePoints: pricePoints,
      priceGems: priceGems,
      enabled: item.enabled,
      requestedByUid: uid,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.fold((f) => f.message, (_) => 'تم تحديث السعر'))));
  }

  Future<void> _editPackage(
      BuildContext context, String uid, PointsPackageEntity p) async {
    final controller =
        TextEditingController(text: p.price.amount.toStringAsFixed(2));
    final result = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('سعر ${p.title}'),
                content: TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'السعر')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('حفظ'))
                ]));
    if (result != true) {
      controller.dispose();
      return;
    }
    final amount = double.tryParse(controller.text.trim());
    controller.dispose();
    if (amount == null || amount < 0) return;
    final r = await sl<UpdatePointsPackagePriceUseCase>().call(
        packageId: p.id,
        priceMinorUnits: (amount * 100).round(),
        enabled: true,
        requestedByUid: uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.fold((f) => f.message, (_) => 'تم تحديث السعر'))));
  }
}
