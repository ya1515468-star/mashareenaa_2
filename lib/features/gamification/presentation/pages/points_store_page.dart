import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/media_upload_service.dart';

class PointsStorePage extends StatefulWidget {
  const PointsStorePage({super.key});
  @override State<PointsStorePage> createState() => _PointsStorePageState();
}

class _PointsStorePageState extends State<PointsStorePage> {
  final _db = Supabase.instance.client;
  final _media = MediaUploadService(bucket: 'currency-package-media');
  bool _loading = true;
  bool _owner = false;
  String _filter = 'all';
  String? _error;
  List<Map<String, dynamic>> _packages = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final owner = await _db.rpc('is_my_platform_owner') == true;
      final rows = await _db.from('currency_packages')
          .select('id,package_type,title,description,amount,bonus_amount,price_minor_units,price_currency,image_url,icon_key,enabled,featured,sort_order,created_at')
          .order('sort_order').order('created_at', ascending: false);
      if (!mounted) return;
      setState(() { _owner = owner; _packages = List<Map<String, dynamic>>.from(rows); _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _friendly(e); });
    }
  }

  List<Map<String, dynamic>> get _visible => _packages.where((p) {
    final enabled = p['enabled'] == true;
    return (_owner || enabled) && (_filter == 'all' || p['package_type']?.toString() == _filter);
  }).toList();

  Future<void> _buy(Map<String, dynamic> row) async {
    try {
      await _db.rpc('purchase_currency_package', params: {
        'p_package_id': row['id'],
        'p_request_id': 'buy_' + DateTime.now().microsecondsSinceEpoch.toString(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم شراء الباقة وإضافة الرصيد')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    try {
      await _db.rpc('admin_set_currency_package_enabled', params: {'p_id': row['id'], 'p_enabled': row['enabled'] != true});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _edit({Map<String, dynamic>? row}) async {
    final title = TextEditingController(text: row?['title']?.toString() ?? '');
    final desc = TextEditingController(text: row?['description']?.toString() ?? '');
    final amount = TextEditingController(text: row?['amount']?.toString() ?? '0');
    final bonus = TextEditingController(text: row?['bonus_amount']?.toString() ?? '0');
    final price = TextEditingController(text: row?['price_minor_units']?.toString() ?? '0');
    final sort = TextEditingController(text: row?['sort_order']?.toString() ?? '0');
    String type = row?['package_type']?.toString() ?? 'points';
    String? imageUrl = row?['image_url']?.toString();
    bool enabled = row?['enabled'] != false;
    bool featured = row?['featured'] == true;
    PlatformFile? picked;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: Text(row == null ? 'إضافة باقة' : 'تعديل باقة'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(value: 'points', child: Text('نقاط ⭐')),
                  DropdownMenuItem(value: 'gems', child: Text('جواهر 💎')),
                ],
                onChanged: (v) => setDialog(() => type = v ?? type),
                decoration: const InputDecoration(labelText: 'النوع'),
              ),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم الباقة')),
              TextField(controller: desc, maxLines: 2, decoration: const InputDecoration(labelText: 'الوصف')),
              Row(children: [
                Expanded(child: TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: bonus, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الإضافي'))),
              ]),
              TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالشام كاش')),
              TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_rounded),
                label: Text(picked?.name ?? (imageUrl == null ? 'رفع صورة' : 'استبدال الصورة')),
                onPressed: () async {
                  final file = await _media.pickImage();
                  if (file == null) return;
                  try {
                    final uid = _db.auth.currentUser?.id;
                    if (uid == null) throw StateError('AUTH_REQUIRED');
                    final bytes = file.bytes ?? await file.xFile.readAsBytes();
                    final url = await _media.uploadBytes(bytes: bytes, fileName: file.name, folder: 'packages', uid: uid);
                    setDialog(() { picked = file; imageUrl = url; });
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(_friendly(e))));
                  }
                },
              ),
              if (imageUrl != null && imageUrl!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Image.network(imageUrl!, height: 90, width: 90, fit: BoxFit.cover)),
              SwitchListTile(value: enabled, onChanged: (v) => setDialog(() => enabled = v), title: const Text('نشطة')),
              SwitchListTile(value: featured, onChanged: (v) => setDialog(() => featured = v), title: const Text('مميزة')),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    await _db.rpc('admin_upsert_currency_package', params: {
                      'p_id': row?['id']?.toString() ?? (type + '_' + DateTime.now().millisecondsSinceEpoch.toString()),
                      'p_package_type': type,
                      'p_title': title.text.trim(),
                      'p_description': desc.text.trim(),
                      'p_amount': int.tryParse(amount.text) ?? 0,
                      'p_bonus_amount': int.tryParse(bonus.text) ?? 0,
                      'p_price_minor_units': int.tryParse(price.text) ?? 0,
                      'p_price_currency': 'sham_cash',
                      'p_image_url': imageUrl,
                      'p_icon_key': type == 'gems' ? '💎' : '⭐',
                      'p_enabled': enabled,
                      'p_featured': featured,
                      'p_sort_order': int.tryParse(sort.text) ?? 0,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(_friendly(e))));
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose(); desc.dispose(); amount.dispose(); bonus.dispose(); price.dispose(); sort.dispose();
    }
  }

  String _friendly(Object e) {
    final raw = e.toString().replaceFirst('PostgrestException(message: ', '').replaceFirst(RegExp(r', code:.*'), '').replaceAll('Exception: ', '');
    if (raw.contains('FORBIDDEN')) return 'لا تملك صلاحية إدارة الباقات.';
    if (raw.contains('INSUFFICIENT')) return 'الرصيد غير كافٍ.';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    return Scaffold(
      appBar: AppBar(
        title: const Text('متجر النقاط والجواهر'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          if (_owner) IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('الكل')),
                        ButtonSegment(value: 'points', label: Text('النقاط ⭐')),
                        ButtonSegment(value: 'gems', label: Text('الجواهر 💎')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) => setState(() => _filter = s.first),
                    ),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text(_owner ? 'لا توجد باقات بعد.' : 'لا توجد باقات متاحة.'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => _PackageCard(
                                row: rows[i], owner: _owner,
                                buy: () => _buy(rows[i]), edit: () => _edit(row: rows[i]), toggle: () => _toggle(rows[i]),
                              ),
                            ),
                          ),
                  ),
                ]),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool owner;
  final VoidCallback buy;
  final VoidCallback edit;
  final VoidCallback toggle;
  const _PackageCard({required this.row, required this.owner, required this.buy, required this.edit, required this.toggle});

  @override
  Widget build(BuildContext context) {
    final gems = row['package_type']?.toString() == 'gems';
    final amount = (row['amount'] as num?)?.toInt() ?? 0;
    final bonus = (row['bonus_amount'] as num?)?.toInt() ?? 0;
    final price = (row['price_minor_units'] as num?)?.toInt() ?? 0;
    final image = row['image_url']?.toString();
    final icon = row['icon_key']?.toString() ?? (gems ? '💎' : '⭐');
    final enabled = row['enabled'] == true;
    final label = gems ? 'جوهرة' : 'نقطة';
    final subtitle = (amount + bonus).toString() + ' ' + label + ' • السعر ' + price.toString();
    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 60, height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image != null && image.isNotEmpty
                ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _icon(icon))
                : _icon(icon),
          ),
        ),
        title: Text(row['title']?.toString() ?? 'باقة'),
        subtitle: Text(subtitle),
        trailing: owner
            ? Wrap(children: [
                IconButton(onPressed: edit, icon: const Icon(Icons.edit_rounded)),
                IconButton(onPressed: toggle, icon: Icon(enabled ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
              ])
            : (enabled ? FilledButton(onPressed: buy, child: const Text('شراء')) : const SizedBox.shrink()),
      ),
    );
  }

  Widget _icon(String value) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        colors: row['package_type']?.toString() == 'gems'
            ? const [Color(0xFF173E68), Color(0xFF6C35A5)]
            : const [Color(0xFF634A11), Color(0xFFD8A628)],
      ),
    ),
    child: Center(child: Text(value, style: const TextStyle(fontSize: 28))),
  );
}
