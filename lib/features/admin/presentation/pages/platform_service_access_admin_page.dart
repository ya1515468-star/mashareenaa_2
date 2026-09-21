import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlatformServiceAccessAdminPage extends StatefulWidget {
  const PlatformServiceAccessAdminPage({super.key});
  @override State<PlatformServiceAccessAdminPage> createState()=>_PlatformServiceAccessAdminPageState();
}
class _PlatformServiceAccessAdminPageState extends State<PlatformServiceAccessAdminPage>{
  final query=TextEditingController();
  static const services=<Map<String,String>>[
    {'key':'garment_market','name':'خدمات الألبسة'},
    {'key':'producer_market','name':'سوق الألبسة'},
    {'key':'currency_packages','name':'باقات النقاط والجواهر'},
  ];
  String service='garment_market';
  List<Map<String,dynamic>> results=[],access=[];
  bool owner=false,loading=true;
  @override void initState(){super.initState();_load();}
  @override void dispose(){query.dispose();super.dispose();}
  Future<void> _load() async{
    try{
      final db=Supabase.instance.client;
      if(await db.rpc('is_my_platform_owner')!=true){if(mounted)setState(()=>loading=false);return;}
      final rows=await db.rpc('admin_list_platform_service_access');
      if(!mounted)return;
      setState(() { owner=true; access=List<Map<String,dynamic>>.from(rows as List); loading=false; });
    }catch(e){if(mounted){setState(()=>loading=false);_snack(_friendly(e));}}
  }
  Future<void> _search() async{
    final q=query.text.trim();if(q.length<2)return;
    try{
      final rows=await Supabase.instance.client.rpc('search_public_profiles',params:{'p_query':q,'p_limit':20});
      if(!mounted)return;
      setState(()=>results=List<Map<String,dynamic>>.from(rows as List));
    }catch(e){_snack(_friendly(e));}
  }
  Future<void> _grant(String uid) async{
    try{await Supabase.instance.client.rpc('admin_grant_platform_service_access',params:{'p_service_key':service,'p_user_id':uid});await _load();}
    catch(e){_snack(_friendly(e));}
  }
  Future<void> _revoke(String key,String uid) async{
    try{await Supabase.instance.client.rpc('admin_revoke_platform_service_access',params:{'p_service_key':key,'p_user_id':uid});await _load();}
    catch(e){_snack(_friendly(e));}
  }
  void _snack(String s){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  String _friendly(Object e)=>e.toString().replaceFirst('PostgrestException(message: ','').replaceFirst(RegExp(r', code:.*'),'').replaceAll('Exception: ','');
  @override Widget build(BuildContext context){
    if(loading)return const Center(child:CircularProgressIndicator());
    if(!owner)return const Center(child:Text('صلاحيات الخدمات للمالك فقط.'));
    return ListView(padding:const EdgeInsets.all(14),children:[
      DropdownButtonFormField<String>(value:service,items:[for(final s in services)DropdownMenuItem(value:s['key']!,child:Text(s['name']!))],onChanged:(v)=>setState(()=>service=v??service),decoration:const InputDecoration(labelText:'الخدمة')),
      const SizedBox(height:8),
      Row(children:[Expanded(child:TextField(controller:query,onSubmitted:(_)=>_search(),decoration:const InputDecoration(hintText:'اسم المستخدم أو اسم الحساب'))),const SizedBox(width:8),FilledButton(onPressed:_search,child:const Text('بحث'))]),
      const SizedBox(height:8),
      ...results.map((p)=>Card(child:ListTile(title:Text(p['display_name']?.toString()??p['username']?.toString()??'عضو'),subtitle:Text('@${p['username']??''}'),trailing:FilledButton(onPressed:()=>_grant(p['id'].toString()),child:const Text('منح'))))),
      const Divider(height:28),
      const Text('الصلاحيات الحالية',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
      ...access.map((a)=>Card(child:ListTile(title:Text(a['display_name']?.toString()??a['username']?.toString()??'عضو'),subtitle:Text('${a['service_key']} • @${a['username']??''}'),trailing:IconButton(onPressed:()=>_revoke(a['service_key'].toString(),a['user_id'].toString()),icon:const Icon(Icons.remove_circle_outline))))),
    ]);
  }
}
