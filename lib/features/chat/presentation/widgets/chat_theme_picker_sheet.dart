import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';

class ChatThemeDefinition {
  final String id;
  final String name;
  final String backgroundKey;
  final List<Color> gradient;
  final Color bubbleMine;
  final Color bubbleOther;
  final Color accent;
  final IconData icon;
  final String? imageUrl;

  const ChatThemeDefinition({
    required this.id,
    required this.name,
    required this.backgroundKey,
    required this.gradient,
    required this.bubbleMine,
    required this.bubbleOther,
    required this.accent,
    required this.icon,
    this.imageUrl,
  });

  static final List<ChatThemeDefinition> all = [
    const ChatThemeDefinition(
      id: 'royal_dark',
      name: 'ملكي داكن',
      backgroundKey: 'royal_dark',
      gradient: [Color(0xFF0D0617), Color(0xFF24103A), Color(0xFF0B0815)],
      bubbleMine: Color(0xFF6F26A0),
      bubbleOther: Color(0xFF32203D),
      accent: Color(0xFFC86BFF),
      icon: Icons.auto_awesome_rounded,
    ),
    const ChatThemeDefinition(
      id: 'midnight_blue',
      name: 'ليلي أزرق',
      backgroundKey: 'midnight_blue',
      gradient: [Color(0xFF06101C), Color(0xFF0B2741), Color(0xFF050B14)],
      bubbleMine: Color(0xFF1F5D91),
      bubbleOther: Color(0xFF18303F),
      accent: Color(0xFF64C8FF),
      icon: Icons.nights_stay_rounded,
    ),
    const ChatThemeDefinition(
      id: 'emerald_night',
      name: 'زمردي',
      backgroundKey: 'emerald_night',
      gradient: [Color(0xFF061510), Color(0xFF0A342A), Color(0xFF050D0A)],
      bubbleMine: Color(0xFF13765B),
      bubbleOther: Color(0xFF17382F),
      accent: Color(0xFF5FE4B3),
      icon: Icons.eco_rounded,
    ),
    const ChatThemeDefinition(
      id: 'rose_velvet',
      name: 'مخمل وردي',
      backgroundKey: 'rose_velvet',
      gradient: [Color(0xFF1A0913), Color(0xFF4A1730), Color(0xFF12070E)],
      bubbleMine: Color(0xFF9B3166),
      bubbleOther: Color(0xFF402036),
      accent: Color(0xFFFF80B8),
      icon: Icons.favorite_rounded,
    ),
    const ChatThemeDefinition(
      id: 'golden_lounge',
      name: 'صالون ذهبي',
      backgroundKey: 'golden_lounge',
      gradient: [Color(0xFF171108), Color(0xFF3B2A08), Color(0xFF0D0A06)],
      bubbleMine: Color(0xFF80611A),
      bubbleOther: Color(0xFF382B13),
      accent: Color(0xFFFFD36A),
      icon: Icons.workspace_premium_rounded,
    ),
    const ChatThemeDefinition(
      id: 'carbon',
      name: 'كربوني',
      backgroundKey: 'carbon',
      gradient: [Color(0xFF08090B), Color(0xFF1B1E23), Color(0xFF07080A)],
      bubbleMine: Color(0xFF3D434C),
      bubbleOther: Color(0xFF20242A),
      accent: Color(0xFFBFC7D2),
      icon: Icons.grid_4x4_rounded,
    ),
  ];

  static void replaceServerThemes(List<ChatThemeDefinition> themes) {
    if (themes.isEmpty) return;
    all
      ..clear()
      ..addAll(themes);
  }

  static ChatThemeDefinition byId(String? id) {
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => all.first,
    );
  }
}

class ChatThemePickerSheet extends StatefulWidget {
  final String selectedId;
  final Future<void> Function(ChatThemeDefinition theme) onSelected;

  const ChatThemePickerSheet({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  static Future<void> loadServerCatalog() async {
    try {
      final rows = await Supabase.instance.client.rpc('get_chat_wallpaper_catalog', params: {'p_scope': 'both'});
      final mapped = <ChatThemeDefinition>[];
      for (final raw in List<Map<String, dynamic>>.from(rows)) {
        final row = Map<String, dynamic>.from(raw);
        final key = row['wallpaper_key']?.toString();
        final name = row['name_ar']?.toString();
        if (key == null || key.isEmpty || name == null || name.isEmpty) continue;
        final c1 = _ChatThemeColor.parse(row['color1']?.toString()) ?? const Color(0xFF111827);
        final c2 = _ChatThemeColor.parse(row['color2']?.toString()) ?? c1;
        mapped.add(ChatThemeDefinition(id:key,name:name,backgroundKey:key,gradient:[c1,c2,c1],bubbleMine:c2.withValues(alpha:.82),bubbleOther:const Color(0xFF20242A),accent:c2,icon:row['is_premium']==true?Icons.workspace_premium_rounded:Icons.wallpaper_rounded,imageUrl:row['image_url']?.toString()));
      }
      ChatThemeDefinition.replaceServerThemes(mapped);
    } catch (_) {}
  }

  static Future<void> show({
    required BuildContext context,
    required String selectedId,
    required Future<void> Function(ChatThemeDefinition theme) onSelected,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 760,
            maxHeight: MediaQuery.of(dialogContext).size.height * .82,
          ),
          child: ChatThemePickerSheet(
            selectedId: selectedId,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  @override
  State<ChatThemePickerSheet> createState() => _ChatThemePickerSheetState();
}

class _ChatThemePickerSheetState extends State<ChatThemePickerSheet> {
  List<ChatThemeDefinition>? serverThemes;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadServerThemes());
  }

  Future<void> _loadServerThemes() async {
    try {
      final rows = await Supabase.instance.client.rpc('get_chat_wallpaper_catalog', params: {'p_scope': 'both'});
      final mapped = <ChatThemeDefinition>[];
      for (final raw in List<Map<String, dynamic>>.from(rows)) {
        final row = Map<String, dynamic>.from(raw);
        final key = row['wallpaper_key']?.toString();
        final name = row['name_ar']?.toString();
        if (key == null || key.isEmpty || name == null || name.isEmpty) continue;
        final c1 = _ChatThemeColor.parse(row['color1']?.toString()) ?? const Color(0xFF111827);
        final c2 = _ChatThemeColor.parse(row['color2']?.toString()) ?? c1;
        mapped.add(ChatThemeDefinition(
          id: key,
          name: name,
          backgroundKey: key,
          gradient: [c1, c2, c1],
          bubbleMine: c2.withValues(alpha: .82),
          bubbleOther: const Color(0xFF20242A),
          accent: c2,
          icon: row['is_premium'] == true ? Icons.workspace_premium_rounded : Icons.wallpaper_rounded,
          imageUrl: row['image_url']?.toString(),
        ));
      }
      if (mapped.isNotEmpty) {
        ChatThemeDefinition.replaceServerThemes(mapped);
        if (mounted) setState(() => serverThemes = mapped);
      }
    } catch (_) {
      // Fallback remains available so a transient catalog failure never blocks chat.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final themes = serverThemes ?? ChatThemeDefinition.all;
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF120C1B),
          borderRadius: BorderRadius.all(Radius.circular(28)),
          border: Border.fromBorderSide(BorderSide(color: Color(0x663E1B50))),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.wallpaper_rounded, color: Color(0xFFE0A8FF)),
              const SizedBox(width: 10),
              const Expanded(child: Text('خلفيات وثيمات الشات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
              if (loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: themes.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55),
                itemBuilder: (_, index) {
                  final theme = themes[index];
                  final selected = theme.id == widget.selectedId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      unawaited(widget.onSelected(theme));
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: theme.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(color: selected ? theme.accent : Colors.white12, width: selected ? 2 : 1),
                        boxShadow: selected ? [BoxShadow(color: theme.accent.withValues(alpha: .26), blurRadius: 18, spreadRadius: 1)] : const [],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08), border: Border.all(color: theme.accent.withValues(alpha: .7))), child: Icon(theme.icon, color: Colors.white70)),
                          const Spacer(),
                          if (selected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        ]),
                        const Spacer(),
                        Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(theme.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ChatThemeBackground extends StatelessWidget {
  final ChatThemeDefinition theme;
  final Widget child;
  const ChatThemeBackground({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    final imageUrl = theme.imageUrl?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        if (imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: .20),
                Colors.transparent,
                Colors.black.withValues(alpha: .30),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ChatThemeColor {
  static Color? parse(String? value) { final v=value?.trim().replaceFirst('#',''); if(v==null||v.isEmpty)return null; final hex=v.length==6?'FF$v':v; final n=int.tryParse(hex,radix:16); return n==null?null:Color(n); }
}
