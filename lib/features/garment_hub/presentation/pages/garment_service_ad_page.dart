import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class GarmentServiceAdPage extends StatefulWidget {
  const GarmentServiceAdPage({super.key});
  @override
  State<GarmentServiceAdPage> createState() => _GarmentServiceAdPageState();
}

class _GarmentServiceAdPageState extends State<GarmentServiceAdPage> {
  final db = Supabase.instance.client;
  final uuid = const Uuid();
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
  List<Map<String, dynamic>> services = const [];
  String? serviceKey;
  String? sectorKey;
  String publicationCurrency = 'points';
  List<String> images = const [];
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final rows = await db.rpc('get_garment_service_catalog');
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows as List);
      setState(() {
        services = list;
        if (services.isNotEmpty) {
          serviceKey = services.first['service_key']?.toString();
          sectorKey = services.first['sector_key']?.toString();
        }
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _pickImages() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final uid = db.auth.currentUser?.id;
    if (uid == null) return;

    final uploaded = <String>[...images];
    try {
      for (final file in picked.files.take(8 - uploaded.length)) {
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) continue;
        final ext = (file.extension ?? 'jpg').toLowerCase();
        final path = '$uid/${uuid.v4()}.$ext';
        final storage = db.storage.from('garment-service-media');
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
        uploaded.add('storage://garment-service-media/$path');
      }
      if (!mounted) return;
      setState(() => images = uploaded);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  Future<void> _publish() async {
    if (saving || serviceKey == null || sectorKey == null) return;
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العنوان مطلوب.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      await db.rpc('publish_garment_service_ad', params: {
        'p_service_key': serviceKey,
        'p_sector_key': sectorKey,
        'p_title': title.text.trim(),
        'p_description': description.text.trim(),
        'p_price_minor_units': int.tryParse(price.text.trim()),
        'p_currency': 'sham_cash',
        'p_unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
        'p_min_qty': int.tryParse(minQty.text.trim()),
        'p_city': city.text.trim().isEmpty ? null : city.text.trim(),
        'p_address': address.text.trim().isEmpty ? null : address.text.trim(),
        'p_phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'p_whatsapp':
            whatsapp.text.trim().isEmpty ? null : whatsapp.text.trim(),
        'p_images': images,
        'p_specs': {
          if (specs.text.trim().isNotEmpty) 'details': specs.text.trim(),
        },
        'p_publication_currency': publicationCurrency,
        'p_request_id': const Uuid().v4(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نشر الإعلان.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  String _friendly(Object e) => e
      .toString()
      .replaceFirst('PostgrestException(message: ', '')
      .replaceFirst(RegExp(r', code:.*'), '')
      .replaceAll('Exception: ', '');

  @override
  void dispose() {
    for (final c in [
      title,
      description,
      price,
      unit,
      minQty,
      city,
      address,
      phone,
      whatsapp,
      specs,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة إعلان خدمة ألبسة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: serviceKey,
            items: services
                .map(
                  (s) => DropdownMenuItem(
                    value: s['service_key']?.toString(),
                    child: Text(
                      s['name_ar']?.toString() ??
                          s['service_key']?.toString() ??
                          'خدمة',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              final row = services.firstWhere(
                (s) => s['service_key']?.toString() == v,
              );
              setState(() {
                serviceKey = v;
                sectorKey = row['sector_key']?.toString();
              });
            },
            decoration: const InputDecoration(labelText: 'نوع الخدمة'),
          ),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'عنوان الإعلان'),
          ),
          TextField(
            controller: description,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'الوصف'),
          ),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر'),
          ),
          TextField(
            controller: unit,
            decoration: const InputDecoration(labelText: 'الوحدة'),
          ),
          TextField(
            controller: minQty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الحد الأدنى للطلب'),
          ),
          TextField(
            controller: city,
            decoration: const InputDecoration(labelText: 'المدينة'),
          ),
          TextField(
            controller: address,
            decoration: const InputDecoration(labelText: 'العنوان'),
          ),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'الهاتف'),
          ),
          TextField(
            controller: whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'واتساب'),
          ),
          TextField(
            controller: specs,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'التفاصيل والمواصفات'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final image in images)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        image,
                        width: 92,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        onPressed: () =>
                            setState(() => images = [...images]..remove(image)),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: images.length >= 8 ? null : _pickImages,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('رفع صور من الهاتف'),
          ),
          DropdownButtonFormField<String>(
            value: publicationCurrency,
            items: const [
              DropdownMenuItem(
                value: 'points',
                child: Text('رسوم النشر بالنقاط'),
              ),
              DropdownMenuItem(
                value: 'gems',
                child: Text('رسوم النشر بالجواهر'),
              ),
            ],
            onChanged: (v) =>
                setState(() => publicationCurrency = v ?? publicationCurrency),
            decoration: const InputDecoration(labelText: 'عملة رسوم النشر'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : _publish,
            icon: const Icon(Icons.publish_rounded),
            label: Text(saving ? 'جارٍ النشر...' : 'نشر الإعلان'),
          ),
        ],
      ),
    );
  }
}
