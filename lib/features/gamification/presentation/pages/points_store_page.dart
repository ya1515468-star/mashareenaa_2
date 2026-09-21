import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum StoreFeatureType {
  glow,
  frame,
  background,
}

class PointsStorePage extends StatefulWidget {
  const PointsStorePage({super.key});
  @override
  State<PointsStorePage> createState() => _PointsStorePageState();
}

class _PointsStorePageState extends State<PointsStorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<_PackageCatalog> _future;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<_PackageCatalog> _load() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      client
          .from('points_packages')
          .select(
              'id,title,description,points_granted,bonus_points,price_minor_units,currency,icon,image_url,enabled,is_featured,sort_order')
          .eq('enabled', true)
          .order('sort_order')
          .order('price_minor_units'),
      client
          .from('currency_packages')
          .select(
              'id,title,description,amount,bonus_amount,price_minor_units,price_currency,image_url,icon_key,enabled,featured,sort_order')
          .eq('package_type', 'gems')
          .eq('enabled', true)
          .order('sort_order')
          .order('price_minor_units'),
    ]);
    return _PackageCatalog(
      points: List<Map<String, dynamic>>.from(results[0] as List),
      gems: List<Map<String, dynamic>>.from(results[1] as List),
    );
  }

  Future<void> _purchase(String functionName, String id) async {
    try {
      await Supabase.instance.client.rpc(
        functionName,
        params: {'p_package_id': id, 'p_request_id': _uuid.v4()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت العملية بنجاح')),
      );
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إتمام العملية: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متجر النقاط والجواهر'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.star_rounded), text: 'النقاط'),
            Tab(icon: Icon(Icons.diamond_rounded), text: 'الجواهر'),
          ],
        ),
      ),
      body: FutureBuilder<_PackageCatalog>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'تعذر تحميل الباقات: ${snapshot.error}',
              ),
            );
          }
          final data =
              snapshot.data ?? const _PackageCatalog(points: [], gems: []);
          return TabBarView(
            controller: _tabs,
            children: [
              _PackageGrid(
                rows: data.points,
                kind: _PackageKind.points,
                onPurchase: (id) => _purchase('purchase_points_package', id),
              ),
              _PackageGrid(
                rows: data.gems,
                kind: _PackageKind.gems,
                onPurchase: (id) => _purchase('purchase_currency_package', id),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _PackageKind { points, gems }

class _PackageCatalog {
  final List<Map<String, dynamic>> points;
  final List<Map<String, dynamic>> gems;
  const _PackageCatalog({required this.points, required this.gems});
}

class _PackageGrid extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final _PackageKind kind;
  final ValueChanged<String> onPurchase;

  const _PackageGrid({
    required this.rows,
    required this.kind,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          kind == _PackageKind.points
              ? 'لا توجد باقات نقاط متاحة حاليًا.'
              : 'لا توجد باقات جواهر متاحة حاليًا.',
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 1100 ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .78,
      ),
      itemCount: rows.length,
      itemBuilder: (_, index) {
        final row = rows[index];
        final amount =
            ((row[kind == _PackageKind.points ? 'points_granted' : 'amount']
                        as num?)
                    ?.toInt() ??
                0);
        final bonus =
            ((row[kind == _PackageKind.points ? 'bonus_points' : 'bonus_amount']
                        as num?)
                    ?.toInt() ??
                0);
        final title = row['title']?.toString() ?? '';
        final image = row['image_url']?.toString();
        final icon =
            row[kind == _PackageKind.points ? 'icon' : 'icon_key']?.toString();
        final price = ((row['price_minor_units'] as num?)?.toInt() ?? 0);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: image != null && image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _FallbackIcon(kind: kind, icon: icon),
                        )
                      : _FallbackIcon(kind: kind, icon: icon),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '+${amount + bonus} ${kind == _PackageKind.points ? 'نقطة' : 'جوهرة'}',
                style: TextStyle(
                  color: kind == _PackageKind.points
                      ? Colors.amber
                      : Colors.cyanAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (bonus > 0)
                Text(
                  'الأساسي $amount + مكافأة $bonus',
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onPurchase(row['id'].toString()),
                    child: Text('$price شام كاش'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final _PackageKind kind;
  final String? icon;
  const _FallbackIcon({required this.kind, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon != null && icon!.trim().isNotEmpty) {
      return Text(icon!, style: const TextStyle(fontSize: 70));
    }
    return Icon(
      kind == _PackageKind.points ? Icons.stars_rounded : Icons.diamond_rounded,
      size: 72,
      color: kind == _PackageKind.points ? Colors.amber : Colors.cyanAccent,
    );
  }
}
