import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../producer_market/data/producer_market_repository.dart';
import '../../../producer_market/presentation/pages/producer_market_page.dart';

class ProducerMarketProfileTab extends ConsumerStatefulWidget {
  final String uid;

  const ProducerMarketProfileTab({
    required this.uid,
    super.key,
  });

  @override
  ConsumerState<ProducerMarketProfileTab> createState() =>
      _ProducerMarketProfileTabState();
}

class _ProducerMarketProfileTabState
    extends ConsumerState<ProducerMarketProfileTab> {
  final repo = ProducerMarketRepository.instance;

  bool loading = true;
  List<Map<String, dynamic>> reels = [];
  String username = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        repo.myReels(),
        repo.profiles([widget.uid]),
      ]);
      if (!mounted) return;
      final names = Map<String, String>.from(results[1] as Map);
      setState(() {
        reels = List<Map<String, dynamic>>.from(results[0] as List);
        username = (names[widget.uid] ?? '').trim();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل منشورات الورش: $e')),
      );
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> reel) async {
    final id = reel['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف منشور الورش'),
        content: Text(
          'سيتم حذف «' +
              (reel['title'] ?? 'الفيديو').toString() +
              '» نهائيًا من منشوراتك. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await repo.deleteReel(id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف منشور الورش من الخادم ✓')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف المنشور: $e')),
        );
      }
    }
  }

  Future<void> _togglePublished(Map<String, dynamic> reel) async {
    final id = reel['id']?.toString();
    if (id == null || id.isEmpty) return;
    final published = reel['is_published'] == true;

    try {
      await repo.setReelPublished(id, !published);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تغيير ظهور الفيديو: $e')),
        );
      }
    }
  }

  Future<void> _edit(Map<String, dynamic> reel) async {
    final title = TextEditingController(
      text: reel['title']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: reel['description']?.toString() ?? '',
    );
    final duration = TextEditingController(
      text: reel['duration_seconds']?.toString() ?? '',
    );
    final price = TextEditingController(
      text: reel['price_minor_units']?.toString() ?? '',
    );
    final city = TextEditingController(
      text: reel['city']?.toString() ?? '',
    );
    final tags = TextEditingController(
      text: reel['tags'] is List ? (reel['tags'] as List).join(', ') : '',
    );
    String? selectedSector = reel['sector_key']?.toString();
    bool allowDownload = reel['allow_download'] != false;

    try {
      final sectorRows = await repo.sectors();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialog) => AlertDialog(
            title: const Text('تعديل منشور الورش'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'المدة بالثواني',
                    ),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر'),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(
                      labelText: 'المدينة/الورشة',
                    ),
                  ),
                  TextField(
                    controller: tags,
                    decoration: const InputDecoration(
                      labelText: 'الوسوم مفصولة بفواصل',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: sectorRows.any(
                      (row) =>
                          row['sector_key']?.toString() == selectedSector,
                    )
                        ? selectedSector
                        : null,
                    items: sectorRows
                        .map(
                          (row) => DropdownMenuItem<String>(
                            value: row['sector_key']?.toString(),
                            child: Text(row['name_ar']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialog(() => selectedSector = value),
                    decoration: const InputDecoration(
                      labelText: 'قطاع الورش',
                    ),
                  ),
                  SwitchListTile(
                    value: allowDownload,
                    onChanged: (value) =>
                        setDialog(() => allowDownload = value),
                    title: const Text('السماح بالتحميل'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  final durationValue =
                      int.tryParse(duration.text.trim()) ?? 0;
                  if (title.text.trim().isEmpty || durationValue <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('العنوان والمدة الصحيحة مطلوبان.'),
                      ),
                    );
                    return;
                  }

                  try {
                    await repo.updateReel(
                      reelId: reel['id'].toString(),
                      title: title.text.trim(),
                      description: description.text.trim(),
                      videoUrl: reel['video_url']?.toString(),
                      durationSeconds: durationValue,
                      thumbnailUrl: reel['thumbnail_url']?.toString(),
                      sectorKey: selectedSector,
                      priceMinorUnits:
                          int.tryParse(price.text.trim()),
                      city: city.text.trim(),
                      tags: tags.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                      allowDownload: allowDownload,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _load();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تعديل المنشور خادميًا ✓'),
                      ),
                    );
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text('تعذر حفظ التعديل: $e')),
                      );
                    }
                  }
                },
                child: const Text('حفظ خادميًا'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      description.dispose();
      duration.dispose();
      price.dispose();
      city.dispose();
      tags.dispose();
    }
  }

  Widget _statusChip(Map<String, dynamic> reel) {
    final blocked = reel['is_blocked'] == true;
    final published = reel['is_published'] == true;
    if (blocked) return const Chip(label: Text('محجوب'));
    return Chip(label: Text(published ? 'ظاهر في الورش' : 'مخفي'));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (reels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_library_outlined, size: 52),
              const SizedBox(height: 10),
              const Text(
                'لا توجد منشورات في الورش لهذا الحساب بعد.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProducerMarketPage(),
                  ),
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('نشر أول فيديو في الورش'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: reels.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final reel = reels[index];
          final thumbnail = reel['thumbnail_url']?.toString();
          final title = reel['title']?.toString() ?? 'منشور ورش';
          final visibleUsername = username.isEmpty ? 'مستخدم' : username;

          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumbnail != null && thumbnail.isNotEmpty
                      ? Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: AppColors.surface,
                            child: Center(
                              child: Icon(
                                Icons.video_file_outlined,
                                size: 46,
                              ),
                            ),
                          ),
                        )
                      : const ColoredBox(
                          color: AppColors.surface,
                          child: Center(
                            child: Icon(
                              Icons.video_file_outlined,
                              size: 46,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          visibleUsername,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _statusChip(reel),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text(
                    reel['description']?.toString() ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _edit(reel),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('تعديل'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _togglePublished(reel),
                        icon: Icon(
                          reel['is_published'] == true
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        label: Text(
                          reel['is_published'] == true ? 'إخفاء' : 'إظهار',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _confirmDelete(reel),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProducerMarketPage(),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('عرض في الورش'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
