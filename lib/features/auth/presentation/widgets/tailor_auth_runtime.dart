import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme_palette.dart';

class AuthUiFeature {
  final IconData icon;
  final String label;

  const AuthUiFeature({required this.icon, required this.label});
}

class AuthUiRuntime {
  final String mode;
  final String brandName;
  final String brandTagline;
  final String loginTitle;
  final String loginSubtitle;
  final String loginButton;
  final String registerTitle;
  final String registerSubtitle;
  final String registerButton;
  final String switchToRegister;
  final String switchToLogin;
  final String securityNote;
  final String trustLabel;
  final List<AuthUiFeature> features;
  final AppThemePalette palette;
  final double patternOpacity;
  final String? remoteHeroUrl;

  const AuthUiRuntime({
    required this.mode,
    required this.brandName,
    required this.brandTagline,
    required this.loginTitle,
    required this.loginSubtitle,
    required this.loginButton,
    required this.registerTitle,
    required this.registerSubtitle,
    required this.registerButton,
    required this.switchToRegister,
    required this.switchToLogin,
    required this.securityNote,
    required this.trustLabel,
    required this.features,
    required this.palette,
    required this.patternOpacity,
    required this.remoteHeroUrl,
  });

  static const AuthUiRuntime fallback = AuthUiRuntime(
    mode: 'modern_auth_v2',
    brandName: 'مشاريعنا',
    brandTagline: 'من الفكرة إلى السوق، كل شيء في مكان واحد',
    loginTitle: 'مرحبًا بعودتك',
    loginSubtitle: 'سجّل الدخول لمتابعة أعمالك، محادثاتك وطلباتك.',
    loginButton: 'تسجيل الدخول',
    registerTitle: 'أنشئ حسابك',
    registerSubtitle: 'أنشئ هويتك المهنية وابدأ ببناء حضورك داخل مشاريعنا.',
    registerButton: 'إنشاء الحساب',
    switchToRegister: 'ليس لديك حساب؟ إنشاء حساب',
    switchToLogin: 'لديك حساب بالفعل؟ تسجيل الدخول',
    securityNote: 'حماية الجلسة وإدارة الهوية تتم عبر خوادم المنصة.',
    trustLabel: 'حماية الخادم مفعّلة',
    features: [
      AuthUiFeature(icon: Icons.badge_outlined, label: 'هوية احترافية'),
      AuthUiFeature(icon: Icons.storefront_outlined, label: 'تجارة وأعمال'),
      AuthUiFeature(icon: Icons.forum_outlined, label: 'محادثات واتصال'),
    ],
    palette: AppThemePalette.goldLuxury,
    patternOpacity: .05,
    remoteHeroUrl: null,
  );

  factory AuthUiRuntime.fromConfig(Map<String, dynamic>? root) {
    final source = Map<String, dynamic>.from(root ?? const {});
    final auth = _map(source['auth']);
    final brand = _map(source['brand']);
    final paletteMap = _map(auth['palette']);
    final featuresRaw = auth['features'] is List ? auth['features'] as List : const [];
    const fallback = AuthUiRuntime.fallback;

    final features = <AuthUiFeature>[];
    for (final raw in featuresRaw) {
      final item = _map(raw);
      final label = item['label_ar']?.toString().trim() ?? '';
      if (label.isEmpty) continue;
      features.add(AuthUiFeature(
        icon: _icon(item['icon']?.toString()),
        label: label,
      ));
    }

    return AuthUiRuntime(
      mode: auth['mode']?.toString().trim().isNotEmpty == true
          ? auth['mode'].toString()
          : fallback.mode,
      brandName: brand['name_ar']?.toString().trim().isNotEmpty == true
          ? brand['name_ar'].toString()
          : fallback.brandName,
      brandTagline: auth['brand_tagline_ar']?.toString().trim().isNotEmpty == true
          ? auth['brand_tagline_ar'].toString()
          : (brand['tagline_ar']?.toString().trim().isNotEmpty == true
              ? brand['tagline_ar'].toString()
              : fallback.brandTagline),
      loginTitle: auth['login_title_ar']?.toString().trim().isNotEmpty == true
          ? auth['login_title_ar'].toString()
          : fallback.loginTitle,
      loginSubtitle: auth['login_subtitle_ar']?.toString().trim().isNotEmpty == true
          ? auth['login_subtitle_ar'].toString()
          : fallback.loginSubtitle,
      loginButton: auth['login_button_ar']?.toString().trim().isNotEmpty == true
          ? auth['login_button_ar'].toString()
          : fallback.loginButton,
      registerTitle: auth['register_title_ar']?.toString().trim().isNotEmpty == true
          ? auth['register_title_ar'].toString()
          : fallback.registerTitle,
      registerSubtitle: auth['register_subtitle_ar']?.toString().trim().isNotEmpty == true
          ? auth['register_subtitle_ar'].toString()
          : fallback.registerSubtitle,
      registerButton: auth['register_button_ar']?.toString().trim().isNotEmpty == true
          ? auth['register_button_ar'].toString()
          : fallback.registerButton,
      switchToRegister: auth['switch_to_register_ar']?.toString().trim().isNotEmpty == true
          ? auth['switch_to_register_ar'].toString()
          : fallback.switchToRegister,
      switchToLogin: auth['switch_to_login_ar']?.toString().trim().isNotEmpty == true
          ? auth['switch_to_login_ar'].toString()
          : fallback.switchToLogin,
      securityNote: auth['security_note_ar']?.toString().trim().isNotEmpty == true
          ? auth['security_note_ar'].toString()
          : fallback.securityNote,
      trustLabel: auth['trust_label_ar']?.toString().trim().isNotEmpty == true
          ? auth['trust_label_ar'].toString()
          : fallback.trustLabel,
      features: features.isEmpty ? fallback.features : List.unmodifiable(features),
      palette: _palette(paletteMap, fallback.palette),
      patternOpacity: _double(auth['pattern_opacity'], fallback.patternOpacity)
          .clamp(.02, .16)
          .toDouble(),
      remoteHeroUrl: _url(auth['hero_image_url']),
    );
  }

  static AppThemePalette _palette(
    Map<String, dynamic> values,
    AppThemePalette fallback,
  ) {
    Color read(String key, Color current) => _color(values[key]) ?? current;
    return fallback.copyWith(
      id: 'server_auth_modern',
      nameAr: values['name_ar']?.toString() ?? fallback.nameAr,
      accent: read('accent', fallback.accent),
      accentMuted: read('accent_muted', fallback.accentMuted),
      accentBright: read('accent_bright', fallback.accentBright),
      secondary: read('secondary', fallback.secondary),
      secondaryBright: read('secondary_bright', fallback.secondaryBright),
      background: read('background', fallback.background),
      surface: read('surface', fallback.surface),
      surfaceElevated: read('surface_elevated', fallback.surfaceElevated),
      surfaceHighlight: read('surface_highlight', fallback.surfaceHighlight),
      textPrimary: read('text_primary', fallback.textPrimary),
      textSecondary: read('text_secondary', fallback.textSecondary),
      textMuted: read('text_muted', fallback.textMuted),
      divider: read('divider', fallback.divider),
      error: read('error', fallback.error),
      success: read('success', fallback.success),
      warning: read('warning', fallback.warning),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static double _double(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _url(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || !text.startsWith('http')) return null;
    return text;
  }

  static Color? _color(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final text = raw.replaceFirst('#', '');
    final normalized = text.length == 6 ? 'FF$text' : text;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static IconData _icon(String? key) => switch (key) {
        'badge' => Icons.badge_outlined,
        'store' => Icons.storefront_outlined,
        'chat' => Icons.forum_outlined,
        'secure' => Icons.verified_user_outlined,
        'content_cut' => Icons.content_cut_rounded,
        'checkroom' => Icons.checkroom_rounded,
        'handshake' => Icons.handshake_outlined,
        'design' => Icons.design_services_outlined,
        _ => Icons.auto_awesome_rounded,
      };
}

final authUiRuntimeProvider = FutureProvider<AuthUiRuntime>((ref) async {
  try {
    final result = await Supabase.instance.client
        .rpc('get_auth_ui_runtime')
        .timeout(const Duration(seconds: 5));
    final payload = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return AuthUiRuntime.fromConfig(payload['config'] is Map
        ? Map<String, dynamic>.from(payload['config'])
        : payload);
  } catch (_) {
    return AuthUiRuntime.fallback;
  }
});
