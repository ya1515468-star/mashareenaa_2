import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/monitoring/error_monitor.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium/effects.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_text_field.dart';
import '../widgets/premium/remember_me_checkbox.dart';
import '../widgets/premium/social_login_row.dart';
import '../widgets/tailor_auth_runtime.dart';
import '../widgets/tailor_auth_scaffold.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _localSession = LocalSessionService();
  bool? _rememberMeOverride;

  @override
  void initState() {
    super.initState();
    _restoreRememberedEmail();
  }

  Future<void> _restoreRememberedEmail() async {
    final email = await _localSession.getRememberedEmail();
    if (email == null || !mounted) return;
    _emailController.text = email;
    setState(() => _rememberMeOverride = true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(bool rememberMe) async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    final success = await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (success) {
      if (rememberMe) {
        await _localSession.saveRememberedEmail(_emailController.text.trim());
      } else {
        await _localSession.clearRememberedEmail();
      }
      return;
    }

    if (!mounted) return;
    _shakeKey.currentState?.shake();
    final error = ref.read(authControllerProvider);
    final message = error.error?.toString() ?? 'فشل تسجيل الدخول';
    final requiresConfirmation = message.contains('تأكيد البريد');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: requiresConfirmation
            ? SnackBarAction(
                label: 'إعادة الإرسال',
                onPressed: () async {
                  final resend = await ref
                      .read(authControllerProvider.notifier)
                      .resendSignupConfirmationEmail(
                        _emailController.text.trim(),
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        resend ??
                            'تمت إعادة إرسال رسالة تأكيد البريد الإلكتروني',
                      ),
                    ),
                  );
                },
              )
            : null,
      ),
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const RegisterPage(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(.04, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ErrorMonitor.setScreen('auth.login');
    final ui = ref.watch(authUiRuntimeProvider).value ?? AuthUiRuntime.fallback;
    final authState = ref.watch(authControllerProvider);

    return Theme(
      data: AppTheme.fromPalette(ui.palette),
      child: TailorAuthScaffold(
        ui: ui,
        registerMode: false,
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AuthIntentRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'دخول آمن وسريع',
                  subtitle: 'استخدم بيانات حسابك للوصول إلى مساحتك.',
                ),
                const SizedBox(height: 18),
                AutofillGroup(
                  child: Column(
                    children: [
                      PremiumTextField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.alternate_email_rounded,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          if (!text.contains('@') || !text.contains('.')) {
                            return 'صيغة البريد الإلكتروني غير صحيحة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 13),
                      PremiumTextField(
                        controller: _passwordController,
                        label: 'كلمة المرور',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) =>
                            value == null || value.isEmpty
                                ? 'الرجاء إدخال كلمة المرور'
                                : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    RememberMeCheckbox(
                      value: _rememberMeOverride ?? false,
                      onChanged: (value) =>
                          setState(() => _rememberMeOverride = value),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PremiumButton(
                  label: ui.loginButton,
                  isLoading: authState.isLoading,
                  onPressed: () => _submit(_rememberMeOverride ?? false),
                ),
                const SizedBox(height: 18),
                SocialLoginRow(
                  showAppleButton: true,
                  onError: (message) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  ),
                ),
                const SizedBox(height: 18),
                _AuthSwitchButton(
                  text: ui.switchToRegister,
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: _openRegister,
                ),
                const SizedBox(height: 13),
                _SecurityNote(text: ui.securityNote),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthIntentRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AuthIntentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: p.background.withValues(alpha: .32),
        border: Border.all(color: p.divider.withValues(alpha: .86)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: p.accent.withValues(alpha: .10),
            ),
            child: Icon(icon, size: 18, color: p.accentBright),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthSwitchButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _AuthSwitchButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: p.accentBright,
        side: BorderSide(color: p.accent.withValues(alpha: .42)),
        backgroundColor: p.surfaceHighlight.withValues(alpha: .22),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final String text;

  const _SecurityNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_outlined, color: p.success, size: 14),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textMuted,
              fontSize: 10.3,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
