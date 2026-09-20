import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/producer_market_repository.dart';

class ProcurementHubPage extends StatefulWidget {
  final String initialScope;
  const ProcurementHubPage({super.key, this.initialScope = 'domestic'});
  @override
  State<ProcurementHubPage> createState() => _ProcurementHubPageState();
}

class _ProcurementHubPageState extends State<ProcurementHubPage> with SingleTickerProviderStateMixin {
  final repo = ProducerMarketRepository.instance;
  late final TabController tabs;
  bool loading = true;
  Map<String, dynamic> quota = {};
  List<Map<String, dynamic>> domestic = [];
  List<Map<String, dynamic>> external = [];

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialScope == 'external' ? 1 : 0);
    _load();
  }

  @override
  void dispose() { tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final result = await Future.wait([repo.tenderQuota(), repo.tenders(scope: 'domestic'), repo.tenders(scope: 'external')]);
      if (!mounted) return;
      setState(() { quota = Map<String, dynamic>.from(result[0] as Map); domestic = List<Map<String, dynamic>>.from(result[1] as List); external = List<Map<String, dynamic>>.from(result[2] as List); loading = false; });
    } catch (e) {
      if (mounted) { setState(() => loading = false); _snack(_friendly(e)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.gavel_rounded, color: AppColors.gold), SizedBox(width: 8), Text('المناقصات والتجارة الخارجية')]),
        bottom: TabBar(controller: tabs, tabs: const [Tab(icon: Icon(Icons.factory_outlined), text: 'المناقصات'), Tab(icon: Icon(Icons.public_rounded), text: 'الطلبات الخارجية')]),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: tabs, children: [_scopeView('domestic'), _scopeView('external')]),
      floatingActionButton: FloatingActionButton.extended(heroTag: 'procurement_create_tender', onPressed: () => _create(tabs.index == 1 ? 'external' : 'domestic'), icon: const Icon(Icons.add_rounded), label: Text(tabs.index == 1 ? 'طلب خارجي جديد' : 'مناقصة جديدة')),
    );
  }

  Widget _scopeView(String scope) {
    final rows = scope == 'external' ? external : domestic;
    final externalAllowed = quota['unlimited'] == true || quota['can_publish_external'] == true;
    final remaining = scope == 'external' ? quota['external_remaining'] : quota['domestic_remaining'];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 100), children: [
        _QuotaBanner(scope: scope, quota: quota, remaining: remaining),
        if (scope == 'external' && !externalAllowed) const _RestrictionCard(text: 'الطلبات الخارجية تبدأ من العضوية الفضية فصاعدًا.'),
        const SizedBox(height: 10),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Column(children: [Icon(Icons.inbox_outlined, size: 54, color: AppColors.gold), SizedBox(height: 10), Text('لا توجد طلبات منشورة حاليًا.'), SizedBox(height: 4), Text('أنشئ أول فرصة لقطاع الألبسة.', style: TextStyle(color: Colors.white60))])),
        ...rows.map((row) => _TenderCard(tender: row, onTap: () => _details(row))),
      ]),
    );
  }

  Future<void> _create(String scope) async {
    final sectorRows = await repo.sectors();
    if (!mounted) return;
    if (sectorRows.isEmpty) {
      _snack('لا توجد قطاعات فعالة على الخادم للنشر.');
      return;
    }
    final title = TextEditingController();
    final description = TextEditingController();
    var selectedSector = sectorRows.first['sector_key']?.toString() ?? '';
    final quantity = TextEditingController();
    final unit = TextEditingController(text: 'قطعة');
    final budgetMin = TextEditingController();
    final budgetMax = TextEditingController();
    final city = TextEditingController();
    final country = TextEditingController();
    final incoterm = TextEditingController(text: 'FOB');
    final shipping = TextEditingController(text: 'بحري / جوي');
    final customs = TextEditingController();
    final payment = TextEditingController(text: 'اعتماد / تحويل بنكي');
    final certificates = TextEditingController();
    final packaging = TextEditingController();
    final sampleDetails = TextEditingController();
    final specs = TextEditingController();
    var sample = false;
    var publicationCurrency = 'points';
    final List<PlatformFile> attachmentFiles = [];
    DateTime? deadline;
    DateTime? deliveryDeadline;
    final isExternal = scope == 'external';
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Row(children: [Icon(isExternal ? Icons.public_rounded : Icons.gavel_rounded, color: AppColors.gold), const SizedBox(width: 8), Text(isExternal ? 'طلب خارجي — خارج سورية' : 'مناقصة جديدة')]),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('حصة النشر المتبقية: ${isExternal ? (quota['external_remaining'] ?? 0) : (quota['domestic_remaining'] ?? 0)}', style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 10),
        _tf(title, 'عنوان الفرصة', Icons.title_rounded),
        _tf(description, 'الوصف الكامل والمواصفات المطلوبة', Icons.description_outlined, max: 5),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: sectorRows.any((row) => row['sector_key']?.toString() == selectedSector) ? selectedSector : null,
            decoration: const InputDecoration(labelText: 'قطاع الألبسة', prefixIcon: Icon(Icons.category_outlined)),
            items: [for (final row in sectorRows) DropdownMenuItem<String>(
              value: row['sector_key']?.toString(),
              child: Text(row['name_ar']?.toString() ?? row['sector_key']?.toString() ?? ''),
            )],
            onChanged: (v) { if (v != null) setDialog(() => selectedSector = v); },
          )),
          const SizedBox(width: 8),
          Expanded(child: _tf(unit, 'الوحدة', Icons.straighten_outlined)),
        ]),
        Row(children: [Expanded(child: _tf(quantity, 'الكمية', Icons.numbers_rounded, number: true)), const SizedBox(width: 8), Expanded(child: _tf(city, isExternal ? 'مدينة التسليم في الخارج' : 'مدينة التسليم داخل سورية', Icons.location_on_outlined))]),
        Row(children: [Expanded(child: _tf(budgetMin, 'الميزانية الدنيا', Icons.arrow_downward_rounded, number: true)), const SizedBox(width: 8), Expanded(child: _tf(budgetMax, 'الميزانية العليا', Icons.arrow_upward_rounded, number: true))]),
        if (isExternal) ...[
          _tf(country, 'الدولة المطلوبة', Icons.flag_outlined),
          _tf(incoterm, 'الإنكوترم (EXW / FOB / CIF ...)', Icons.local_shipping_outlined),
          _tf(shipping, 'طريقة الشحن', Icons.flight_takeoff_outlined),
          _tf(customs, 'من يتولى الجمارك؟', Icons.assignment_rounded),
          _tf(payment, 'شروط الدفع', Icons.payments_outlined, max: 3),
          _tf(certificates, 'الشهادات المطلوبة (مفصولة بفواصل)', Icons.verified_outlined, max: 3),
          _tf(packaging, 'متطلبات التغليف والتوسيم', Icons.inventory_2_outlined, max: 3),
        ] else ...[
          _tf(specs, 'الخامة / القياسات / اللون / الجودة / أي تفاصيل فنية', Icons.straighten_rounded, max: 5),
          _tf(packaging, 'التعبئة والتغليف', Icons.inventory_2_outlined, max: 3),
        ],
        SwitchListTile(contentPadding: EdgeInsets.zero, value: sample, onChanged: (v) => setDialog(() => sample = v), title: const Text('طلب عيّنة قبل التوريد')),
        if (sample) _tf(sampleDetails, 'تفاصيل العيّنة ومعايير قبولها', Icons.science_outlined, max: 3),
        const SizedBox(height: 5),
        OutlinedButton.icon(onPressed: () async { final file = await repo.pickAttachment(); if (file != null) setDialog(() => attachmentFiles.add(file)); }, icon: const Icon(Icons.attach_file_rounded), label: const Text('إرفاق كتالوج / مواصفات / PDF / صورة')),
        if (attachmentFiles.isNotEmpty) ...[const SizedBox(height: 5), Wrap(spacing: 6, runSpacing: 6, children: [for (final file in attachmentFiles) Chip(avatar: const Icon(Icons.insert_drive_file_outlined, size: 15), label: Text(file.name, overflow: TextOverflow.ellipsis), onDeleted: () => setDialog(() => attachmentFiles.remove(file)))])],
        const SizedBox(height: 5),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رسوم نشر الفرصة', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${quota['publish_cost_points'] ?? 0} نقطة • ${quota['publish_cost_gems'] ?? 0} جوهرة', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'points', label: Text('نقاط')),
                  ButtonSegment<String>(value: 'gems', label: Text('جواهر')),
                ],
                selected: {publicationCurrency},
                onSelectionChanged: (value) => setDialog(() => publicationCurrency = value.first),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 5),
        OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: DateTime.now().add(const Duration(days: 7))); if (d != null) setDialog(() => deadline = d); }, icon: const Icon(Icons.event_outlined), label: Text(deadline == null ? 'تحديد آخر موعد لتلقي العروض' : 'موعد العروض: ${_date(deadline)}')),
        OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 1095)), initialDate: DateTime.now().add(const Duration(days: 30))); if (d != null) setDialog(() => deliveryDeadline = d); }, icon: const Icon(Icons.local_shipping_outlined), label: Text(deliveryDeadline == null ? 'تحديد موعد التسليم' : 'التسليم: ${_date(deliveryDeadline)}')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton.icon(onPressed: () async {
        try {
          final selectedCost = publicationCurrency == 'points' ? ((quota['publish_cost_points'] as num?)?.toInt() ?? 0) : ((quota['publish_cost_gems'] as num?)?.toInt() ?? 0);
          if (quota['unlimited'] != true && selectedCost <= 0) throw Exception('PUBLICATION_FEE_NOT_CONFIGURED_FOR_CURRENCY');
          if (title.text.trim().isEmpty) throw Exception('TITLE_REQUIRED');
          if (description.text.trim().isEmpty) throw Exception('DESCRIPTION_REQUIRED');
          if (isExternal && (country.text.trim().isEmpty || (quota['can_publish_external'] != true && quota['unlimited'] != true))) throw Exception('EXTERNAL_NOT_ALLOWED');
          final created = await repo.publishTender(scope: scope, title: title.text.trim(), description: description.text.trim(), sector: selectedSector, quantity: int.tryParse(quantity.text), unit: unit.text.trim().isEmpty ? 'قطعة' : unit.text.trim(), budgetMin: int.tryParse(budgetMin.text), budgetMax: int.tryParse(budgetMax.text), city: city.text.trim().isEmpty ? null : city.text.trim(), country: isExternal ? country.text.trim() : null, incoterm: isExternal ? incoterm.text.trim() : null, shipping: isExternal ? shipping.text.trim() : null, customs: isExternal ? customs.text.trim() : null, payment: isExternal ? payment.text.trim() : null, certificates: certificates.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), packaging: packaging.text.trim().isEmpty ? null : packaging.text.trim(), sample: sample, sampleDetails: sample ? sampleDetails.text.trim() : null, technicalSpecs: specs.text.trim().isEmpty ? null : specs.text.trim(), deadline: deadline, deliveryDeadline: deliveryDeadline, publicationCurrency: publicationCurrency);
          final createdId = created['id']?.toString();
          if (createdId != null && attachmentFiles.isNotEmpty) {
            final paths = <String>[];
            for (final file in attachmentFiles) {
              paths.add(await repo.uploadBytes(folder: 'tenders', file: file, extension: (file.extension ?? 'bin').toLowerCase()));
            }
            await repo.updateTender(createdId, {'attachments': paths});
          }
          if (ctx.mounted) Navigator.pop(ctx);
          _snack('تم نشر الفرصة ورفع مرفقاتها تحت تحكم الخادم.');
          await _load();
        } catch (e) { _snack(_friendly(e)); }
      }, icon: const Icon(Icons.publish_rounded), label: const Text('نشر خادميًا'))],
    )));
    for (final c in [title,description,quantity,unit,budgetMin,budgetMax,city,country,incoterm,shipping,customs,payment,certificates,packaging,sampleDetails,specs]) {
      c.dispose();
    }
  }

  Future<void> _details(Map<String, dynamic> tender) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = uid != null && uid == tender['owner_uid'];
    List<Map<String, dynamic>> bids = [];
    try { bids = await repo.bids(tender['id'].toString()); } catch (_) {}
    final existingMine = bids.where((b) => b['bidder_uid']?.toString() == uid).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: AppColors.surface, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: SizedBox(height: MediaQuery.sizeOf(context).height * .88, child: _TenderDetails(tender: tender, owner: isOwner, bids: bids, myBid: existingMine.isEmpty ? null : existingMine.first, onRefresh: _load, repo: repo))));
  }

  Widget _tf(TextEditingController c, String label, IconData icon, {int max = 1, bool number = false}) => Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c, maxLines: max, keyboardType: number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon))));
  static String _date(DateTime? value) => value == null ? '' : value.toLocal().toString().split(' ').first;
  void _snack(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }
  String _friendly(Object e) => e.toString().replaceFirst('PostgrestException(message: ', '').replaceFirst(RegExp(r', code:.*'), '').replaceAll('Exception: ', '');
}

class _QuotaBanner extends StatelessWidget {
  final String scope; final Map<String, dynamic> quota; final dynamic remaining;
  const _QuotaBanner({required this.scope, required this.quota, required this.remaining});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1E1B14), Color(0xFF321C28)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.gold.withValues(alpha: .3))), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.gold.withValues(alpha: .15)), child: Icon(scope == 'external' ? Icons.public_rounded : Icons.gavel_rounded, color: AppColors.gold)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(scope == 'external' ? 'طلبات تصدير خارج سورية' : 'مناقصات قطاع الألبسة', style: const TextStyle(fontWeight: FontWeight.w900)), Text(quota['unlimited'] == true ? 'مالك المنصة — بلا حدود' : 'المتبقي هذا الشهر: ${remaining ?? 0} • العروض: ${quota['bids_remaining'] ?? 0}', style: const TextStyle(color: Colors.white60, fontSize: 12))]))]));
}
class _RestrictionCard extends StatelessWidget { final String text; const _RestrictionCard({required this.text}); @override Widget build(BuildContext context) => Card(color: AppColors.burgundy.withValues(alpha: .18), child: ListTile(leading: const Icon(Icons.lock_outline_rounded, color: AppColors.warning), title: const Text('ميزة حسب العضوية'), subtitle: Text(text))); }

class _TenderCard extends StatelessWidget {
  final Map<String, dynamic> tender; final VoidCallback onTap;
  const _TenderCard({required this.tender, required this.onTap});
  @override Widget build(BuildContext context) {
    final external = tender['scope'] == 'external';
    final awarded = tender['status'] == 'awarded';
    return Card(margin: const EdgeInsets.only(bottom: 10), clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: external ? const Color(0xFF123B4C) : const Color(0xFF342613), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(external ? Icons.public_rounded : Icons.gavel_rounded, size: 14, color: AppColors.gold), const SizedBox(width: 5), Text(external ? 'طلب خارجي' : 'مناقصة', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))])), const Spacer(), if (awarded) const Icon(Icons.emoji_events_rounded, color: AppColors.gold)],), const SizedBox(height: 8), Text(tender['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 5), Text(tender['description']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 10), Wrap(spacing: 7, runSpacing: 7, children: [if (tender['quantity'] != null) _chip(Icons.numbers_rounded, '${tender['quantity']} ${tender['unit'] ?? 'قطعة'}'), if (external && tender['target_country'] != null) _chip(Icons.flag_outlined, tender['target_country'].toString()), if (external && tender['incoterm'] != null) _chip(Icons.local_shipping_outlined, tender['incoterm'].toString()), if (tender['city'] != null) _chip(Icons.location_on_outlined, tender['city'].toString()), _chip(Icons.markunread_mailbox_outlined, '${tender['bids_count'] ?? 0} عروض')]),]))));
  }
  static Widget _chip(IconData icon, String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: AppColors.gold), const SizedBox(width: 4), Text(text, style: const TextStyle(fontSize: 10))]));
}

class _TenderDetails extends StatefulWidget {
  final Map<String, dynamic> tender; final bool owner; final List<Map<String, dynamic>> bids; final Map<String, dynamic>? myBid; final VoidCallback onRefresh; final ProducerMarketRepository repo;
  const _TenderDetails({required this.tender, required this.owner, required this.bids, required this.myBid, required this.onRefresh, required this.repo});
  @override State<_TenderDetails> createState() => _TenderDetailsState();
}
class _TenderDetailsState extends State<_TenderDetails> {
  bool busy = false;
  Future<void> _bid() async {
    final price = TextEditingController(); final days = TextEditingController(); final notes = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('تقديم عرض سري'), content: SingleChildScrollView(child: Column(children: [TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر', prefixIcon: Icon(Icons.payments_outlined))), TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مدة التسليم بالأيام')), TextField(controller: notes, maxLines: 4, decoration: const InputDecoration(labelText: 'الملاحظات والشروط'))])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () async { try { setState(() => busy = true); await widget.repo.submitBid(tenderId: widget.tender['id'].toString(), price: int.tryParse(price.text) ?? 0, deliveryDays: int.tryParse(days.text), notes: notes.text.trim()); if (ctx.mounted) Navigator.pop(ctx); if (mounted) { widget.onRefresh(); Navigator.pop(context); } } catch (e) { if (mounted) _snack(e.toString()); } finally { if (mounted) setState(() => busy = false); } }, child: const Text('إرسال العرض'))]));
    price.dispose(); days.dispose(); notes.dispose();
  }
  Future<void> _award(String bidId) async { try { setState(() => busy = true); await widget.repo.awardTender(widget.tender['id'].toString(), bidId); widget.onRefresh(); if (mounted) _snack('تمت الترسية؛ رُفضت العروض الأخرى وأُرسل إشعار للفائز.'); } catch (e) { _snack(e.toString()); } finally { if (mounted) setState(() => busy = false); } }

  Future<void> _editTender() async {
    final t = widget.tender;
    final title = TextEditingController(text: t['title']?.toString() ?? '');
    final description = TextEditingController(text: t['description']?.toString() ?? '');
    final quantity = TextEditingController(text: t['quantity']?.toString() ?? '');
    final budgetMin = TextEditingController(text: t['budget_min_minor_units']?.toString() ?? '');
    final budgetMax = TextEditingController(text: t['budget_max_minor_units']?.toString() ?? '');
    final city = TextEditingController(text: t['city']?.toString() ?? '');
    final country = TextEditingController(text: t['target_country']?.toString() ?? '');
    final incoterm = TextEditingController(text: t['incoterm']?.toString() ?? '');
    final shipping = TextEditingController(text: t['shipping_method']?.toString() ?? '');
    final customs = TextEditingController(text: t['customs_handled_by']?.toString() ?? '');
    final payment = TextEditingController(text: t['payment_terms']?.toString() ?? '');
    final packaging = TextEditingController(text: t['packaging_requirements']?.toString() ?? '');
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('تعديل الفرصة خادميًا'), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(children: [
      TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
      TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'الوصف')),
      Row(children: [Expanded(child: TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))), const SizedBox(width: 8), Expanded(child: TextField(controller: city, decoration: const InputDecoration(labelText: 'المدينة')))]),
      Row(children: [Expanded(child: TextField(controller: budgetMin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الميزانية الدنيا'))), const SizedBox(width: 8), Expanded(child: TextField(controller: budgetMax, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الميزانية العليا')))]),
      if (t['scope'] == 'external') ...[
        TextField(controller: country, decoration: const InputDecoration(labelText: 'الدولة')),
        TextField(controller: incoterm, decoration: const InputDecoration(labelText: 'الإنكوترم')),
        TextField(controller: shipping, decoration: const InputDecoration(labelText: 'طريقة الشحن')),
        TextField(controller: customs, decoration: const InputDecoration(labelText: 'مسؤول الجمارك')),
        TextField(controller: payment, maxLines: 2, decoration: const InputDecoration(labelText: 'شروط الدفع')),
        TextField(controller: packaging, maxLines: 2, decoration: const InputDecoration(labelText: 'متطلبات التغليف')),
      ],
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () async {
      try {
        setState(() => busy = true);
        await widget.repo.updateTender(t['id'].toString(), {
          'title': title.text.trim(), 'description': description.text.trim(), 'quantity': int.tryParse(quantity.text),
          'budget_min_minor_units': int.tryParse(budgetMin.text), 'budget_max_minor_units': int.tryParse(budgetMax.text), 'city': city.text.trim(),
          if (t['scope'] == 'external') 'target_country': country.text.trim(),
          if (t['scope'] == 'external') 'incoterm': incoterm.text.trim(),
          if (t['scope'] == 'external') 'shipping_method': shipping.text.trim(),
          if (t['scope'] == 'external') 'customs_handled_by': customs.text.trim(),
          if (t['scope'] == 'external') 'payment_terms': payment.text.trim(),
          if (t['scope'] == 'external') 'packaging_requirements': packaging.text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (ctx.mounted) Navigator.pop(ctx);
        widget.onRefresh();
        if (mounted) _snack('تم حفظ التعديلات خادميًا.');
      } catch (e) { _snack(e.toString()); } finally { if (mounted) setState(() => busy = false); }
    }, child: const Text('حفظ'))]));
    for (final c in [title,description,quantity,budgetMin,budgetMax,city,country,incoterm,shipping,customs,payment,packaging]) {
      c.dispose();
    }
  }

  Future<void> _changeStatus(String status) async { try { setState(() => busy = true); await widget.repo.setTenderStatus(widget.tender['id'].toString(), status); widget.onRefresh(); if (mounted) _snack(status == 'closed' ? 'تم إغلاق الفرصة.' : 'تم إلغاء الفرصة.'); } catch (e) { _snack(e.toString()); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _openAttachment(String path) async {
    try {
      final url = await widget.repo.mediaUrl(kind: 'storage', id: widget.tender['id'].toString(), path: path, purpose: 'play');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack(e.toString());
    }
  }
  void _snack(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.replaceAll('Exception: ', '')))); }
  @override Widget build(BuildContext context) { final t = widget.tender; final external = t['scope'] == 'external'; return SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [Center(child: Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)))), const SizedBox(height: 16), Row(children: [Icon(external ? Icons.public_rounded : Icons.gavel_rounded, color: AppColors.gold), const SizedBox(width: 7), Expanded(child: Text(t['title'].toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)))]), const SizedBox(height: 10), Text(t['description']?.toString() ?? '', style: const TextStyle(color: Colors.white70, height: 1.55)), const Divider(height: 28), _detail('القطاع', t['sector_key']), _detail('الكمية', '${t['quantity'] ?? '-'} ${t['unit'] ?? ''}'), _detail('الميزانية', '${t['budget_min_minor_units'] ?? '-'} — ${t['budget_max_minor_units'] ?? '-'} ${t['currency'] ?? ''}'), _detail('المدينة', t['city']), if (external) ...[_detail('الدولة', t['target_country']), _detail('الإنكوترم', t['incoterm']), _detail('الشحن', t['shipping_method']), _detail('الجمارك', t['customs_handled_by']), _detail('الدفع', t['payment_terms']), _detail('الشهادات', (t['required_certificates'] as List?)?.join('، ')), _detail('التغليف', t['packaging_requirements']), _detail('المواصفات الفنية', (t['specs'] as Map?)?['technical']), _detail('تفاصيل العينة', (t['specs'] as Map?)?['sample_details']), _detail('العينة', t['sample_required'] == true ? 'مطلوبة' : 'غير مطلوبة')], if ((t['attachments'] as List?)?.isNotEmpty ?? false) ...[const Text('المرفقات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 6), for (final path in (t['attachments'] as List? ?? const [])) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.attachment_rounded, color: AppColors.gold), title: Text(path.toString().split('/').last), subtitle: const Text('ملف خاص — يُفتح برابط خادمي موقّع'), onTap: () => _openAttachment(path.toString()))], _detail('آخر موعد للعروض', t['deadline_at']), _detail('التسليم', t['delivery_deadline_at']), const SizedBox(height: 18), if (widget.owner) ...[const Text('العروض السرية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 8), if (widget.bids.isEmpty) const Text('لم يصل أي عرض بعد.', style: TextStyle(color: Colors.white60)), ...widget.bids.map((b) => Card(child: ListTile(title: Text('${b['price_minor_units']} ${b['currency'] ?? t['currency'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('التسليم: ${b['delivery_days'] ?? '-'} يوم • ${b['status'] ?? 'submitted'}\n${b['notes'] ?? ''}'), isThreeLine: true, trailing: t['status'] == 'open' && b['status'] == 'submitted' ? IconButton(onPressed: busy ? null : () => _award(b['id'].toString()), icon: const Icon(Icons.emoji_events_rounded, color: AppColors.gold)) : null))), const SizedBox(height: 12), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: busy ? null : _editTender, icon: const Icon(Icons.edit_rounded), label: const Text('تعديل'))), const SizedBox(width: 8), if (t['status'] == 'open') Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => _changeStatus('closed'), icon: const Icon(Icons.lock_outline_rounded), label: const Text('إغلاق'))), if (t['status'] != 'cancelled') Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => _changeStatus('cancelled'), icon: const Icon(Icons.cancel_outlined), label: const Text('إلغاء')))],),] else ...[if (widget.myBid == null && t['status'] == 'open') FilledButton.icon(onPressed: busy ? null : _bid, icon: const Icon(Icons.send_rounded), label: const Text('تقديم عرض سري')), if (widget.myBid != null) Card(child: ListTile(leading: const Icon(Icons.lock_outline_rounded, color: AppColors.gold), title: const Text('عرضك محفوظ وسري'), subtitle: Text('${widget.myBid!['price_minor_units']} ${widget.myBid!['currency'] ?? t['currency'] ?? ''} • ${widget.myBid!['status'] ?? ''}')))], const SizedBox(height: 10), if (t['status'] == 'awarded') const Text('تمت الترسية — النظام يرفض العروض الأخرى تلقائيًا.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700))])); }
  Widget _detail(String label, Object? value) => value == null || value.toString().trim().isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.white54))), Expanded(child: Text(value.toString()))]));
}
