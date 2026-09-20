import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickLinkCard(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
