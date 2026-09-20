import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/local_session_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/monitoring/error_monitor.dart';
import '../../domain/usecases/check_username_available_usecase.dart';
import '../../domain/usecases/create_username_pin_usecase.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium/effects.dart';
import '../widgets/premium/password_widgets.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_text_field.dart';
import '../widgets/premium/social_login_row.dart';
import '../widgets/tailor_auth_runtime.dart';
import '../widgets/tailor_auth_scaffold.dart';
import 'email_verification_code_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

enum _UsernameStatus { idle, checking, available, taken, invalid }

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _referralController = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  final _localSession = LocalSessionService();

  bool _passwordFocused = false;
  bool _enableQuickPin = true;
  bool _submitting = false;
  bool _advancedOpen = false;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_refreshPasswordUi);
    _confirmController.addListener(_refreshPasswordUi);
  }

  void _refreshPasswordUi() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      setState(() => _usernameStatus = _UsernameStatus.idle);
      return;
    }
    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      final useCase = sl<CheckUsernameAvailableUseCase>();
      final result = await useCase(normalized);
      if (!mounted) return;
      result.fold(
        (_) => setState(() => _usernameStatus = _UsernameStatus.invalid),
        (available) => setState(() => _usernameStatus =
            available ? _UsernameStatus.available : _UsernameStatus.taken),
      );
    });
  }

  String? _usernameHintText() => switch (_usernameStatus) {
        _UsernameStatus.checking => 'جارٍ فحص الاسم على الخادم…',
        _UsernameStatus.available => 'الاسم متاح ✓',
        _UsernameStatus.taken => 'الاسم محجوز، اختر اسمًا آخر',
        _UsernameStatus.invalid => 'اسم المستخدم غير صالح',
        _UsernameStatus.idle => null,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    if (_usernameController.text.trim().isNotEmpty &&
        _usernameStatus != _UsernameStatus.available) {
      _shakeKey.currentState?.shake();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار اسم مستخدم متاح، أو تركه فارغًا')),
      );
      return;
    }

    setState(() => _submitting = true);
    final signedUp = await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

    if (!signedUp) {
      if (mounted) {
        setState(() => _submitting = false);
        _shakeKey.currentState?.shake();
        final error = ref.read(authControllerProvider);
        final raw = error.error?.toString().toLowerCase() ?? '';
        final message = raw.contains('confirm') ||
                raw.contains('email') ||
                raw.contains('تأكيد البريد')
            ? 'يرجى تأكيد البريد الإلكتروني ثم المتابعة.'
            : error.error?.toString() ?? 'تعذر إنشاء الحساب الآن.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    final user = ref.read(authControllerProvider).value;
    final uid = user?.uid;
    if (uid != null &&
        _usernameController.text.trim().isNotEmpty &&
        _pinController.text.isNotEmpty &&
        Supabase.instance.client.auth.currentSession != null) {
      final createUseCase = sl<CreateUsernamePinUseCase>();
      final result = await createUseCase(
        CreateUsernamePinParams(
          uid: uid,
          username: _usernameController.text.trim(),
          pin: _pinController.text.trim(),
        ),
      );
      final created = result.fold((_) => false, (_) => true);
      if (created && _enableQuickPin) await _localSession.enableQuickPinFor(uid);
    }

    if (!mounted || uid == null) return;
    setState(() => _submitting = false);

    if (Supabase.instance.client.auth.currentSession == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationCodePage(
            uid: uid,
            email: _emailController.text.trim(),
            referralUsername: _referralController.text.trim(),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openLogin() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    ErrorMonitor.setScreen('auth.register');
    final ui = ref.watch(authUiRuntimeProvider).value ?? AuthUiRuntime.fallback;
    final p = context.palette;

    return Theme(
      data: AppTheme.fromPalette(ui.palette),
      child: TailorAuthScaffold(
        ui: ui,
        registerMode: true,
        onBack: _openLogin,
        child: ShakeWidget(
          key: _shakeKey,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _RegistrationIntro(),
                const SizedBox(height: 18),
                AutofillGroup(
                  child: Column(
                    children: [
                      PremiumTextField(
                        controller: _nameController,
                        label: 'الاسم الكامل',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'الرجاء إدخال الاسم'
                            : null,
                      ),
                      const SizedBox(height: 13),
                      PremiumTextField(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.alternate_email_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'صيغة البريد الإلكتروني غير صحيحة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 13),
                      Focus(
                        onFocusChange: (focused) =>
                            setState(() => _passwordFocused = focused),
                        child: PremiumTextField(
                          controller: _passwordController,
                          label: 'كلمة المرور',
                          obscureText: true,
                          prefixIcon: Icons.lock_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null ||
                                  v.length < AppValidation.minPasswordLength
                              ? 'كلمة المرور قصيرة جدًا'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                PasswordStrengthPanel(
                  password: _passwordController.text,
                  visible: _passwordFocused || _passwordController.text.isNotEmpty,
                ),
                const SizedBox(height: 10),
                PremiumTextField(
                  controller: _confirmController,
                  label: 'تأكيد كلمة المرور',
                  obscureText: true,
                  prefixIcon: Icons.lock_reset_outlined,
                  textInputAction: TextInputAction.done,
                  validator: (v) => v != _passwordController.text
                      ? 'كلمتا المرور غير متطابقتين'
                      : null,
                ),
                PasswordMatchIndicator(
                  password: _passwordController.text,
                  confirmPassword: _confirmController.text,
                ),
                const SizedBox(height: 17),
                _SectionToggle(
                  open: _advancedOpen,
                  onTap: () => setState(() => _advancedOpen = !_advancedOpen),
                  accent: p.accent,
                  title: 'خيارات إضافية',
                  subtitle: 'اسم مستخدم، PIN سريع، وكود دعوة — كلها اختيارية',
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _advancedOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        PremiumTextField(
                          controller: _usernameController,
                          label: 'اسم المستخدم (اختياري)',
                          prefixIcon: Icons.alternate_email_rounded,
                          onChanged: _onUsernameChanged,
                          suffixWidget: _usernameStatus == _UsernameStatus.checking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                        ),
                        if (_usernameHintText() != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6, right: 4),
                              child: Text(
                                _usernameHintText()!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _usernameStatus == _UsernameStatus.available
                                      ? p.success
                                      : _usernameStatus == _UsernameStatus.idle
                                          ? p.textMuted
                                          : p.error,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        PremiumTextField(
                          controller: _pinController,
                          label: 'PIN سريع (اختياري)',
                          obscureText: true,
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (v.length != AppValidation.pinLength) {
                              return 'PIN يجب أن يكون ${AppValidation.pinLength} خانات';
                            }
                            return null;
                          },
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _enableQuickPin,
                          onChanged: (value) =>
                              setState(() => _enableQuickPin = value),
                          title: Text(
                            'تفعيل PIN السريع على هذا الجهاز',
                            style: TextStyle(color: p.textSecondary, fontSize: 12),
                          ),
                          activeThumbColor: p.accent,
                        ),
                        PremiumTextField(
                          controller: _referralController,
                          label: 'كود الدعوة (اختياري)',
                          prefixIcon: Icons.card_giftcard_outlined,
                        ),
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
                const SizedBox(height: 18),
                PremiumButton(
                  label: ui.registerButton,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
                SocialLoginRow(
                  showAppleButton: true,
                  onError: (message) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(ui.switchToLogin, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.accentBright,
                    side: BorderSide(color: p.accent.withValues(alpha: .42)),
                    backgroundColor: p.surfaceHighlight.withValues(alpha: .22),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                _SecurityNote(
                  text: ui.securityNote,
                  icon: Icons.shield_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionToggle extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  final Color accent;
  final String title;
  final String subtitle;

  const _SectionToggle({
    required this.open,
    required this.onTap,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: p.surfaceHighlight.withValues(alpha: .22),
            border: Border.all(color: p.divider.withValues(alpha: .86)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: accent.withValues(alpha: .10),
                ),
                child: Icon(
                  open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 19,
                  color: accent,
                ),
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
                        fontSize: 10.3,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 19,
                color: p.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationIntro extends StatelessWidget {
  const _RegistrationIntro();

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
            child: Icon(Icons.verified_user_outlined, size: 18, color: p.accentBright),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'أنشئ حسابك بخطوات قليلة. التحقق والهوية وحالة الجلسة تُدار عبر الخادم.',
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 10.7,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  final String text;
  final IconData icon;

  const _SecurityNote({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: p.success, size: 14),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textMuted, fontSize: 10.3, height: 1.4),
          ),
        ),
      ],
    );
  }
}
