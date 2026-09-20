import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme_palette.dart';
import '../../../../core/theme/theme_controller.dart';

class StyleSettingsPage extends ConsumerStatefulWidget {
  final String uid;

  const StyleSettingsPage({super.key, required this.uid});

  @override
  ConsumerState<StyleSettingsPage> createState() => _StyleSettingsPageState();
}

class _StyleSettingsPageState extends ConsumerState<StyleSettingsPage> {
  late Future<List<AppThemePalette>> _catalogFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _catalogFuture = ref.read(themeControllerProvider.notifier).loadCatalog();
  }

  Future<void> _select(AppThemePalette palette) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(themeControllerProvider.notifier).selectPalette(palette);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ ثيم «${palette.nameAr}» على الخادم.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الثيم: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(themeControllerProvider);
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(title: const Text('ستايلات التطبيق')),
      body: FutureBuilder<List<AppThemePalette>>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final themes = snapshot.data ?? AppThemePalette.all;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              width < 420 ? 12 : 18,
              16,
              width < 420 ? 12 : 18,
              28,
            ),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(Icons.cloud_done_outlined, color: current.accent),
                  title: const Text(
                    'الستايل يُدار من الخادم',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'الاختيار، الكتالوج والحفظ مرتبطة بـSupabase ولا تُحفظ كإعداد محلي.'
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر مظهر التطبيق',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: themes.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  final selected = theme.id == current.id;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _saving ? null : () => _select(theme),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [theme.surfaceElevated, theme.background],
                        ),
                        border: Border.all(
                          color: selected ? theme.accent : theme.divider,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: theme.accent.withValues(alpha: .20), blurRadius: 18)]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.accent.withValues(alpha: .15),
                              border: Border.all(color: theme.accent.withValues(alpha: .4)),
                            ),
                            child: Icon(theme.icon, color: theme.accentBright),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(theme.nameAr, style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _Dot(color: theme.accent),
                                    const SizedBox(width: 5),
                                    _Dot(color: theme.secondaryBright),
                                    const SizedBox(width: 5),
                                    _Dot(color: theme.accentBright),
                                    const Spacer(),
                                    if (selected) Icon(Icons.check_circle_rounded, color: theme.accentBright, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_saving) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
