import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'premium/effects.dart';
import 'tailor_auth_runtime.dart';

class TailorAuthScaffold extends StatelessWidget {
  final AuthUiRuntime ui;
  final Widget child;
  final bool registerMode;
  final VoidCallback? onBack;

  const TailorAuthScaffold({
    super.key,
    required this.ui,
    required this.child,
    required this.registerMode,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width <= 380;
    final wide = size.width >= 800;
    final maxCardWidth = registerMode ? 560.0 : 480.0;
    final outerPadding = compact ? 14.0 : (wide ? 24.0 : 18.0);

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          Positioned.fill(child: _AuthBackdrop(ui: ui)),
          if (ui.remoteHeroUrl != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: .08,
                  child: Image.network(
                    ui.remoteHeroUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          const Positioned.fill(child: FloatingGoldDust()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    outerPadding,
                    compact ? 16 : 28,
                    outerPadding,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - (compact ? 40 : 52)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxCardWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ModernBrandHeader(ui: ui, compact: compact),
                            SizedBox(height: compact ? 16 : 22),
                            _AuthCard(
                              ui: ui,
                              registerMode: registerMode,
                              onBack: onBack,
                              child: child,
                            ),
                            const SizedBox(height: 14),
                            _AuthFooter(ui: ui),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernBrandHeader extends StatelessWidget {
  final AuthUiRuntime ui;
  final bool compact;

  const _ModernBrandHeader({required this.ui, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 42 : 48,
          height: compact ? 42 : 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.accentBright, p.accent, p.secondary],
            ),
            boxShadow: [
              BoxShadow(
                color: p.accent.withValues(alpha: .20),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: p.background,
            size: compact ? 21 : 24,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ui.brandName,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: compact ? 19 : 22,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              ui.brandTagline,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  final AuthUiRuntime ui;
  final Widget child;
  final bool registerMode;
  final VoidCallback? onBack;

  const _AuthCard({
    required this.ui,
    required this.child,
    required this.registerMode,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.divider.withValues(alpha: .92)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .36),
            blurRadius: 42,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: p.accent.withValues(alpha: .06),
            blurRadius: 60,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'رجوع',
                  icon: const Icon(Icons.arrow_forward_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            _AuthModeHeader(ui: ui, registerMode: registerMode),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _AuthModeHeader extends StatelessWidget {
  final AuthUiRuntime ui;
  final bool registerMode;

  const _AuthModeHeader({required this.ui, required this.registerMode});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final title = registerMode ? ui.registerTitle : ui.loginTitle;
    final subtitle = registerMode ? ui.registerSubtitle : ui.loginSubtitle;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: p.accent.withValues(alpha: .09),
            border: Border.all(color: p.accent.withValues(alpha: .18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                registerMode ? Icons.person_add_alt_1_rounded : Icons.lock_open_rounded,
                size: 14,
                color: p.accentBright,
              ),
              const SizedBox(width: 7),
              Text(
                registerMode ? 'حساب جديد' : 'تسجيل الدخول',
                style: TextStyle(
                  color: p.accentBright,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: p.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 12,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthFooter extends StatelessWidget {
  final AuthUiRuntime ui;
  const _AuthFooter({required this.ui});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.verified_user_outlined, size: 14, color: p.success),
        const SizedBox(width: 6),
        Text(
          ui.trustLabel,
          style: TextStyle(
            color: p.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  final AuthUiRuntime ui;
  const _AuthBackdrop({required this.ui});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.background,
            Color.lerp(p.background, p.secondary, .12) ?? p.background,
            p.background,
          ],
          stops: const [0, .52, 1],
        ),
      ),
      child: CustomPaint(
        painter: _AuthGlowPainter(
          primary: p.accent,
          secondary: p.secondaryBright,
          opacity: ui.patternOpacity,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AuthGlowPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final double opacity;

  const _AuthGlowPainter({
    required this.primary,
    required this.secondary,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glows = [
      (Offset(size.width * .13, size.height * .10), size.width * .42, primary),
      (Offset(size.width * .88, size.height * .76), size.width * .46, secondary),
    ];
    for (final glow in glows) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            glow.$3.withValues(alpha: opacity),
            glow.$3.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: glow.$1, radius: glow.$2));
      canvas.drawCircle(glow.$1, glow.$2, paint);
    }

    final linePaint = Paint()
      ..color = primary.withValues(alpha: opacity * .20)
      ..strokeWidth = 1;
    const gap = 68.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthGlowPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.opacity != opacity;
}
