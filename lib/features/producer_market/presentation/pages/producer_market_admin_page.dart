import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../store/presentation/widgets/visual_effect_config.dart';
import '../../../store/presentation/widgets/visual_effect_host.dart';
import '../../data/producer_market_repository.dart';

class ProducerMarketAdminPage extends StatefulWidget {
  const ProducerMarketAdminPage({super.key});
  @override
  State<ProducerMarketAdminPage> createState() => _ProducerMarketAdminPageState();
}

class _ProducerMarketAdminPageState extends State<ProducerMarketAdminPage>
    with SingleTickerProviderStateMixin {
  final repo = ProducerMarketRepository.instance;
  late final TabController tabs = TabController(length: 5, vsync: this);
  bool loading = true;
  bool owner = false;
  Map<String, dynamic> season = {};
  List<Map<String, dynamic>> reelRules = [];
  List<Map<String, dynamic>> tenderRules = [];
  List<Map<String, dynamic>> reels = [];
  List<Map<String, dynamic>> tenders = [];
  List<Map<String, dynamic>> wallpapers = [];
  List<Map<String, dynamic>> garmentServices = [];
  List<Map<String, dynamic>> publicationFees = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final clientOwner = await repo.tenderQuota();
      final isOwner = clientOwner['unlimited'] == true;
      if (!isOwner) {
        if (mounted) setState(() { owner = false; loading = false; });
        return;
      }
      final results = await Future.wait([
        repo.bootstrap(),
        repo.reelRules(),
        repo.tenderRules(),
        repo.allReelsForAdmin(),
        repo.allTendersForAdmin(),
        repo.wallpapers(),
        repo.garmentServiceCatalog(),
        repo.garmentPublicationFees(),
      ]);
      if (!mounted) return;
      setState(() {
        owner = true;
        season = Map<String, dynamic>.from(results[0] as Map);
        reelRules = List<Map<String, dynamic>>.from(results[1] as List);
        tenderRules = List<Map<String, dynamic>>.from(results[2] as List);
        reels = List<Map<String, dynamic>>.from(results[3] as List);
        tenders = List<Map<String, dynamic>>.from(results[4] as List);
        wallpapers = List<Map<String, dynamic>>.from(results[5] as List);
        garmentServices = List<Map<String, dynamic>>.from(results[6] as List);
        publicationFees = List<Map<String, dynamic>>.from(results[7] as List);
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { owner = false; loading = false; });
    }
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة سوق المنتجين')),
        body: const Center(child: Text('هذه الصفحة متاحة لمالك المنصة فقط.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة سوق المنتجين — تحكم المالك'),
        bottom: TabBar(controller: tabs, tabs: const [
          Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'الموسم'),
          Tab(icon: Icon(Icons.video_settings_outlined), text: 'حصص الريلز'),
          Tab(icon: Icon(Icons.gavel_rounded), text: 'المناقصات'),
          Tab(icon: Icon(Icons.wallpaper_rounded), text: 'خلفيات الشات'),
          Tab(icon: Icon(Icons.checkroom_rounded), text: 'خدمات ورسوم'),
        ]),
      ),
      body: TabBarView(controller: tabs, children: [
        _seasonEditor(),
        _quotaEditor(reel: true),
        _procurementAdmin(),
        _wallpaperAdmin(),
        _garmentServicesAdmin(),
      ]),
    );
  }

  Widget _seasonEditor() {
    final title = TextEditingController(text: season['title']?.toString() ?? 'موسم الألبسة');
    final date = TextEditingController(text: season['date_text']?.toString() ?? '');
    final bg = TextEditingController(text: season['background_url']?.toString() ?? '');
    final gif = TextEditingController(text: season['overlay_gif_url']?.toString() ?? '');
    final color1 = TextEditingController(text: season['title_color1']?.toString() ?? '#FFE7A1');
    final color2 = TextEditingController(text: season['title_color2']?.toString() ?? '#D4AF37');
    var showDate = season['show_date'] != false;
    var active = season['is_active'] != false;
    var effect = season['title_effect']?.toString() ?? 'golden_sparkle';
    if (effect != 'none' && !VisualEffectRegistry.definitions.containsKey(effect)) effect = 'none';
    const supportedFonts = ['MashareenaKufi', 'Cairo', 'NotoKufiArabic', 'Tajawal', 'Amiri', 'Almarai', 'Rubik'];
    var font = season['title_font_family']?.toString() ?? 'MashareenaKufi';
    if (!supportedFonts.contains(font)) font = supportedFonts.first;
    var size = double.tryParse(season['title_font_size']?.toString() ?? '') ?? 22;

    Future<void> save(StateSetter setModal) async {
      try {
        await repo.updateSeason({
          'p_title': title.text.trim(),
          'p_show_date': showDate,
          'p_date_text': date.text.trim(),
          'p_title_effect': effect,
          'p_title_color1': color1.text.trim(),
          'p_title_color2': color2.text.trim(),
          'p_title_font_family': font,
          'p_title_font_size': size,
          'p_overlay_gif_url': gif.text.trim(),
          'p_overlay_opacity': .82,
          'p_overlay_height': 180,
          'p_background_url': bg.text.trim(),
          'p_background_color1': '#0D1724',
          'p_background_color2': '#241329',
          'p_is_active': active,
        });
        await _load();
        if (mounted) _snack('تم الحفظ.');
      } catch (e) {
        if (mounted) _snack(_friendly(e));
      }
    }

    return StatefulBuilder(builder: (context, setModal) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 210,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFF111827), Color(0xFF32122B)])),
            child: Stack(children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: AppColors.gold.withValues(alpha: .35)), borderRadius: BorderRadius.circular(26)))),
              Center(child: VisualEffectHost(effectKey: effect, placement: VisualEffectPlacement.username, quality: VisualEffectQuality.ultra, child: Text(title.text.isEmpty ? 'موسم شتاء' : title.text, style: const TextStyle(fontFamily: 'MashareenaKufi', fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFFFFE7A1))))),
              Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(14), child: Text(date.text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)))),
            ]),
          ),
          const SizedBox(height: 18),
          _SectionCard(title: 'عنوان الموسم', icon: Icons.title_rounded, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'السطر الأول الظاهر في سوق المنتجين')),
            const SizedBox(height: 10),
            TextField(controller: date, decoration: const InputDecoration(labelText: 'التاريخ / الوصف الزمني')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: showDate, onChanged: (v) => setModal(() => showDate = v), title: const Text('إظهار التاريخ تحت العنوان')),
          ]),
          _SectionCard(title: 'التأثيرات الفاخرة', icon: Icons.auto_awesome_rounded, children: [
            DropdownButtonFormField<String>(initialValue: effect, decoration: const InputDecoration(labelText: 'تأثير العنوان'), items: [
              const DropdownMenuItem<String>(value: 'none', child: Text('بدون تأثير')),
              ...VisualEffectRegistry.definitions.values.map((e) => DropdownMenuItem<String>(value: e.effectKey, child: Text(e.nameAr))),
            ], onChanged: (v) => setModal(() => effect = v ?? effect)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: font, decoration: const InputDecoration(labelText: 'الخط'), items: supportedFonts.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setModal(() => font = v ?? font)),
            Slider(value: size.clamp(16, 40), min: 16, max: 40, divisions: 24, label: size.toStringAsFixed(0), onChanged: (v) => setModal(() => size = v)),
          ]),
          _SectionCard(title: 'خلفية القسم', icon: Icons.wallpaper_rounded, children: [
            TextField(controller: bg, maxLines: 2, decoration: const InputDecoration(labelText: 'رابط/مسار الخلفية')),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(onPressed: () async { final file = await repo.pickImage(); if (file == null) return; try { final path = await repo.uploadSeasonAsset(file, gif: false); setModal(() => bg.text = path); } catch (e) { if (mounted) _snack(_friendly(e)); } }, icon: const Icon(Icons.upload_file_rounded), label: const Text('رفع خلفية القسم')),
          ]),
          _SectionCard(title: 'مؤثر الموسم المتحرك', icon: Icons.gif_box_outlined, children: [
            TextField(controller: gif, maxLines: 2, decoration: const InputDecoration(labelText: 'رابط/مسار GIF شفاف')),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(onPressed: () async { final file = await repo.pickImage(); if (file == null) return; final ext = (file.extension ?? '').toLowerCase(); if (ext != 'gif') { _snack('اختر ملف GIF شفافًا للمؤثر المتحرك.'); return; } try { final path = await repo.uploadSeasonAsset(file, gif: true); setModal(() => gif.text = path); } catch (e) { if (mounted) _snack(_friendly(e)); } }, icon: const Icon(Icons.cloud_upload_rounded), label: const Text('رفع GIF ثلج / شمس / أي مؤثر')),
            const SizedBox(height: 5),
            const Text('', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ]),
          SwitchListTile(value: active, onChanged: (v) => setModal(() => active = v), title: const Text('تفعيل هوية الموسم'), contentPadding: EdgeInsets.zero),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => save(setModal), icon: const Icon(Icons.save_rounded), label: const Text('حفظ الهوية')),
        ],
      );
    });
  }

  Widget _quotaEditor({required bool reel}) {
    final rows = reel ? reelRules : tenderRules;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final tier = row['tier_id'].toString();
        final title = switch (tier) {
          'free' => 'مجانية', 'bronze' => 'برونزية', 'silver' => 'فضية', 'gold' => 'ذهبية', 'diamond' => 'ماسية', 'royal' => 'ملكية', 'vip' => 'VIP', 'legendary' => 'النخبة الأسطورية', _ => 'Ultimate'
        };
        return Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha: .15), child: const Icon(Icons.workspace_premium_outlined, color: AppColors.gold)),
            title: Text('$title  •  $tier'),
            subtitle: Text(reel ? '${row['reels_per_month']} مقطع/شهر  •  حد ${row['max_duration_seconds']}ث  •  ${row['publish_cost_points']} نقطة + ${row['publish_cost_gems']} جوهرة' : '${row['tenders_per_month']} مناقصة محلية  •  ${row['external_per_month']} طلب خارجي  •  ${row['bids_per_month']} عروض  •  ${row['publish_cost_points'] ?? 0} نقطة + ${row['publish_cost_gems'] ?? 0} جوهرة'),
            trailing: IconButton(onPressed: () => _editRule(reel, row), icon: const Icon(Icons.edit_rounded)),
          ),
        );
      },
    );
  }

  Future<void> _editRule(bool reel, Map<String, dynamic> row) async {
    final a = TextEditingController(text: row[reel ? 'reels_per_month' : 'tenders_per_month'].toString());
    final b = TextEditingController(text: row[reel ? 'max_duration_seconds' : 'external_per_month'].toString());
    final c = TextEditingController(text: row[reel ? 'publish_cost_points' : 'bids_per_month'].toString());
    final d = TextEditingController(text: reel ? (row['publish_cost_gems']?.toString() ?? '0') : (row['publish_cost_points']?.toString() ?? '0'));
    final e = TextEditingController(text: row['publish_cost_gems']?.toString() ?? '0');
    var external = row['can_publish_external'] == true;
    var download = row['allow_download'] != false;
    var pin = row['can_pin'] == true;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text('تعديل ${row['tier_id']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: a, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: reel ? 'حصص الريلز / شهر' : 'المناقصات المحلية / شهر')),
        TextField(controller: b, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: reel ? 'المدة القصوى بالثواني' : 'الطلبات الخارجية / شهر')),
        TextField(controller: c, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: reel ? 'تكلفة النقاط' : 'العروض / شهر')),
        if (reel) TextField(controller: d, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة الجواهر')),
        if (!reel) TextField(controller: d, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة النشر بالنقاط')),
        if (!reel) TextField(controller: e, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة النشر بالجواهر')),
        if (reel) SwitchListTile(value: download, onChanged: (v) => setDialog(() => download = v), title: const Text('السماح بالتحميل')),
        if (reel) SwitchListTile(value: pin, onChanged: (v) => setDialog(() => pin = v), title: const Text('السماح بالتثبيت')),
        if (!reel) SwitchListTile(value: external, onChanged: (v) => setDialog(() => external = v), title: const Text('السماح بالنشر الخارجي')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () async {
        final updated = Map<String, dynamic>.from(row);
        if (reel) {
          updated['reels_per_month'] = int.tryParse(a.text) ?? 0;
          updated['max_duration_seconds'] = int.tryParse(b.text) ?? 30;
          updated['publish_cost_points'] = int.tryParse(c.text) ?? 0;
          updated['publish_cost_gems'] = int.tryParse(d.text) ?? 0;
          updated['allow_download'] = download;
          updated['can_pin'] = pin;
        }
        if (!reel) {
          updated['tenders_per_month'] = int.tryParse(a.text) ?? 0;
          updated['external_per_month'] = int.tryParse(b.text) ?? 0;
          updated['bids_per_month'] = int.tryParse(c.text) ?? 0;
          updated['can_publish_external'] = external;
          updated['publish_cost_points'] = int.tryParse(d.text) ?? 0;
          updated['publish_cost_gems'] = int.tryParse(e.text) ?? 0;
        }
        updated['updated_at'] = DateTime.now().toUtc().toIso8601String();
        try {
          if (reel) await repo.updateReelRule(updated);
          if (!reel) await repo.updateTenderRule(updated);
          if (ctx.mounted) Navigator.pop(ctx);
          await _load();
        } catch (e) { if (mounted) _snack(_friendly(e)); }
      }, child: const Text('حفظ'))],
    )));
    a.dispose(); b.dispose(); c.dispose(); d.dispose(); e.dispose();
  }

  Future<void> _editReel(Map<String,dynamic> row) async {
    final title=TextEditingController(text: row['title']?.toString()??'');
    final desc=TextEditingController(text: row['description']?.toString()??'');
    final city=TextEditingController(text: row['city']?.toString()??'');
    final duration=TextEditingController(text: row['duration_seconds']?.toString()??'30');
    final price=TextEditingController(text: row['price_minor_units']?.toString()??'');
    final tags=TextEditingController(text: ((row['tags'] as List?)??const []).map((e)=>e.toString()).join(','));
    var pinned=row['is_pinned']==true;
    var featured=row['is_featured']==true;
    var published=row['is_published']!=false;
    var blocked=row['is_blocked']==true;
    var allowDownload=row['allow_download']==true;
    var score=int.tryParse(row['promotion_score']?.toString()??'0')??0;
    PlatformFile? video;
    PlatformFile? cover;
    String? sector=row['sector_key']?.toString();
    try {
      final sectors=await repo.sectors();
      if (!mounted) return;
      if (sector==null || !sectors.any((e)=>e['sector_key']?.toString()==sector)) sector=sectors.isEmpty?null:sectors.first['sector_key']?.toString();
      await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
        title:Text('تحكم المالك — ${row['id']}'),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان الريلز')),
          TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
          Row(children:[Expanded(child:TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المدة بالثواني'))),const SizedBox(width:8),Expanded(child:TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر')))]),
          TextField(controller:city,decoration:const InputDecoration(labelText:'المدينة')),
          DropdownButtonFormField<String>(initialValue:sector,decoration:const InputDecoration(labelText:'القطاع'),items:sectors.map((e)=>DropdownMenuItem(value:e['sector_key']?.toString(),child:Text(e['name_ar']?.toString()??''))).toList(),onChanged:(v)=>setDialog(()=>sector=v)),
          TextField(controller:tags,decoration:const InputDecoration(labelText:'الوسوم')),
          Slider(value:score.toDouble(),min:0,max:100,divisions:20,label:'$score/100',onChanged:(v)=>setDialog(()=>score=v.round())),
          Wrap(spacing:4,children:[
            FilterChip(selected:pinned,label:const Text('مثبت'),onSelected:(v)=>setDialog(()=>pinned=v)),
            FilterChip(selected:featured,label:const Text('مميز'),onSelected:(v)=>setDialog(()=>featured=v)),
            FilterChip(selected:published,label:const Text('منشور'),onSelected:(v)=>setDialog(()=>published=v)),
            FilterChip(selected:blocked,label:const Text('محجوب'),onSelected:(v)=>setDialog(()=>blocked=v)),
            FilterChip(selected:allowDownload,label:const Text('تحميل مسموح'),onSelected:(v)=>setDialog(()=>allowDownload=v)),
          ]),
          const SizedBox(height:8),
          Row(children:[Expanded(child:OutlinedButton.icon(onPressed:() async { video=await repo.pickVideo(); if(ctx.mounted)setDialog((){}); },icon:const Icon(Icons.video_library_outlined),label:Text(video?.name??'استبدال الفيديو'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:() async { cover=await repo.pickImage(); if(ctx.mounted)setDialog((){}); },icon:const Icon(Icons.image_outlined),label:Text(cover?.name??'استبدال الغلاف')))]),
          const SizedBox(height:5),
          const Text('',style:TextStyle(color:Colors.white60,fontSize:11)),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:() async {
          try {
            String? vp=row['video_url']?.toString(); String? cp=row['thumbnail_url']?.toString();
            if(video!=null) vp=await repo.uploadReelVideo(video!);
            if(cover!=null) cp=await repo.uploadReelCover(cover!);
            await repo.updateOwnerReelControl(reelId:row['id'].toString(),title:title.text.trim(),description:desc.text.trim(),videoUrl:vp,durationSeconds:int.tryParse(duration.text)??30,thumbnailUrl:cp,sectorKey:sector,priceMinorUnits:int.tryParse(price.text),city:city.text.trim(),tags:tags.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList(),allowDownload:allowDownload,published:published,blocked:blocked,pinned:pinned,featured:featured,promotionScore:score);
            if(ctx.mounted)Navigator.pop(ctx); await _load();
          }catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(_friendly(e))));}
        },child:const Text('حفظ'))],
      )));
    } finally { title.dispose(); desc.dispose(); city.dispose(); duration.dispose(); price.dispose(); tags.dispose(); }
  }

  Widget _wallpaperAdmin() {
    return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[const Expanded(child:Text('خلفيات الشات',style:TextStyle(fontWeight:FontWeight.w900,fontSize:20))),FilledButton.icon(onPressed:()=>_editWallpaper(null),icon:const Icon(Icons.add_rounded),label:const Text('إضافة'))]),
      const SizedBox(height:8),
      const Text('',style:TextStyle(color:Colors.white60,fontSize:12)),
      const SizedBox(height:12),
      ...wallpapers.map((w)=>Card(child:ListTile(
        leading:Container(width:52,height:52,decoration:BoxDecoration(borderRadius:BorderRadius.circular(10),gradient:LinearGradient(colors:[_color(w['color1']),_color(w['color2'])]))),
        title:Text('${w['name_ar']}  •  ${w['wallpaper_key']}'),
        subtitle:Text('${w['is_premium']==true?'VIP':'مجاني'}  •  ${w['price_points']} نقطة  •  ${w['is_active']==true?'نشط':'متوقف'}  •  ترتيب ${w['sort_order']}'),
        trailing:Wrap(children:[IconButton(onPressed:()=>_editWallpaper(w),icon:const Icon(Icons.edit_rounded)),IconButton(onPressed:() async { try{await repo.deleteWallpaper(w['wallpaper_key'].toString());await _load();}catch(e){if(mounted)_snack(_friendly(e));}},icon:const Icon(Icons.visibility_off_outlined))]),
      )))
    ]));
  }

  Color _color(dynamic v){ final s=v?.toString().replaceFirst('#','')??'111827'; final h=s.length==6?'FF$s':s; final n=int.tryParse(h,radix:16); return n==null?Colors.black:Color(n); }

  Future<void> _editWallpaper(Map<String,dynamic>? row) async {
    final key=TextEditingController(text:row?['wallpaper_key']?.toString()??'');
    final name=TextEditingController(text:row?['name_ar']?.toString()??'');
    final c1=TextEditingController(text:row?['color1']?.toString()??'#0F172A');
    final c2=TextEditingController(text:row?['color2']?.toString()??'#1E293B');
    final image=TextEditingController(text:row?['image_url']?.toString()??'');
    final price=TextEditingController(text:row?['price_points']?.toString()??'0');
    final order=TextEditingController(text:row?['sort_order']?.toString()??'250');
    var premium=row?['is_premium']==true; var active=row?['is_active']!=false; var kind=row?['kind']?.toString()??'gradient'; if(!const {'solid','gradient','image'}.contains(kind)) kind='gradient';
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:Text(row==null?'إضافة خلفية':'تعديل الخلفية'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:key,enabled:row==null,decoration:const InputDecoration(labelText:'مفتاح الخلفية')),
      TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم العربي')),
      DropdownButtonFormField<String>(initialValue:kind,items:const [DropdownMenuItem(value:'solid',child:Text('لون واحد')),DropdownMenuItem(value:'gradient',child:Text('تدرج')),DropdownMenuItem(value:'image',child:Text('صورة'))],onChanged:(v)=>setDialog(()=>kind=v??kind),decoration:const InputDecoration(labelText:'النوع')),
      Row(children:[Expanded(child:TextField(controller:c1,decoration:const InputDecoration(labelText:'اللون 1'))),const SizedBox(width:8),Expanded(child:TextField(controller:c2,decoration:const InputDecoration(labelText:'اللون 2')))]),
      TextField(controller:image,maxLines:2,decoration:const InputDecoration(labelText:'رابط الصورة (اختياري)')),
      FilledButton.tonalIcon(onPressed:() async { try{final f=await repo.pickImage(); if(f==null)return; final u=await repo.uploadChatWallpaper(f); image.text=u; if(ctx.mounted)setDialog((){});}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(_friendly(e))));}},icon:const Icon(Icons.upload_file_rounded),label:const Text('رفع صورة للكتالوج')),
      TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر بالنقاط')),
      TextField(controller:order,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الترتيب')),
      SwitchListTile(value:premium,onChanged:(v)=>setDialog(()=>premium=v),title:const Text('VIP')),
      SwitchListTile(value:active,onChanged:(v)=>setDialog(()=>active=v),title:const Text('نشطة')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:() async { try{await repo.upsertWallpaper(key:key.text.trim(),nameAr:name.text.trim(),scope:'both',kind:kind,color1:c1.text.trim(),color2:c2.text.trim(),imageUrl:image.text.trim().isEmpty?null:image.text.trim(),premium:premium,pricePoints:int.tryParse(price.text)??0,active:active,sortOrder:int.tryParse(order.text)??250);if(ctx.mounted)Navigator.pop(ctx);await _load();}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(_friendly(e))));}},child:const Text('حفظ'))])));
    key.dispose();name.dispose();c1.dispose();c2.dispose();image.dispose();price.dispose();order.dispose();
  }

  Future<void> _createOwnerReel() async {
    final sectors=await repo.sectors();
    if (!mounted) return;
    if (sectors.isEmpty) { _snack('لا توجد قطاعات فعالة.'); return; }
    final title=TextEditingController(); final desc=TextEditingController(); final duration=TextEditingController(text:'30');
    final price=TextEditingController(); final city=TextEditingController(); final tags=TextEditingController();
    String? sector=sectors.first['sector_key']?.toString(); PlatformFile? video; PlatformFile? cover; var allowDownload=true;
    await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:const Text('رفع ريل جديد — المالك'),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'عنوان المنتج')),
        TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
        Row(children:[Expanded(child:TextField(controller:duration,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'المدة بالثواني'))),const SizedBox(width:8),Expanded(child:TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر')))]),
        TextField(controller:city,decoration:const InputDecoration(labelText:'المدينة')),
        DropdownButtonFormField<String>(initialValue:sector,items:sectors.map((e)=>DropdownMenuItem(value:e['sector_key']?.toString(),child:Text(e['name_ar']?.toString()??''))).toList(),onChanged:(v)=>setDialog(()=>sector=v),decoration:const InputDecoration(labelText:'القطاع')),
        TextField(controller:tags,decoration:const InputDecoration(labelText:'الوسوم')),
        Row(children:[Expanded(child:OutlinedButton.icon(onPressed:() async {video=await repo.pickVideo();if(ctx.mounted)setDialog((){});},icon:const Icon(Icons.video_file_rounded),label:Text(video?.name??'اختيار الفيديو'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:() async {cover=await repo.pickImage();if(ctx.mounted)setDialog((){});},icon:const Icon(Icons.image_outlined),label:Text(cover?.name??'الغلاف')))]),
        SwitchListTile(value:allowDownload,onChanged:(v)=>setDialog(()=>allowDownload=v),contentPadding:EdgeInsets.zero,title:const Text('السماح بالتحميل')),
        const Text('',style:TextStyle(color:Colors.white60,fontSize:11)),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton.icon(onPressed:video==null?null:() async {try{if(title.text.trim().isEmpty) { _snack('اكتب عنوان المنتج قبل رفع الفيديو.'); return; } final parsedDuration=int.tryParse(duration.text)??0; if(parsedDuration<=0){ _snack('مدة الفيديو يجب أن تكون أكبر من صفر.'); return; } final vp=await repo.uploadReelVideo(video!);String? cp;if(cover!=null)cp=await repo.uploadReelCover(cover!);await repo.publishReel(title:title.text.trim(),description:desc.text.trim(),duration:parsedDuration,videoPath:vp,coverPath:cp,allowDownload:allowDownload,sector:sector!,priceLabel:price.text.trim().isEmpty?null:price.text.trim(),city:city.text.trim(),tags:tags.text.split(',').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList());if(ctx.mounted)Navigator.pop(ctx);await _load();}catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(_friendly(e))));}},icon:const Icon(Icons.cloud_upload_rounded),label:const Text('رفع ونشر'))]
    )));
    title.dispose();desc.dispose();duration.dispose();price.dispose();city.dispose();tags.dispose();
  }

  Widget _garmentServicesAdmin() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('خدمات الألبسة والرسوم — تحكم المالك', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          const Text(''),
          const SizedBox(height: 12),
          ...publicationFees.map((row) => Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_rounded, color: AppColors.gold),
                  title: Text(_publicationLabel(row['content_type']?.toString())),
                  subtitle: Text('${row['points_cost'] ?? 0} نقطة + ${row['gems_cost'] ?? 0} جوهرة • ${row['is_enabled'] == true ? 'مفعّل' : 'متوقف'}'),
                  trailing: IconButton(onPressed: () => _editGarmentPublicationFee(row), icon: const Icon(Icons.edit_rounded)),
                ),
              )),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('كتالوج خدمات الألبسة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
            FilledButton.icon(onPressed: () => _editGarmentService(null), icon: const Icon(Icons.add_rounded), label: const Text('إضافة نوع')),
          ]),
          const SizedBox(height: 8),
          ...garmentServices.map((row) => Card(
                child: ListTile(
                  leading: Icon(Icons.checkroom_rounded, color: row['is_active'] == true ? AppColors.gold : Colors.white54),
                  title: Text(row['name_ar']?.toString() ?? row['service_key']?.toString() ?? 'خدمة'),
                  subtitle: Text('${row['sector_key'] ?? ''} • ${row['is_active'] == true ? 'نشطة' : 'متوقفة'} • ترتيب ${row['sort_order'] ?? 0}'),
                  trailing: IconButton(onPressed: () => _editGarmentService(row), icon: const Icon(Icons.edit_rounded)),
                ),
              )),
        ],
      ),
    );
  }

  String _publicationLabel(String? key) => switch (key) {
        'garment_business' => 'نشر النشاط التجاري',
        'garment_product' => 'نشر المنتج',
        'garment_service' => 'نشر خدمة الألبسة',
        _ => key ?? 'رسوم النشر',
      };

  Future<void> _editGarmentPublicationFee(Map<String, dynamic> row) async {
    final points = TextEditingController(text: row['points_cost']?.toString() ?? '0');
    final gems = TextEditingController(text: row['gems_cost']?.toString() ?? '0');
    var enabled = row['is_enabled'] != false;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: Text('رسوم ${_publicationLabel(row['content_type']?.toString())}'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'نقاط')),
              TextField(controller: gems, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'جواهر')),
              SwitchListTile(value: enabled, onChanged: (v) => setDialog(() => enabled = v), title: const Text('تفعيل الرسم')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    await repo.adminUpsertGarmentPublicationFee(
                      contentType: row['content_type']?.toString() ?? 'garment_service',
                      pointsCost: int.tryParse(points.text) ?? 0,
                      gemsCost: int.tryParse(gems.text) ?? 0,
                      enabled: enabled,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) { if (ctx.mounted) _snack(_friendly(e)); }
                },
                child: const Text('حفظًا'),
              ),
            ],
          ),
        ),
      );
    } finally { points.dispose(); gems.dispose(); }
  }

  Future<void> _editGarmentService(Map<String, dynamic>? row) async {
    final key = TextEditingController(text: row?['service_key']?.toString() ?? '');
    final sector = TextEditingController(text: row?['sector_key']?.toString() ?? 'tailoring');
    final name = TextEditingController(text: row?['name_ar']?.toString() ?? '');
    final description = TextEditingController(text: row?['description_ar']?.toString() ?? '');
    final icon = TextEditingController(text: row?['icon_key']?.toString() ?? 'checkroom');
    final order = TextEditingController(text: row?['sort_order']?.toString() ?? '250');
    var active = row?['is_active'] != false;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: Text(row == null ? 'إضافة نوع خدمة' : 'تعديل خدمة الألبسة'),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: key, enabled: row == null, decoration: const InputDecoration(labelText: 'مفتاح الخدمة')),
              TextField(controller: sector, decoration: const InputDecoration(labelText: 'القطاع')),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم العربي')),
              TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
              TextField(controller: icon, decoration: const InputDecoration(labelText: 'مفتاح الأيقونة')),
              TextField(controller: order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الترتيب')),
              SwitchListTile(value: active, onChanged: (v) => setDialog(() => active = v), title: const Text('نشطة')),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () async {
                  try {
                    await repo.adminUpsertGarmentServiceCatalog(
                      serviceKey: key.text.trim(),
                      sectorKey: sector.text.trim(),
                      nameAr: name.text.trim(),
                      descriptionAr: description.text.trim(),
                      iconKey: icon.text.trim(),
                      active: active,
                      sortOrder: int.tryParse(order.text) ?? 0,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  } catch (e) { if (ctx.mounted) _snack(_friendly(e)); }
                },
                child: const Text('حفظًا'),
              ),
            ],
          ),
        ),
      );
    } finally { key.dispose(); sector.dispose(); name.dispose(); description.dispose(); icon.dispose(); order.dispose(); }
  }

  Widget _procurementAdmin() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children:[const Expanded(child:Text('الريلز والمناقصات — تحكم المالك',style:TextStyle(fontWeight:FontWeight.w900,fontSize:20))),FilledButton.icon(onPressed:_createOwnerReel,icon:const Icon(Icons.add_rounded),label:const Text('رفع ريل جديد'))]),
        const SizedBox(height: 10),
        ...reels.take(50).map((r) => _ModerationCard(title: 'ريلز: ${r['title']}', status: r['is_blocked'] == true ? 'محجوب' : (r['is_featured'] == true ? 'مميز • إبراز ${r['promotion_score'] ?? 0}/100' : 'ظاهر • إبراز ${r['promotion_score'] ?? 0}/100'), icon: Icons.video_library_outlined, blocked: r['is_blocked'] == true, onEdit: () => _editReel(r), onToggle: () async { await repo.setReelBlocked(r['id'].toString(), r['is_blocked'] != true); await _load(); }, onDelete: () async { await repo.deleteReel(r['id'].toString()); await _load(); })),
        const Divider(height: 34),
        ...tenders.take(40).map((t) => _ModerationCard(title: '${t['scope'] == 'external' ? 'خارجي' : 'مناقصة'}: ${t['title']}', status: t['is_blocked'] == true ? 'محجوب' : 'ظاهر', icon: Icons.gavel_outlined, blocked: t['is_blocked'] == true, onToggle: () async { await repo.setTenderBlocked(t['id'].toString(), t['is_blocked'] != true); await _load(); }, onDelete: () async { await repo.deleteTender(t['id'].toString()); await _load(); })),
      ]),
    );
  }

  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  String _friendly(Object e) => e.toString().replaceFirst('PostgrestException(message: ', '').replaceFirst(RegExp(r', code:.*'), '').replaceAll('Exception: ', '');
}

class _SectionCard extends StatelessWidget {
  final String title; final IconData icon; final List<Widget> children;
  const _SectionCard({required this.title, required this.icon, required this.children});
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppColors.gold), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 12), ...children])));
}

class _ModerationCard extends StatelessWidget {
  final String title; final String status; final IconData icon; final bool blocked; final Future<void> Function() onToggle; final Future<void> Function() onDelete; final Future<void> Function()? onEdit;
  const _ModerationCard({required this.title, required this.status, required this.icon, required this.blocked, required this.onToggle, required this.onDelete, this.onEdit});
  @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, color: blocked ? AppColors.error : AppColors.gold), title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text(status), trailing: Wrap(children: [if(onEdit!=null) IconButton(onPressed:onEdit, icon:const Icon(Icons.edit_rounded)), IconButton(onPressed: onToggle, icon: Icon(blocked ? Icons.visibility_rounded : Icons.block_rounded)), IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded))])));
}
