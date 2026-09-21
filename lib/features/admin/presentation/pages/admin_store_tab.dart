import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/media_upload_service.dart';

final ownerPointGemPackagesProvider =
    FutureProvider.autoDispose<_AdminPackages>((ref) async {
  final client = Supabase.instance.client;
  final owner = await client.rpc('is_my_platform_owner') == true;
  if (!owner) throw Exception('FORBIDDEN');
  final results = await Future.wait([
    client
        .from('points_packages')
        .select('*')
        .order('sort_order')
        .order('price_minor_units'),
    client
        .from('currency_packages')
        .select('*')
        .eq('package_type', 'gems')
        .order('sort_order')
        .order('price_minor_units'),
  ]);
  return _AdminPackages(
    points: List<Map<String, dynamic>>.from(results[0] as List),
    gems: List<Map<String, dynamic>>.from(results[1] as List),
  );
});

class AdminStoreTab extends ConsumerWidget {
  const AdminStoreTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ownerPointGemPackagesProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('تعذر تحميل الباقات: $e')),
      data: (data) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openEditor(
                context,
                ref,
                kind: _AdminPackageKind.points,
              ),
              icon: const Icon(Icons.add),
              label: const Text('باقة نقاط'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'باقات النقاط',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          ...data.points.map(
            (row) => _AdminPackageTile(
              row: row,
              kind: _AdminPackageKind.points,
              onEdit: () => _openEditor(
                context,
                ref,
                kind: _AdminPackageKind.points,
                row: row,
              ),
            ),
          ),
          const Divider(height: 28),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openEditor(
                context,
                ref,
                kind: _AdminPackageKind.gems,
              ),
              icon: const Icon(Icons.add),
              label: const Text('باقة جواهر'),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'باقات الجواهر',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          ...data.gems.map(
            (row) => _AdminPackageTile(
              row: row,
              kind: _AdminPackageKind.gems,
              onEdit: () => _openEditor(
                context,
                ref,
                kind: _AdminPackageKind.gems,
                row: row,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    required _AdminPackageKind kind,
    Map<String, dynamic>? row,
  }) async {
    final result = await showDialog<_AdminPackageFormResult>(
      context: context,
      builder: (_) => _AdminPackageDialog(kind: kind, row: row),
    );
    if (result == null) return;

    String? uploadedUrl = result.existingImageUrl;
    try {
      if (result.file != null) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) throw Exception('AUTH_REQUIRED');
        final bytes =
            result.file!.bytes ?? await result.file!.xFile.readAsBytes();
        final ext = (result.file!.extension ?? 'png').toLowerCase();
        uploadedUrl =
            await MediaUploadService(bucket: 'currency-package-media')
                .uploadBytesAtPath(
          bytes: bytes,
          fileName: result.file!.name,
          path: 'packages/$uid/${const Uuid().v4()}.$ext',
        );
      }

      if (kind == _AdminPackageKind.points) {
        await Supabase.instance.client.rpc(
          'admin_upsert_points_package',
          params: {
            'p_package_id': result.id,
            'p_title': result.title,
            'p_description': result.description,
            'p_points_granted': result.amount,
            'p_bonus_points': result.bonus,
            'p_price_minor_units': result.price,
            'p_currency': 'shamCash',
            'p_category': 'points',
            'p_rarity': 'common',
            'p_icon': result.icon.isEmpty ? '⭐' : result.icon,
            'p_image_url': uploadedUrl,
            'p_background_image_url': null,
            'p_display_mode': 'card',
            'p_primary_color': null,
            'p_secondary_color': null,
            'p_text_color': null,
            'p_border_color': null,
            'p_badge_text': null,
            'p_sort_order': result.sortOrder,
            'p_is_featured': result.featured,
            'p_enabled': result.enabled,
            'p_request_id': const Uuid().v4(),
          },
        );
      } else {
        await Supabase.instance.client.rpc(
          'admin_upsert_currency_package',
          params: {
            'p_id': result.id,
            'p_package_type': 'gems',
            'p_title': result.title,
            'p_description': result.description,
            'p_amount': result.amount,
            'p_bonus_amount': result.bonus,
            'p_price_minor_units': result.price,
            'p_price_currency': 'sham_cash',
            'p_image_url': uploadedUrl,
            'p_icon_key': result.icon.isEmpty ? '💎' : result.icon,
            'p_enabled': result.enabled,
            'p_featured': result.featured,
            'p_sort_order': result.sortOrder,
          },
        );
      }

      ref.invalidate(ownerPointGemPackagesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الباقة على الخادم')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل حفظ الباقة: $e')),
        );
      }
    }
  }
}

class _AdminPackages {
  final List<Map<String, dynamic>> points;
  final List<Map<String, dynamic>> gems;
  const _AdminPackages({required this.points, required this.gems});
}

enum _AdminPackageKind { points, gems }

class _AdminPackageTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final _AdminPackageKind kind;
  final VoidCallback onEdit;

  const _AdminPackageTile({
    required this.row,
    required this.kind,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final amount = ((row[
                kind == _AdminPackageKind.points
                    ? 'points_granted'
                    : 'amount'] as num?)
            ?.toInt() ??
        0);
    final bonus = ((row[
                kind == _AdminPackageKind.points
                    ? 'bonus_points'
                    : 'bonus_amount'] as num?)
            ?.toInt() ??
        0);
    return Card(
      child: ListTile(
        leading: _PackageImage(
          url: row['image_url']?.toString(),
          fallback: row[
                  kind == _AdminPackageKind.points ? 'icon' : 'icon_key']
              ?.toString(),
          kind: kind,
        ),
        title: Text(row['title']?.toString() ?? row['id'].toString()),
        subtitle: Text(
          '$amount + $bonus • ${((row['price_minor_units'] as num?)?.toInt() ?? 0)} شام كاش • ${row['enabled'] == true ? 'مفعلة' : 'موقوفة'}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
      ),
    );
  }
}

class _PackageImage extends StatelessWidget {
  final String? url;
  final String? fallback;
  final _AdminPackageKind kind;

  const _PackageImage({
    required this.url,
    required this.fallback,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.trim().isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url!));
    }
    return CircleAvatar(
      child: Text(
        (fallback == null || fallback!.isEmpty)
            ? (kind == _AdminPackageKind.points ? '⭐' : '💎')
            : fallback!,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }
}

class _AdminPackageFormResult {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int amount;
  final int bonus;
  final int price;
  final int sortOrder;
  final bool enabled;
  final bool featured;
  final String? existingImageUrl;
  final PlatformFile? file;

  const _AdminPackageFormResult({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.amount,
    required this.bonus,
    required this.price,
    required this.sortOrder,
    required this.enabled,
    required this.featured,
    required this.existingImageUrl,
    required this.file,
  });
}

class _AdminPackageDialog extends StatefulWidget {
  final _AdminPackageKind kind;
  final Map<String, dynamic>? row;

  const _AdminPackageDialog({required this.kind, this.row});

  @override
  State<_AdminPackageDialog> createState() => _AdminPackageDialogState();
}

class _AdminPackageDialogState extends State<_AdminPackageDialog> {
  late final TextEditingController _id;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final TextEditingController _bonus;
  late final TextEditingController _price;
  late final TextEditingController _sort;
  late final TextEditingController _icon;
  late bool enabled;
  late bool featured;
  PlatformFile? file;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    final kind = widget.kind;
    _id = TextEditingController(text: row?['id']?.toString() ?? '');
    _title = TextEditingController(text: row?['title']?.toString() ?? '');
    _description =
        TextEditingController(text: row?['description']?.toString() ?? '');
    final amountKey =
        kind == _AdminPackageKind.points ? 'points_granted' : 'amount';
    final bonusKey =
        kind == _AdminPackageKind.points ? 'bonus_points' : 'bonus_amount';
    _amount = TextEditingController(
      text: ((row?[amountKey] as num?)?.toInt() ?? 0).toString(),
    );
    _bonus = TextEditingController(
      text: ((row?[bonusKey] as num?)?.toInt() ?? 0).toString(),
    );
    _price = TextEditingController(
      text: ((row?['price_minor_units'] as num?)?.toInt() ?? 0).toString(),
    );
    _sort = TextEditingController(
      text: ((row?['sort_order'] as num?)?.toInt() ?? 0).toString(),
    );
    _icon = TextEditingController(
      text: row?['icon']?.toString() ?? row?['icon_key']?.toString() ?? '',
    );
    enabled = row?['enabled'] != false;
    featured = row?[kind == _AdminPackageKind.points ? 'is_featured' : 'featured'] ==
        true;
  }

  @override
  void dispose() {
    for (final c in [
      _id,
      _title,
      _description,
      _amount,
      _bonus,
      _price,
      _sort,
      _icon
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final picked =
        result != null && result.files.isNotEmpty ? result.files.first : null;
    if (picked != null && mounted) {
      setState(() => file = picked);
    }
  }

  void _save() {
    final id = _id.text.trim();
    final title = _title.text.trim();
    final amount = int.tryParse(_amount.text.trim());
    final bonus = int.tryParse(_bonus.text.trim());
    final price = int.tryParse(_price.text.trim());
    final sortOrder = int.tryParse(_sort.text.trim());
    if (id.isEmpty ||
        title.isEmpty ||
        amount == null ||
        amount < 0 ||
        bonus == null ||
        bonus < 0 ||
        price == null ||
        price < 0 ||
        sortOrder == null ||
        sortOrder < 0) {
      return;
    }
    Navigator.pop(
      context,
      _AdminPackageFormResult(
        id: id,
        title: title,
        description: _description.text.trim(),
        icon: _icon.text.trim(),
        amount: amount,
        bonus: bonus,
        price: price,
        sortOrder: sortOrder,
        enabled: enabled,
        featured: featured,
        existingImageUrl: widget.row?['image_url']?.toString(),
        file: file,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.row == null
            ? (widget.kind == _AdminPackageKind.points
                ? 'إضافة باقة نقاط'
                : 'إضافة باقة جواهر')
            : 'تعديل الباقة',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _id,
              enabled: widget.row == null,
              decoration: const InputDecoration(labelText: 'المعرف'),
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.kind == _AdminPackageKind.points
                    ? 'عدد النقاط'
                    : 'عدد الجواهر',
              ),
            ),
            TextField(
              controller: _bonus,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المكافأة'),
            ),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر شام كاش'),
            ),
            TextField(
              controller: _sort,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ترتيب العرض'),
            ),
            TextField(
              controller: _icon,
              decoration: InputDecoration(
                labelText: widget.kind == _AdminPackageKind.points
                    ? 'رمز النقاط'
                    : 'رمز الجواهر',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.upload_file),
                label: Text(
                    file == null ? 'رفع صورة من الهاتف' : file!.name),
              ),
            ),
            SwitchListTile(
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
              title: const Text('مفعلة'),
            ),
            SwitchListTile(
              value: featured,
              onChanged: (v) => setState(() => featured = v),
              title: const Text('مميزة'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
