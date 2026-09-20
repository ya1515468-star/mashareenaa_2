import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../store/presentation/widgets/store_preview.dart';
import '../../domain/entities/subscription_tier_entity.dart';

class StoreMembershipCard extends StatefulWidget {
  final SubscriptionTierEntity tier;
  final String? currentTierId;
  final bool ownerMode;
  final VoidCallback? onPurchase;
  final VoidCallback? onGift;
  final VoidCallback? onEditPrice;
  final VoidCallback? onDelete;
  const StoreMembershipCard(
      {super.key,
      required this.tier,
      this.currentTierId,
      required this.ownerMode,
      this.onPurchase,
      this.onGift,
      this.onEditPrice,
      this.onDelete});
  @override
  State<StoreMembershipCard> createState() => _StoreMembershipCardState();
}

class _StoreMembershipCardState extends State<StoreMembershipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.tier.badge.color;
    final active = widget.currentTierId == widget.tier.id;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final angle = math.sin(_c.value * math.pi * 2) * 0.045;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          // كل محاولات إصلاح "عرض لا نهائي" السابقة كانت داخل البطاقة
          // (Flexible حول Wrap) ولم تُنهِ الخطأ لأن المصدر الحقيقي هنا في
          // الجذر: Transform يمرّر قيود الأب كما هي، فإن كانت البطاقة داخل
          // سياق بعرض غير محدود (ListView أفقي، Row بلا Expanded...) تصل
          // القيود w=Infinity إلى الأزرار في الداخل فينهار التخطيط. تحديد
          // عرض أقصى عند الجذر يقطع هذا نهائيًا مهما كان سياق الاستدعاء.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width,
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 14),
              child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  color.withValues(alpha: 0.28),
                  Colors.transparent
                ]),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 20,
                      spreadRadius: 1)
                ],
              ),
              padding: const EdgeInsets.all(16),
              // NOT CrossAxisAlignment.stretch: stretch forces children to the Column's
              // width, and this card is laid out with an unbounded width, so the
              // trailing FilledButton received w=Infinity and the whole card failed
              // to lay out — which is why the memberships tab rendered EMPTY.
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                SizedBox(
                    width: 92,
                    height: 92,
                    child: StoreGifPreview(
                      assetPath: _assetForTier(widget.tier.id),
                      alt: widget.tier.name,
                    )),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.tier.name,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.palette.textPrimary)),
                      const SizedBox(height: 5),
                      Text(widget.tier.price.formatted,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.bold)),
                      Text(
                          '${widget.tier.durationDays} يوم • مكافأة يومية ×${widget.tier.dailyRewardMultiplier}',
                          style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 12)),
                    ])),
                if (widget.ownerMode)
                  // Same fix as the "شراء" branch below, missed here the first
                  // time: a Wrap placed directly as a non-flex Row child can
                  // still be handed an unbounded max width by the Row, and a
                  // FilledButton inside it then crashes in _computeSize with
                  // "BoxConstraints forces an infinite width" — exactly the
                  // crash reported at this file/line. Flexible caps the Wrap
                  // to the space actually left in the Row.
                  Flexible(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        IconButton(
                            onPressed: widget.onEditPrice,
                            icon: const Icon(Icons.dashboard_customize_outlined),
                            tooltip: 'تعديل العضوية بالكامل'),
                        IconButton(
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            tooltip: 'حذف العضوية'),
                        FilledButton.icon(
                            onPressed: widget.onGift,
                            icon: const Icon(Icons.card_giftcard),
                            label: const Text('إهداء')),
                        FilledButton.icon(
                            onPressed: active ? null : widget.onPurchase,
                            icon: const Icon(Icons.storefront_outlined),
                            label: Text(active ? 'مفعّلة' : 'شراء مجاني')),
                      ],
                    ),
                  )
                else if (active)
                  const Chip(label: Text('مفعّلة'))
                else
                  Flexible(
                    child: FilledButton.icon(
                        onPressed: widget.onPurchase,
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text('شراء')),
                  )
                ]),
                // Spec 8.2: membership isn't just a buy button — show what
                // the buyer actually gets, before they pay, not just after.
                if (widget.tier.hasOneTimeGrants) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text('يشمل عند الشراء:', style: TextStyle(fontSize: 11, color: context.palette.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (widget.tier.pointsGranted > 0)
                      Chip(avatar: const Icon(Icons.stars, size: 16), label: Text('${widget.tier.pointsGranted} نقطة'), visualDensity: VisualDensity.compact),
                    if (widget.tier.gemsGranted > 0)
                      Chip(avatar: const Icon(Icons.diamond, size: 16), label: Text('${widget.tier.gemsGranted} جوهرة'), visualDensity: VisualDensity.compact),
                    if (widget.tier.grantedCosmeticKeys.isNotEmpty)
                      Chip(avatar: const Icon(Icons.palette, size: 16), label: Text('${widget.tier.grantedCosmeticKeys.length} عنصر تجميلي'), visualDensity: VisualDensity.compact),
                    if (widget.tier.grantedAnimationKeys.isNotEmpty)
                      Chip(avatar: const Icon(Icons.pets, size: 16), label: Text('${widget.tier.grantedAnimationKeys.length} حيوان اسم'), visualDensity: VisualDensity.compact),
                  ]),
                ],
              ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _assetForTier(String id) {
  switch (id) {
    case 'bronze':
      return 'assets/store_gifs/membership/membership_01.gif';
    case 'silver':
      return 'assets/store_gifs/membership/membership_06.gif';
    case 'gold':
      return 'assets/store_gifs/membership/membership_11.gif';
    case 'diamond':
      return 'assets/store_gifs/membership/membership_16.gif';
    case 'royal':
      return 'assets/store_gifs/membership/membership_21.gif';
    case 'vip':
      return 'assets/store_gifs/membership/membership_26.gif';
    case 'legendary':
      return 'assets/store_gifs/membership/membership_31.gif';
    default:
      return 'assets/store_gifs/membership/membership_11.gif';
  }
}
