import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GarmentServicesAdminPage extends StatefulWidget {
  const GarmentServicesAdminPage({super.key});
  @override State<GarmentServicesAdminPage> createState() => _GarmentServicesAdminPageState();
}
class _GarmentServicesAdminPageState extends State<GarmentServicesAdminPage> {
  bool loading=true, access=false;
  List<Map<String,dynamic>> catalog=[], fees=[], ads=[];
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {
      final db = Supabase.instance.client;
      final allowed = await db.rpc('has_platform_service_access', params: {'p_service_key': 'garment_market'});
      if (allowed != true) {
        if (mounted) setState(() { loading = false; access = false; });
        return;
      }
      final c = await db.rpc('service_admin_get_garment_service_catalog');
      final f = await db.rpc('service_admin_get_garment_publication_fees');
      final a = await db.from('garment_service_ads')
          .select('id,owner_uid,service_key,sector_key,title,description,price_minor_units,currency,unit,min_qty,city,address,phone,whatsapp,images,specs,status,created_at')
          .order('created_at', ascending: false)
          .limit(250);
      if (!mounted) return;
      setState(() {
        access = true;
        catalog = List<Map<String,dynamic>>.from(c as List);
        fees = List<Map<String,dynamic>>.from(f as List);
        ads = List<Map<String,dynamic>>.from(a as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; access = false; });
      _snack(_friendly(e));
    }
  }
  Future<void> _editFee(Map<String,dynamic> row) async {
    final points=TextEditingController(text:row['points_cost']?.toString()??'0');
    final gems=TextEditingController(text:row['gems_cost']?.toString()??'0');
    var enabled=row['is_enabled']!=false;
    try{
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
        title:Text('رسوم ${row['content_type']}'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:points,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'النقاط')),
          TextField(controller:gems,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الجواهر')),
          SwitchListTile(value:enabled,onChanged:(v)=>setD(()=>enabled=v),title:const Text('مفعّلة')),
        ]),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
      )));
      if(ok!=true)return;
      await Supabase.instance.client.rpc('service_admin_upsert_garment_publication_fee',params:{
        'p_content_type':row['content_type'],'p_points_cost':int.tryParse(points.text)??0,'p_gems_cost':int.tryParse(gems.text)??0,'p_is_enabled':enabled});
      await _load();
    }finally{points.dispose();gems.dispose();}
  }
  Future<void> _editCatalog([Map<String,dynamic>? row]) async {
    final key=TextEditingController(text:row?['service_key']?.toString()??'');
    final sector=TextEditingController(text:row?['sector_key']?.toString()??'');
    final name=TextEditingController(text:row?['name_ar']?.toString()??'');
    final desc=TextEditingController(text:row?['description_ar']?.toString()??'');
    final icon=TextEditingController(text:row?['icon_key']?.toString()??'checkroom');
    final order=TextEditingController(text:row?['sort_order']?.toString()??'100');
    var active=row?['is_active']!=false;
    try{
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
        title:Text(row==null?'إضافة خدمة':'تعديل خدمة'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:key,enabled:row==null,decoration:const InputDecoration(labelText:'مفتاح الخدمة')),
          TextField(controller:sector,decoration:const InputDecoration(labelText:'القطاع')),
          TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),
          TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'الوصف')),
          TextField(controller:icon,decoration:const InputDecoration(labelText:'الأيقونة')),
          TextField(controller:order,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الترتيب')),
          SwitchListTile(value:active,onChanged:(v)=>setD(()=>active=v),title:const Text('نشطة')),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))],
      )));
      if(ok!=true)return;
      await Supabase.instance.client.rpc('service_admin_upsert_garment_service_catalog',params:{
        'p_service_key':key.text.trim(),'p_sector_key':sector.text.trim(),'p_name_ar':name.text.trim(),'p_description_ar':desc.text.trim(),'p_icon_key':icon.text.trim(),'p_is_active':active,'p_sort_order':int.tryParse(order.text)??0});
      await _load();
    } finally { for (final c in [key, sector, name, desc, icon, order]) { c.dispose(); } }
  }
  Future<void> _status(String id,String status) async {
    try{await Supabase.instance.client.rpc('admin_set_garment_service_ad_status',params:{'p_ad_id':id,'p_status':status});await _load();}
    catch(e){_snack(_friendly(e));}
  }
  void _snack(String value){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));}
  String _friendly(Object e)=>e.toString().replaceFirst('PostgrestException(message: ','').replaceFirst(RegExp(r', code:.*'),'').replaceAll('Exception: ','');
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(!access)return const Center(child:Text('صلاحية إدارة خدمات الألبسة غير متاحة.'));
    return RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(14),children:[
      const Text('خدمات الألبسة',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      ...fees.map((f)=>Card(child:ListTile(title:Text(f['content_type']?.toString()??''),subtitle:Text('${f['points_cost']??0} نقطة • ${f['gems_cost']??0} جوهرة • ${f['is_enabled']==true?'مفعّل':'متوقف'}'),trailing:IconButton(onPressed:()=>_editFee(f),icon:const Icon(Icons.payments_outlined))))),
      Row(children:[const Expanded(child:Text('كتالوج الخدمات',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16))),IconButton(onPressed:()=>_editCatalog(),icon:const Icon(Icons.add_rounded))]),
      ...catalog.map((c)=>Card(child:ListTile(title:Text(c['name_ar']?.toString()??''),subtitle:Text('${c['sector_key']??''} • ${c['is_active']==true?'نشطة':'متوقفة'}'),trailing:IconButton(onPressed:()=>_editCatalog(c),icon:const Icon(Icons.edit_rounded))))),
      const SizedBox(height:14),
      Text('الإعلانات • ${ads.length}',style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
      ...ads.map((ad)=>Card(child:ListTile(
        title:Text(ad['title']?.toString()??''),
        subtitle:Text('${ad['service_key']??''} • ${ad['city']??''} • ${ad['status']??''} • ${ad['price_minor_units']??''} ${ad['currency']??''}'),
        trailing:PopupMenuButton<String>(onSelected:(s)=>_status(ad['id'].toString(),s),itemBuilder:(_)=>const[
          PopupMenuItem(value:'published',child:Text('نشر')),PopupMenuItem(value:'paused',child:Text('إيقاف مؤقت')),PopupMenuItem(value:'blocked',child:Text('حظر')),PopupMenuItem(value:'removed',child:Text('إزالة'))])))),
    ]));
  }
}
