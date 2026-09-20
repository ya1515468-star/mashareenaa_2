import 'package:flutter/material.dart';

enum AppIconKey {
  store,
  wallet,
  chat,
  calls,
  posts,
  marketplace,
  patternStudio,
  garmentHub,
  gamification,
  gifts,
  friends,
  notifications,
  profile,
  subscriptions,
  ai,
  admin,
  rbac,
  reports,
  settings,
  inventory,
  wishlist,
  collectibles,
}

/// Central visual language for the platform. Business logic must not depend on icons.
class AppIconRegistry {
  AppIconRegistry._();

  static const Map<AppIconKey, IconData> _icons = {
    AppIconKey.store: Icons.storefront_rounded,
    AppIconKey.wallet: Icons.account_balance_wallet_rounded,
    AppIconKey.chat: Icons.chat_bubble_rounded,
    AppIconKey.calls: Icons.call_rounded,
    AppIconKey.posts: Icons.article_rounded,
    AppIconKey.marketplace: Icons.shopping_bag_rounded,
    AppIconKey.patternStudio: Icons.design_services_rounded,
    AppIconKey.garmentHub: Icons.checkroom_rounded,
    AppIconKey.gamification: Icons.emoji_events_rounded,
    AppIconKey.gifts: Icons.card_giftcard_rounded,
    AppIconKey.friends: Icons.group_rounded,
    AppIconKey.notifications: Icons.notifications_rounded,
    AppIconKey.profile: Icons.person_rounded,
    AppIconKey.subscriptions: Icons.workspace_premium_rounded,
    AppIconKey.ai: Icons.auto_awesome_rounded,
    AppIconKey.admin: Icons.admin_panel_settings_rounded,
    AppIconKey.rbac: Icons.security_rounded,
    AppIconKey.reports: Icons.analytics_rounded,
    AppIconKey.settings: Icons.settings_rounded,
    AppIconKey.inventory: Icons.inventory_2_rounded,
    AppIconKey.wishlist: Icons.favorite_rounded,
    AppIconKey.collectibles: Icons.diamond_rounded,
  };

  static IconData icon(AppIconKey key) => _icons[key] ?? Icons.apps_rounded;

  static Widget build(AppIconKey key,
          {double? size, Color? color, String? semanticLabel}) =>
      Icon(icon(key), size: size, color: color, semanticLabel: semanticLabel);
}
