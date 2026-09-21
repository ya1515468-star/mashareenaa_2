import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/routing/app_route_observer.dart';
import '../../../../core/media/media_playback_coordinator.dart';
import '../../../store/presentation/widgets/visual_effect_config.dart';
import '../../../store/presentation/widgets/visual_effect_host.dart';
import '../../data/producer_market_repository.dart';
import 'producer_market_admin_page.dart';
import '../../../rbac/presentation/widgets/server_username_display.dart';

class ProducerMarketPage extends ConsumerStatefulWidget {
  final bool isActive;
  const ProducerMarketPage({super.key, this.isActive = true});
  @override
  ConsumerState<ProducerMarketPage> createState() => _ProducerMarketPageState();
}

class _ProducerMarketPageState extends ConsumerState<ProducerMarketPage> with WidgetsBindingObserver, RouteAware {
  final repo = ProducerMarketRepository.instance;
  final pageController = PageController();
  List<Map<String, dynamic>> reels = [];
  Map<String, String> names = {};
  Set<String> likes = {}, saves = {};
  Map<String, dynamic> season = {};
  Map<String, dynamic> quota = {};
  bool loading = true;
  bool owner = false;
  List<Map<String, dynamic>> garmentServices = [];
  final Map<int, VideoPlayerController> controllers = {};
  final Map<int, Future<VideoPlayerController>> controllerLoads = {};

  @override
  void initState() {
    super.initState();
    AppMediaPlaybackCoordinator.scope.addListener(_onMediaScopeChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  int _currentIndex = 0;

  void _onMediaScopeChanged() {
    if (!AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
      unawaited(_stopAllPlayback());
    } else if (widget.isActive && reels.isNotEmpty) {
      _playIndex(_currentIndex);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    AppMediaPlaybackCoordinator.setScope(null);
    unawaited(_stopAllPlayback());
  }

  @override
  void didPopNext() {
    if (widget.isActive && reels.isNotEmpty) {
      AppMediaPlaybackCoordinator.setScope(AppMediaPlaybackCoordinator.producerMarket);
      _playIndex(_currentIndex);
    }
  }

  @override
  void didUpdateWidget(covariant ProducerMarketPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive && AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
      if (reels.isNotEmpty) _playIndex(_currentIndex);
    } else {
      unawaited(_stopAllPlayback());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_stopAllPlayback());
    } else if (state == AppLifecycleState.resumed && widget.isActive && reels.isNotEmpty && AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
      _playIndex(_currentIndex);
    }
  }

  Future<void> _stopAllPlayback() async {
    for (final c in controllers.values) {
      try {
        await c.pause();
        await c.setVolume(0);
      } catch (_) {}
    }
  }

  Future<void> _load() async {
    // The reel feed is the critical path. Metadata/config must never hide a valid reel.
    List<Map<String, dynamic>> data = const [];
    try {
      data = await repo.reels();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _snack('تعذر تحميل سوق الألبسة: ${_friendly(e)}');
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      reels = data;
      loading = false;
    });
    if (reels.isNotEmpty && widget.isActive && AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
      _playIndex(0);
    }

    // Non-critical data is loaded independently. A failure here must not blank the feed.
    try {
      final ids = data.map((e) => e['owner_uid']?.toString()).whereType<String>().toSet().toList();
      names = await repo.profiles(ids);
    } catch (_) {}

    try {
      final ids = data.map((e) => e['id']?.toString()).whereType<String>().toList();
      likes = await repo.myInteractions(ids, 'reel_likes');
      saves = await repo.myInteractions(ids, 'reel_saves');
    } catch (_) {}

    try {
      quota = await repo.reelQuota();
      owner = quota['unlimited'] == true;
    } catch (_) {}

    try {
      final s = await repo.bootstrap();
      if ((s['background_url']?.toString() ?? '').startsWith('storage://')) {
        s['background_url'] = await repo.mediaUrl(kind: 'season', id: 'true', variant: 'background', path: s['background_url']?.toString());
      }
      if ((s['overlay_gif_url']?.toString() ?? '').startsWith('storage://')) {
        s['overlay_gif_url'] = await repo.mediaUrl(kind: 'season', id: 'true', variant: 'overlay', path: s['overlay_gif_url']?.toString());
      }
      season = s;
    } catch (_) {}

    try {
      garmentServices = await repo.garmentServiceCatalog();
    } catch (_) {}

    if (!mounted) return;
    setState(() {});
  }

  Future<VideoPlayerController> _controllerFor(int index, String url) async {
    final current = controllers[index];
    if (current != null) return current;
    final signed = await repo.mediaUrl(kind: 'reel', id: reels[index]['id'].toString());
    final c = VideoPlayerController.networkUrl(Uri.parse(signed), videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
    controllers[index] = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(widget.isActive && AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket) ? 1 : 0);
      return c;
    } catch (_) {
      controllers.remove(index);
      await c.dispose();
      rethrow;
    }
  }

  void _playIndex(int index) {
    if (index < 0 || index >= reels.length) return;
    _currentIndex = index;
    if (!widget.isActive || !AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
      unawaited(_stopAllPlayback());
      return;
    }
    for (final entry in controllers.entries) {
      if (entry.key != index) {
        unawaited(entry.value.pause());
        unawaited(entry.value.setVolume(0));
      }
    }
    final url = reels[index]['video_url']?.toString() ?? '';
    if (url.isEmpty) return;
    final load = _controllerFor(index, url);
    controllerLoads[index] = load;
    if (mounted) setState(() {});
    unawaited(load.then((c) async {
      if (!mounted || !widget.isActive || _currentIndex != index || !AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
        try {
          await c.pause();
          await c.setVolume(0);
        } catch (_) {}
        return;
      }
      try {
        await c.setVolume(1);
        await c.play();
      } catch (_) {}
    }));
    unawaited(repo.interact(reels[index]['id'].toString(), 'view'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) {
      AppMediaPlaybackCoordinator.setScope(null);
    }
    AppMediaPlaybackCoordinator.scope.removeListener(_onMediaScopeChanged);
    appRouteObserver.unsubscribe(this);
    for (final c in controllers.values) {
      unawaited(c.pause());
      unawaited(c.setVolume(0));
      unawaited(c.dispose());
    }
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              if (reels.isEmpty) const _EmptyMarket(),
              if (reels.isNotEmpty)
                PageView.builder(
                  controller: pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: reels.length,
                  onPageChanged: _playIndex,
                  itemBuilder: (_, i) => _ReelPage(
                    reel: reels[i],
                    name: names[reels[i]['owner_uid'].toString()] ?? 'منتج أزياء',
                    ownerUid: reels[i]['owner_uid']?.toString(),
                    liked: likes.contains(reels[i]['id'].toString()),
                    saved: saves.contains(reels[i]['id'].toString()),
                    controllerFuture: controllerLoads[i],
                    onLike: () => _toggle(i, 'like'),
                    onSave: () => _toggle(i, 'save'),
                    onShare: () => _share(i),
                    onDownload: () => _download(i),
                    onComments: () => _comments(i),
                    onRetry: () {
                      controllerLoads.remove(i);
                      _playIndex(i);
                      setState(() {});
                    },
                  ),
                ),
              _SeasonOverlay(season: season),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10,
                right: 10,
                child: Row(children: [
                  if (owner)
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProducerMarketAdminPage())).then((_) => _load()),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: _showGarmentServices,
                    icon: const Icon(Icons.home_repair_service_outlined),
                    tooltip: 'خدمات الألبسة',
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: _publishDialog,
                    icon: const Icon(Icons.add_a_photo_outlined),
                  ),
                ]),
              ),
              Positioned(
                left: 14,
                right: 14,
                top: MediaQuery.paddingOf(context).top + 74,
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 17),
                  const SizedBox(width: 6),
                  Text('سوق الألبسة • ريلز المنتجات والخدمات', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontWeight: FontWeight.w700, fontSize: 12)),
                  const Spacer(),
                  Text(quota['tier']?.toString() == 'owner' ? 'المالك • بلا حدود' : 'عضوية ${quota['tier'] ?? 'free'}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ]),
              ),
            ]),
      floatingActionButton: reels.isEmpty ? FloatingActionButton.extended(heroTag: 'producer_market_publish_reel', onPressed: _publishDialog, icon: const Icon(Icons.video_call_outlined), label: const Text('انشر في سوق الألبسة')) : null,
    );
  }

  Future<void> _showGarmentServices() async {
    final services = List<Map<String, dynamic>>.from(garmentServices);
    if (!mounted) return;
    if (services.isEmpty) {
      _snack('لا توجد خدمات ألبسة فعالة على الخادم حاليًا.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .82,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 6, 18, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'خدمات الورش والألبسة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'المصدر الخادمي الفعلي — كل الخدمات النشطة تظهر هنا.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final service = services[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.gold.withValues(alpha: .16),
                          child: const Icon(
                            Icons.checkroom_outlined,
                            color: AppColors.gold,
                          ),
                        ),
                        title: Text(
                          service['name_ar']?.toString() ??
                              service['service_key']?.toString() ??
                              'خدمة',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          service['description_ar']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          service['sector_key']?.toString() ?? '',
                          style: const TextStyle(
                            color: AppColors.goldMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(int i, String action) async {
    final id = reels[i]['id'].toString();
    final isOn = action == 'like' ? likes.contains(id) : saves.contains(id);
    try {
      await repo.interact(id, isOn ? 'un$action' : action);
      if (!mounted) return;
      setState(() {
        if (action == 'like') {
          isOn ? likes.remove(id) : likes.add(id);
          final current = (reels[i]['likes_count'] as num?)?.toInt() ?? 0;
          reels[i]['likes_count'] = (current + (isOn ? -1 : 1)).clamp(0, 1 << 30);
        }
        if (action == 'save') {
          isOn ? saves.remove(id) : saves.add(id);
        }
      });
    } catch (e) {
      _snack(_friendly(e));
    }
  }

  Future<void> _share(int i) async {
    try {
      final url = await repo.mediaUrl(kind: 'reel', id: reels[i]['id'].toString(), path: reels[i]['video_url']?.toString());
      await SharePlus.instance.share(ShareParams(text: 'شاهد هذا المنتج من سوق الألبسة في مشاريعنا:\n$url'));
      await repo.interact(reels[i]['id'].toString(), 'share');
    } catch (e) {
      _snack(_friendly(e));
    }
  }

  Future<void> _download(int i) async {
    try {
      final url = await repo.mediaUrl(kind: 'reel', id: reels[i]['id'].toString(), purpose: 'download', path: reels[i]['video_url']?.toString());
      await Clipboard.setData(ClipboardData(text: url));
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      _snack(opened ? 'تم فتح رابط التحميل.' : 'تم تجهيز رابط التحميل ونسخه.');
      await repo.interact(reels[i]['id'].toString(), 'download');
    } catch (e) {
      _snack(_friendly(e));
    }
  }

  Future<void> _comments(int i) async {
    final id = reels[i]['id'].toString();
    final body = TextEditingController();
    List<Map<String, dynamic>> comments = [];
    String? replyTo;
    try { comments = await repo.comments(id); } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => StatefulBuilder(builder: (context, setModal) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(children: [
              const SizedBox(height: 12),
              const Icon(Icons.drag_handle_rounded, color: Colors.white24),
              const Text('التعليقات والردود', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 8),
              Expanded(
                child: comments.isEmpty
                    ? const Center(child: Text('كن أول من يعلّق على هذا المنتج.'))
                    : ListView.separated(
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, j) {
                          final c = comments[j];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                            title: Text(c['body'].toString()),
                            subtitle: Text(c['created_at'].toString().replaceFirst('T', ' ').split('.').first),
                            trailing: c['reply_to_id'] == null ? IconButton(onPressed: () { replyTo = c['id']?.toString(); body.text = '@'; setModal(() {}); }, icon: const Icon(Icons.reply_outlined)) : null,
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [if (replyTo != null) Row(children: [const Icon(Icons.reply_rounded, size: 14, color: AppColors.gold), const SizedBox(width: 4), const Text('رد مباشر على تعليق', style: TextStyle(color: Colors.white60, fontSize: 11)), const Spacer(), IconButton(onPressed: () => setModal(() => replyTo = null), icon: const Icon(Icons.close_rounded, size: 16))]), TextField(controller: body, maxLines: 3, decoration: const InputDecoration(hintText: 'اكتب تعليقًا محترمًا عن المنتج...'))])),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final text = body.text.trim();
                      if (text.isEmpty) return;
                      try {
                        await repo.addComment(id, text, replyTo: replyTo);
                        body.clear();
                        replyTo = null;
                        comments = await repo.comments(id);
                        setModal(() {});
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
    body.dispose();
  }

  Future<void> _publishDialog() async {
    final sectorRows = await repo.sectors();
    if (!mounted) return;
    if (sectorRows.isEmpty) {
      _snack('لا توجد قطاعات فعالة على الخادم للنشر.');
      return;
    }
    final title = TextEditingController();
    final desc = TextEditingController();
    final price = TextEditingController();
    final city = TextEditingController();
    final durationField = TextEditingController(text: '30');
    final tags = TextEditingController();
    PlatformFile? video;
    PlatformFile? cover;
    var allow = false;
    var publicationCurrency = 'points';
    String selectedSector = sectorRows.first['sector_key']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
        return AlertDialog(
          title: const Row(children: [Icon(Icons.movie_creation_outlined, color: AppColors.gold), SizedBox(width: 8), Text('نشر ريلز في الورش')]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('الحصة: ${quota['remaining'] ?? 0} / ${quota['total'] ?? 0}  •  الحد: ${quota['max_duration_seconds'] ?? 0}ث', style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text('رسوم النشر: ${quota['publish_cost_points'] ?? 0} نقطة • ${quota['publish_cost_gems'] ?? 0} جوهرة', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'points', label: Text('نقاط')),
                  ButtonSegment<String>(value: 'gems', label: Text('جواهر')),
                ],
                selected: {publicationCurrency},
                onSelectionChanged: (value) => setDialog(() => publicationCurrency = value.first),
              ),
              const SizedBox(height: 10),
              TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان المنتج', prefixIcon: Icon(Icons.checkroom_outlined))),
              TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف المنتج، الخامة، القصة، الاستخدام')),
              Row(children: [Expanded(child: TextField(controller: durationField, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدة الفيديو (ثانية)'))), const SizedBox(width: 8), Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر')))]),
              TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة / الورشة')),
              DropdownButtonFormField<String>(
                initialValue: sectorRows.any((row) => row['sector_key']?.toString() == selectedSector) ? selectedSector : null,
                decoration: const InputDecoration(
                  labelText: 'قطاع المنتج',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final row in sectorRows)
                    DropdownMenuItem<String>(
                      value: row['sector_key']?.toString(),
                      child: Text(row['name_ar']?.toString() ?? row['sector_key']?.toString() ?? ''),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialog(() => selectedSector = value);
                },
              ),
              TextField(controller: tags, decoration: const InputDecoration(labelText: 'وسوم الألبسة مفصولة بفواصل')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () async { video = await repo.pickVideo(); if (ctx.mounted) setDialog(() {}); }, icon: const Icon(Icons.video_library_outlined), label: Text(video == null ? 'اختيار الفيديو' : video!.name, overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () async { cover = await repo.pickImage(); if (ctx.mounted) setDialog(() {}); }, icon: const Icon(Icons.image_outlined), label: Text(cover == null ? 'الغلاف' : cover!.name, overflow: TextOverflow.ellipsis))),
              ]),
              SwitchListTile(value: allow, onChanged: (v) => setDialog(() => allow = v), title: const Text('السماح بتحميل المقطع')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton.icon(
              onPressed: video == null ? null : () async {
                final selectedTitle = title.text.trim();
                if (selectedTitle.isEmpty) {
                  _snack('اكتب عنوان المنتج قبل رفع الفيديو.');
                  return;
                }
                final selectedDuration = int.tryParse(durationField.text) ?? 0;
                if (selectedDuration <= 0) {
                  _snack('مدة الفيديو يجب أن تكون أكبر من صفر.');
                  return;
                }
                try {
                  Navigator.pop(ctx);
                  _snack('جارٍ رفع الفيديو والتحقق خادميًا...');
                  final vp = await repo.uploadReelVideo(video!);
                  String? cp;
                  if (cover != null) cp = await repo.uploadReelCover(cover!);
                  final tagList = tags.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  await repo.publishReel(title: selectedTitle, description: desc.text, duration: selectedDuration, videoPath: vp, coverPath: cp, allowDownload: allow, sector: selectedSector, priceLabel: price.text.isEmpty ? null : price.text, city: city.text.isEmpty ? null : city.text, tags: tagList, publicationCurrency: publicationCurrency);
                  _snack('تم نشر المنتج بعد تحقق الخادم من العضوية والحصة والمدة والتكلفة.');
                  await _load();
                } catch (e) {
                  _snack(_friendly(e));
                }
              },
              icon: const Icon(Icons.publish_rounded),
              label: const Text('نشر'),
            ),
          ],
        );
      }),
    );
    title.dispose(); desc.dispose(); price.dispose(); city.dispose(); durationField.dispose(); tags.dispose();
  }

  void _snack(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  String _friendly(Object e) => e.toString().replaceFirst('PostgrestException(message: ', '').replaceFirst(RegExp(r', code:.*'), '').replaceAll('Exception: ', '');
}

class _SeasonOverlay extends StatelessWidget {
  final Map<String, dynamic> season;
  const _SeasonOverlay({required this.season});
  @override
  Widget build(BuildContext context) {
    final title = season['title']?.toString() ?? 'الورش';
    final date = season['show_date'] == false ? '' : (season['date_text']?.toString() ?? '');
    final bg = season['background_url']?.toString();
    final gif = season['overlay_gif_url']?.toString();
    final effect = season['title_effect']?.toString() ?? 'golden_sparkle';
    final active = season['is_active'] != false;
    return IgnorePointer(child: AnimatedOpacity(opacity: active ? 1 : 0, duration: const Duration(milliseconds: 400), child: Stack(children: [
      if (bg != null && bg.startsWith('http')) Positioned.fill(child: Image.network(bg, fit: BoxFit.cover, opacity: const AlwaysStoppedAnimation(.22))),
      Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .48), Colors.transparent, Colors.black.withValues(alpha: .12)])))),
      Positioned(left: 18, right: 18, top: MediaQuery.paddingOf(context).top + 10, child: VisualEffectHost(effectKey: effect, placement: VisualEffectPlacement.username, quality: VisualEffectQuality.ultra, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xE30B1016), Color(0xB318162A)]), border: Border.all(color: AppColors.gold.withValues(alpha: .5)), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)]), child: Stack(alignment: Alignment.center, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [Text(title, style: TextStyle(fontFamily: season['title_font_family']?.toString() ?? 'MashareenaKufi', fontSize: double.tryParse(season['title_font_size']?.toString() ?? '') ?? 22, fontWeight: FontWeight.w900, color: const Color(0xFFFFE7A1)), maxLines: 1, overflow: TextOverflow.ellipsis), if (date.isNotEmpty) Text(date, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))]),
        if (gif != null && gif.startsWith('http')) Positioned.fill(child: IgnorePointer(child: Image.network(gif, fit: BoxFit.cover))),
      ])))),
    ])));
  }
}

class _ReelPage extends StatefulWidget {
  final Map<String, dynamic> reel;
  final String name;
  final String? ownerUid;
  final bool liked, saved;
  final Future<VideoPlayerController>? controllerFuture;
  final VoidCallback onLike, onSave, onShare, onDownload, onComments, onRetry;

  const _ReelPage({
    required this.reel,
    required this.name,
    required this.ownerUid,
    required this.liked,
    required this.saved,
    required this.controllerFuture,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onDownload,
    required this.onComments,
    required this.onRetry,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _controller;
  VoidCallback? _listener;
  bool _busy = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _bindControllerFuture();
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controllerFuture != widget.controllerFuture) {
      _unbindController();
      _bindControllerFuture();
    }
  }

  Future<void> _bindControllerFuture() async {
    final future = widget.controllerFuture;
    if (future == null) return;
    try {
      final controller = await future;
      if (!mounted) return;
      _controller = controller;
      _isPlaying = controller.value.isPlaying;
      _listener = () {
        final playing = controller.value.isPlaying;
        if (playing == _isPlaying || !mounted) return;
        setState(() => _isPlaying = playing);
      };
      controller.addListener(_listener!);
      setState(() {});
    } catch (_) {
      // FutureBuilder renders the detailed error state.
    }
  }

  void _unbindController() {
    final controller = _controller;
    final listener = _listener;
    if (controller != null && listener != null) {
      controller.removeListener(listener);
    }
    _controller = null;
    _listener = null;
    _isPlaying = false;
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (!AppMediaPlaybackCoordinator.owns(AppMediaPlaybackCoordinator.producerMarket)) return;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    _busy = true;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
        _isPlaying = false;
      } else {
        if (controller.value.position >= controller.value.duration && controller.value.duration > Duration.zero) {
          await controller.seekTo(Duration.zero);
        }
        await controller.play();
        _isPlaying = true;
      }
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _unbindController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.reel['thumbnail_url']?.toString();
    final controllerFuture = widget.controllerFuture;
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (controllerFuture != null)
          FutureBuilder<VideoPlayerController>(
            future: controllerFuture,
            builder: (context, snap) {
              final c = snap.data ?? controller;
              if (snap.hasError) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null && image.startsWith('http')) Image.network(image, fit: BoxFit.cover),
                    const ColoredBox(color: Colors.black26),
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(28),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .72),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 42),
                            const SizedBox(height: 10),
                            const Text(
                              'وصل الريلز لكن تعذر تشغيل ملف الفيديو',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              snap.error.toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: widget.onRetry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              if (c == null || !c.value.isInitialized) {
                return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePlayback,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: c.value.size.width,
                    height: c.value.size.height,
                    child: VideoPlayer(c),
                  ),
                ),
              );
            },
          )
        else if (image != null && image.startsWith('http'))
          Image.network(image, fit: BoxFit.cover)
        else
          const ColoredBox(color: Colors.black),

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .15),
                  Colors.transparent,
                  Colors.black.withValues(alpha: .9),
                ],
              ),
            ),
          ),
        ),
        ),

        if (isReady)
          Positioned(
            top: MediaQuery.sizeOf(context).height * .50 - 32,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: AppColors.gold.withValues(alpha: .94),
                shape: const CircleBorder(),
                elevation: 10,
                shadowColor: Colors.black54,
                child: InkWell(
                  onTap: _togglePlayback,
                  customBorder: const CircleBorder(),
                  child: Tooltip(
                    message: _isPlaying ? 'إيقاف الفيديو' : 'تشغيل الفيديو',
                    child: SizedBox(
                      width: 66,
                      height: 66,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          key: ValueKey<bool>(_isPlaying),
                          color: Colors.black,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),


        Positioned(
          left: 18,
          right: 92,
          bottom: 34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.ownerUid != null && widget.ownerUid!.trim().isNotEmpty)
                ServerUsernameDisplay(
                  uid: widget.ownerUid!,
                  fallbackName: widget.name,
                  fallbackFontSize: 17,
                  showBadges: true,
                  compactBadges: true,
                )
              else
                Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 4),
              Text(widget.reel['title']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if ((widget.reel['description'] ?? '').toString().isNotEmpty)
                Text(widget.reel['description'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 7),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Pill(icon: Icons.location_on_outlined, text: widget.reel['city']?.toString() ?? 'سورية'),
                  _Pill(icon: Icons.schedule_rounded, text: '${widget.reel['duration_seconds'] ?? 0}ث'),
                  if (widget.reel['price_minor_units'] != null)
                    _Pill(icon: Icons.sell_outlined, text: '${widget.reel['price_minor_units']} ${widget.reel['currency'] ?? ''}'),
                ],
              ),
            ],
          ),
        ),

        Positioned(
          right: 10,
          bottom: 56,
          child: Column(
            children: [
              _ActionButton(
                icon: widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: '${widget.reel['likes_count'] ?? 0}',
                color: widget.liked ? Colors.redAccent : null,
                onTap: widget.onLike,
              ),
              _ActionButton(icon: Icons.mode_comment_outlined, label: '${widget.reel['comments_count'] ?? 0}', onTap: widget.onComments),
              _ActionButton(icon: widget.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: 'حفظ', onTap: widget.onSave),
              _ActionButton(icon: Icons.share_outlined, label: 'مشاركة', onTap: widget.onShare),
              _ActionButton(icon: Icons.download_outlined, label: 'تحميل', onTap: widget.onDownload),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget { final IconData icon; final String label; final VoidCallback onTap; final Color? color; const _ActionButton({required this.icon, required this.label, required this.onTap, this.color}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Column(children: [IconButton.filledTonal(onPressed: onTap, icon: Icon(icon, color: color, size: 23)), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700))])); }
class _Pill extends StatelessWidget { final IconData icon; final String text; const _Pill({required this.icon, required this.text}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 11))])); }
class _EmptyMarket extends StatelessWidget { const _EmptyMarket(); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFE8C86A), Color(0xFF5B3B14)]), boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .32), blurRadius: 34)]), child: const Icon(Icons.checkroom_rounded, size: 58, color: Colors.black)), const SizedBox(height: 18), const Text('سوق الألبسة', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('فيديوهات قصيرة للمنتجات والورش والمصانع والخامات والخدمات ضمن قطاع الألبسة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))]))); }