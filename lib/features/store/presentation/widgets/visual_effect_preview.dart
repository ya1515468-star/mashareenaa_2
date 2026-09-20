import 'package:flutter/material.dart';
import '../../../../core/widgets/dynamic_avatar_frame.dart';
import 'visual_effect_config.dart';
import 'visual_effect_host.dart';

class VisualEffectPreview extends StatelessWidget {
  final String effectKey;
  final VisualEffectPlacement placement;
  const VisualEffectPreview({super.key,required this.effectKey,required this.placement});

  Widget _name() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),color:Colors.black26),
    child: const Text('(اسمك)',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:Colors.white)),
  );

  Widget _avatar() => const DynamicAvatarFrame(
    frameKey: null, radius: 26, child: CircleAvatar(radius: 26, backgroundColor: Color(0xFF384152), child: Icon(Icons.person,color:Colors.white70)),
  );

  @override Widget build(BuildContext context) {
    final name = VisualEffectHost(effectKey:effectKey,placement:VisualEffectPlacement.username,child:_name());
    final avatar = VisualEffectHost(effectKey:effectKey,placement:VisualEffectPlacement.avatar,child:_avatar());
    switch (placement) {
      case VisualEffectPlacement.username: return Center(child:name);
      case VisualEffectPlacement.avatar: return Center(child:avatar);
      case VisualEffectPlacement.both: return Row(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.center,children:[avatar,const SizedBox(width:10),name]);
    }
  }
}
