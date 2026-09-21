import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Compatibility enum retained for the existing cosmetic store tab.
enum StoreFeatureType { glow, frame, background }

class PointsStorePage extends StatefulWidget {
  const PointsStorePage({super.key});
  @override
  State<PointsStorePage> createState() => _PointsStorePageState();
}

class _PointsStorePageState extends State<PointsStorePage> {
  final _uuid = const Uuid();
  bool loading = true;
  bool manager = false;
  List<Map<String, dynamic>> packages = const [];
  Object? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = Supabase.instance.client;
      final rows = await db
          .from('currency_packages')
          .select('id,package_type,title,description,amount,bonus_amount,price_minor_units,price_currency,image_url,icon_key,enabled,featured,sort_order,updated_at')
          .order('sort_order');
      final access = await db.rpc('is_my_platform_owner');
      if (!mounted) return;
      setState(() {
        packages = List<Map<String, dynamic>>.from(rows);
        manager = access == true;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e;
      });
    }
  }

  String _friendly(Object e) => e
      .toString()
      .replaceFirst('PostgrestException(message: ', '')
      .replaceFirst(RegExp(r', code:.*'), '')
      .replaceAll('Exception: ', '');

  Future<void> _purchase(Map<String, dynamic> package) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تأكيد الشراء'),
            content: Text(
              "شراء ${package['title'] ?? 'الباقة'} مقابل ${package['price_minor_units'] ?? 0} من الرصيد.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('شراء'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    try {
      await Supabase.instance.client.rpc(
        'purchase_currency_package',
        params: {
          'p_package_id': package['id'],
          'p_request_id': _uuid.v4(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الشراء وتحديث الرصيد.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _editPackage([Map<String, dynamic>? row]) async {
    final draft = await showDialog<_PackageDraft>(
      context: context,
      builder: (_) => _PackageEditor(initial: row),
    );
    if (draft == null || !mounted) return;

    try {
      await Supabase.instance.client.rpc(
        'admin_upsert_currency_package',
        params: {
          'p_id': draft.id,
          'p_package_type': draft.type,
          'p_title': draft.title,
          'p_description': draft.description,
          'p_amount': draft.amount,
          'p_bonus_amount': draft.bonus,
          'p_price_minor_units': draft.price,
          'p_price_currency': 'sham_cash',
          'p_image_url': draft.imageUrl,
          'p_icon_key': draft.iconKey,
          'p_enabled': draft.enabled,
          'p_featured': draft.featured,
          'p_sort_order': draft.sortOrder,
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _toggle(Map<String, dynamic> row) async {
    try {
      await Supabase.instance.client.rpc(
        'admin_set_currency_package_enabled',
        params: {
          'p_id': row['id'],
          'p_enabled': row['enabled'] != true,
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Widget _packageCard(Map<String, dynamic> p) {
    final isPoints = p['package_type'] == 'points';
    final image = p['image_url']?.toString() ?? '';
    final amount = int.tryParse(p['amount']?.toString() ?? '') ?? 0;
    final bonus = int.tryParse(p['bonus_amount']?.toString() ?? '') ?? 0;
    final price = int.tryParse(p['price_minor_units']?.toString() ?? '') ?? 0;
    final priceCurrency = p['price_currency']?.toString() ?? 'sham_cash';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: (isPoints ? Colors.amber : Colors.lightBlueAccent)
                    .withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: image.startsWith('http')
                  ? Image.network(image, fit: BoxFit.cover)
                  : Icon(
                      isPoints ? Icons.stars_rounded : Icons.diamond_rounded,
                      size: 36,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p['title']?.toString() ?? 'باقة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${isPoints ? 'نقاط' : 'جواهر'}: $amount'
                    '${bonus > 0 ? ' (+$bonus)' : ''}',
                  ),
                  Text(
                    'السعر: $price $priceCurrency',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if ((p['description']?.toString() ?? '').trim().isNotEmpty)
                    Text(
                      p['description'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (manager)
              Column(
                children: [
                  IconButton(
                    onPressed: () => _editPackage(p),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    onPressed: () => _toggle(p),
                    icon: Icon(
                      p['enabled'] == true
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_rounded,
                    ),
                  ),
                ],
              )
            else
              FilledButton.tonal(
                onPressed: () => _purchase(p),
                child: const Text('شراء'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points =
        packages.where((p) => p['package_type'] == 'points').toList();
    final gems =
        packages.where((p) => p['package_type'] == 'gems').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('باقات النقاط والجواهر'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (manager)
            IconButton(
              onPressed: () => _editPackage(),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('تعذر تحميل الباقات: $error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (points.isNotEmpty) ...[
                        const Text(
                          'باقات النقاط',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...points.map(_packageCard),
                        const SizedBox(height: 18),
                      ],
                      if (gems.isNotEmpty) ...[
                        const Text(
                          'باقات الجواهر',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...gems.map(_packageCard),
                      ],
                      if (points.isEmpty && gems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text('لا توجد باقات متاحة حاليًا.'),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: manager
          ? FloatingActionButton.extended(
              onPressed: () => _editPackage(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('باقة جديدة'),
            )
          : null,
    );
  }
}

class _PackageDraft {
  final String id;
  final String type;
  final String title;
  final String description;
  final String iconKey;
  final int amount;
  final int bonus;
  final int price;
  final int sortOrder;
  final String? imageUrl;
  final bool enabled;
  final bool featured;

  const _PackageDraft({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.amount,
    required this.bonus,
    required this.price,
    required this.sortOrder,
    required this.imageUrl,
    required this.iconKey,
    required this.enabled,
    required this.featured,
  });
}

class _PackageEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _PackageEditor({this.initial});

  @override
  State<_PackageEditor> createState() => _PackageEditorState();
}

class _PackageEditorState extends State<_PackageEditor> {
  late final id =
      TextEditingController(text: widget.initial?['id']?.toString() ?? '');
  late final title = TextEditingController(
      text: widget.initial?['title']?.toString() ?? '');
  late final description = TextEditingController(
      text: widget.initial?['description']?.toString() ?? '');
  late final amount = TextEditingController(
      text: widget.initial?['amount']?.toString() ?? '1000');
  late final bonus = TextEditingController(
      text: widget.initial?['bonus_amount']?.toString() ?? '0');
  late final price = TextEditingController(
      text: widget.initial?['price_minor_units']?.toString() ?? '100');
  late final sort = TextEditingController(
      text: widget.initial?['sort_order']?.toString() ?? '100');
  late final icon = TextEditingController(
      text: widget.initial?['icon_key']?.toString() ?? 'currency');
  late final image = TextEditingController(
      text: widget.initial?['image_url']?.toString() ?? '');

  late String type =
      widget.initial?['package_type']?.toString() ?? 'points';
  late bool enabled = widget.initial?['enabled'] != false;
  late bool featured = widget.initial?['featured'] == true;

  @override
  void dispose() {
    for (final c in [
      id, title, description, amount, bonus, price, sort, icon, image
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;

    final file = picked.files.single;
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الصورة فارغة أو تتجاوز 6MB.')),
      );
      return;
    }

    final ext = (file.extension ?? 'png').toLowerCase();
    final path = 'packages/${const Uuid().v4()}.$ext';
    final storage =
        Supabase.instance.client.storage.from('currency-package-media');
    try {
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: false,
          contentType: ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg',
        ),
      );
      if (!mounted) return;
      setState(() => image.text = storage.getPublicUrl(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة باقة' : 'تعديل الباقة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              enabled: widget.initial == null,
              decoration: const InputDecoration(labelText: 'معرّف الباقة'),
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'points', child: Text('نقاط')),
                DropdownMenuItem(value: 'gems', child: Text('جواهر')),
              ],
              onChanged: (v) => setState(() => type = v ?? type),
              decoration: const InputDecoration(labelText: 'نوع الباقة'),
            ),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: type == 'points' ? 'عدد النقاط' : 'عدد الجواهر',
              ),
            ),
            TextField(
              controller: bonus,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'إضافي'),
            ),
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر بالرصيد'),
            ),
            TextField(
              controller: sort,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الترتيب'),
            ),
            TextField(
              controller: icon,
              decoration: const InputDecoration(labelText: 'رمز داخلي'),
            ),
            TextField(
              controller: image,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'رابط صورة الرمز'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _upload,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('رفع صورة من الهاتف'),
              ),
            ),
            SwitchListTile(
              value: featured,
              onChanged: (v) => setState(() => featured = v),
              title: const Text('مميزة'),
            ),
            SwitchListTile(
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
              title: const Text('مفعلة'),
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
          onPressed: () {
            final draft = _PackageDraft(
              id: id.text.trim(),
              type: type,
              title: title.text.trim(),
              description: description.text.trim(),
              amount: int.tryParse(amount.text) ?? 0,
              bonus: int.tryParse(bonus.text) ?? 0,
              price: int.tryParse(price.text) ?? 0,
              sortOrder: int.tryParse(sort.text) ?? 0,
              imageUrl: image.text.trim().isEmpty ? null : image.text.trim(),
              iconKey: icon.text.trim(),
              enabled: enabled,
              featured: featured,
            );
            Navigator.pop(context, draft);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
