import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme_palette.dart';

/// مصدر ثيم التطبيق من الخادم مع fallback آمن عند غياب الجلسة/الشبكة.
/// اختيار المستخدم وحفظه يتمان حصريًا عبر RPCs الخادمية.
class ThemeController extends Notifier<AppThemePalette> {
  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  bool _restoring = false;

  @override
  AppThemePalette build() {
    ref.onDispose(() {
      unawaited(_authSubscription?.cancel());
      _authSubscription = null;
    });

    _authSubscription = _client.auth.onAuthStateChange.listen((event) {
      if (event.session == null) {
        state = AppThemePalette.goldLuxury;
      } else {
        unawaited(restoreFromServer());
      }
    });
    unawaited(restoreFromServer());
    return AppThemePalette.goldLuxury;
  }

  Future<void> restoreFromServer() async {
    if (_restoring || _client.auth.currentUser == null) return;
    _restoring = true;
    try {
      final raw = await _client.rpc('get_my_ui_theme');
      if (raw is Map) {
        state = AppThemePalette.fromServerRow(
          Map<String, dynamic>.from(raw),
        );
      }
    } catch (_) {
      // لا نمنع التطبيق من العمل عند تعذر تحميل الثيم.
    } finally {
      _restoring = false;
    }
  }

  Future<List<AppThemePalette>> loadCatalog() async {
    try {
      final raw = await _client.rpc('get_ui_theme_catalog');
      if (raw is List) {
        final result = <AppThemePalette>[];
        for (final item in raw) {
          if (item is Map) {
            result.add(AppThemePalette.fromServerRow(
              Map<String, dynamic>.from(item),
            ));
          }
        }
        if (result.isNotEmpty) return result;
      }
    } catch (_) {}
    return AppThemePalette.all;
  }

  Future<void> selectPalette(AppThemePalette palette) async {
    final raw = await _client.rpc(
      'set_my_ui_theme',
      params: {'p_theme_id': palette.id},
    );
    if (raw is Map) {
      state = AppThemePalette.fromServerRow(
        Map<String, dynamic>.from(raw),
      );
      return;
    }
    state = palette;
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemePalette>(
  ThemeController.new,
);
