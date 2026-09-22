import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/media_upload_service.dart';

enum StoreFeatureType { glow, frame, background }

class PointsStorePage extends StatefulWidget {
  const PointsStorePage({super.key});
  @override State<PointsStorePage> createState() => _PointsStorePageState();
}
class _PointsStorePageState extends State<PointsStorePage> {
  final _db=Supabase.instance.client;
  final _media=MediaUploadService(bucket:'currency-package-media');
  List<Map<String,dynamic>> _rows=[]; bool _owner=false,_loading=true; String _filter='all';
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{
      final owner=await _db.rpc('is_my_platform_owner')==true;
      final rows=await _db.from('currency_packages').select('id,package_type,title,description,amount,bonus_amount,price_minor_units,price_currency,image_url,icon_key,enabled,featured,sort_order,created_at').order('sort_order').order('created_at',ascending:false);
      if(!mounted)return; setState((){_owner=owner;_rows=List<Map<String,dynamic>>.from(rows);_loading=false;});
    }catch(e){if(!mounted)return;setState(()=>_loading=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_friendly(e))));}
  }
  List<Map<String,dynamic>> get _visible=>_rows.where((r)=> (_owner||r['enabled']==true)&&(_filter=='all'||r['package_type']==_filter)).toList();
  Future<void> _buy(Map<String,dynamic> r) async {
    try{await _db.rpc('purchase_currency_package',params:{'p_package_id':r['id'],'p_request_id':const Uuid().v4()});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم شراء الباقة')));await _load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_friendly(e))));}
  }
  Future<void> _toggle(Map<String,dynamic> r) async {
    try{await _db.rpc('admin_set_currency_package_enabled',params:{'p_id':r['id'],'p_enabled':r['enabled']!=true});await _load();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(_friendly(e))));}
  }
  Future<void> _edit([Map<String,dynamic>? r]) async {
    if(!_owner)return;
    final title=TextEditingController(text:r?['title']?.toString()??''),desc=TextEditingController(text:r?['description']?.toString()??''),
      amount=TextEditingController(text:r?['amount']?.toString()??'0'),bonus=TextEditingController(text:r?['bonus_amount']?.toString()??'0'),
      price=TextEditingController(text:r?['price_minor_units']?.toString()??'0'),sort=TextEditingController(text:r?['sort_order']?.toString()??'0');
    String type=r?['package_type']?.toString()??'points'; String? image=r?['image_url']?.toString(); bool enabled=r?['enabled']!=false,featured=r?['featured']==true;
    try{
      await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
        title:Text(r==null?'إضافة باقة':'تعديل باقة'),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<String>(initialValue:type,items:const[DropdownMenuItem(value:'points',child:Text('النقاط ⭐')),DropdownMenuItem(value:'gems',child:Text('الجواهر 💎'))],onChanged:(v)=>setDialog(()=>type=v??type),decoration:const InputDecoration(labelText:'النوع')),
          TextField(controller:title,decoration:const InputDecoration(labelText:'اسم الباقة')),
          TextField(controller:desc,maxLines:2,decoration:const InputDecoration(labelText:'الوصف')),
          Row(children:[Expanded(child:TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الكمية'))),const SizedBox(width:8),Expanded(child:TextField(controller:bonus,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الإضافي')))]),
          TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'السعر بالشام كاش')),
          TextField(controller:sort,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الترتيب')),
          OutlinedButton.icon(icon:const Icon(Icons.upload_rounded),label:Text(image==null?'رفع صورة':'استبدال الصورة'),onPressed:() async{
            final f=await ImagePicker().pickImage(source:ImageSource.gallery); if(f==null)return;
            try{final uid=_db.auth.currentUser?.id;if(uid==null)throw StateError('AUTH_REQUIRED');final bytes=await f.readAsBytes();final path=await _media.uploadBytes(bytes:bytes,fileName:f.name,folder:'packages',uid:uid);setDialog(()=>image=path);}
            catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(_friendly(e))));}
          }),
          if(image!=null&&image!.isNotEmpty)Image.network(image!,height:88,width:88,fit:BoxFit.cover),
          SwitchListTile(value:enabled,onChanged:(v)=>setDialog(()=>enabled=v),title:const Text('نشطة')),
          SwitchListTile(value:featured,onChanged:(v)=>setDialog(()=>featured=v),title:const Text('مميزة')),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
          FilledButton(onPressed:() async{
            try{
              await _db.rpc('admin_upsert_currency_package',params:{
                'p_id':r?['id']?.toString()??(type+'_'+DateTime.now().microsecondsSinceEpoch.toString()),
                'p_package_type':type,'p_title':title.text.trim(),'p_description':desc.text.trim(),
                'p_amount':int.tryParse(amount.text)??0,'p_bonus_amount':int.tryParse(bonus.text)??0,'p_price_minor_units':int.tryParse(price.text)??0,
                'p_price_currency':'sham_cash','p_image_url':image,'p_icon_key':type=='gems'?'💎':'⭐','p_enabled':enabled,'p_featured':featured,'p_sort_order':int.tryParse(sort.text)??0,
              });
              if(ctx.mounted)Navigator.pop(ctx); await _load();
            }catch(e){if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(_friendly(e))));}
          },child:const Text('حفظ')),
        ],
      )));
    }finally{for(final c in [title,desc,amount,bonus,price,sort]){c.dispose();}}
  }
  String _friendly(Object e){final s=e.toString().replaceFirst('PostgrestException(message: ','').replaceFirst(RegExp(r', code:.*'),'').replaceAll('Exception: ','');if(s.contains('FORBIDDEN'))return 'لا تملك صلاحية إدارة الباقات.';if(s.contains('INSUFFICIENT'))return 'الرصيد غير كافٍ.';return s;}
  @override Widget build(BuildContext context){
    final rows=_visible;
    return Scaffold(appBar:AppBar(title:const Text('متجر النقاط والجواهر'),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded)),if(_owner)IconButton(onPressed:()=>_edit(),icon:const Icon(Icons.add_rounded))]),
      body:_loading?const Center(child:CircularProgressIndicator()):Column(children:[
        Padding(padding:const EdgeInsets.all(10),child:SegmentedButton<String>(segments:const[ButtonSegment(value:'all',label:Text('الكل')),ButtonSegment(value:'points',label:Text('النقاط ⭐')),ButtonSegment(value:'gems',label:Text('الجواهر 💎'))],selected:{_filter},onSelectionChanged:(v)=>setState(()=>_filter=v.first))),
        Expanded(child:rows.isEmpty?const Center(child:Text('لا توجد باقات متاحة.')):ListView.separated(padding:const EdgeInsets.all(12),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i)=>_Card(row:rows[i],owner:_owner,buy:()=>_buy(rows[i]),edit:()=>_edit(rows[i]),toggle:()=>_toggle(rows[i])))),
      ]));
  }
}
class _Card extends StatelessWidget{
  final Map<String,dynamic> row; final bool owner; final VoidCallback buy,edit,toggle;
  const _Card({required this.row,required this.owner,required this.buy,required this.edit,required this.toggle});
  @override Widget build(BuildContext context){
    final gems=row['package_type']=='gems',enabled=row['enabled']==true,amount=(row['amount'] as num?)?.toInt()??0,bonus=(row['bonus_amount'] as num?)?.toInt()??0,image=row['image_url']?.toString(),icon=row['icon_key']?.toString()??(gems?'💎':'⭐');
    return Card(child:ListTile(leading:SizedBox(width:58,height:58,child:ClipRRect(borderRadius:BorderRadius.circular(10),child:image!=null&&image.isNotEmpty?Image.network(image,fit:BoxFit.cover,errorBuilder:(_,__,___)=>_Icon(icon)):_Icon(icon))),
      title:Text(row['title']?.toString()??'باقة'),subtitle:Text((amount+bonus).toString()+' '+(gems?'جوهرة':'نقطة')+' • '+(row['price_minor_units']??0).toString()+' شام كاش'),
      trailing:owner?Wrap(children:[IconButton(onPressed:edit,icon:const Icon(Icons.edit)),IconButton(onPressed:toggle,icon:Icon(enabled?Icons.visibility_off_outlined:Icons.visibility_outlined))]):(enabled?FilledButton(onPressed:buy,child:const Text('شراء')):const SizedBox.shrink())));
  }
}
class _Icon extends StatelessWidget{final String text;const _Icon(this.text);@override Widget build(BuildContext c)=>Center(child:Text(text,style:const TextStyle(fontSize:28)));}
