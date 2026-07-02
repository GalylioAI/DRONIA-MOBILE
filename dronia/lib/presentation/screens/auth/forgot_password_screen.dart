import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/service_locator.dart';
import '../../widgets/auth/auth_widgets.dart';

/// Three-step password reset flow backed by the VPS Next.js OTP endpoints:
///   1. POST /auth/forgot-password  (send 6-digit code by email, valid 15 min)
///   2. POST /auth/verify-otp       (verify the code)
///   3. POST /auth/reset-password   (set the new password)
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, otp, password }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.email;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final auth = services.auth;
      final email = _emailController.text.trim();
      switch (_step) {
        case _Step.email:
          await auth.requestPasswordReset(email);
          if (!mounted) return;
          UIHelper.showSnackBar(
            context,
            'Si cet e-mail existe, un code à 6 chiffres a été envoyé.',
            isSuccess: true,
          );
          setState(() => _step = _Step.otp);
        case _Step.otp:
          final ok = await auth.verifyResetOtp(
            email: email,
            otp: _otpController.text.trim(),
          );
          if (!ok) throw Exception('Code OTP incorrect.');
          if (!mounted) return;
          setState(() => _step = _Step.password);
        case _Step.password:
          await auth.resetPassword(
            email: email,
            newPassword: _passwordController.text,
          );
          if (!mounted) return;
          UIHelper.showSnackBar(
            context,
            'Mot de passe réinitialisé. Vous pouvez vous connecter.',
            isSuccess: true,
          );
          Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    } catch (e) {
      if (!mounted) return;
      UIHelper.showSnackBar(
        context,
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppColors.textSecondaryLight;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: titleColor),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _titleForStep(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitleForStep(),
                    style: TextStyle(fontSize: 14, color: subtitleColor),
                  ),
                  const SizedBox(height: 28),
                  ..._fieldsForStep(isDark),
                  const SizedBox(height: 24),
                  FuturisticButton(
                    text: _ctaForStep(),
                    onPressed: _isLoading ? () {} : _submit,
                    isLoading: _isLoading,
                  ),
                  if (_step != _Step.email) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _step = _Step.email),
                      child: Text(
                        'Recommencer avec un autre e-mail',
                        style: TextStyle(color: AppColors.primaryGreen),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep() => switch (_step) {
    _Step.email => 'Mot de passe oublié',
    _Step.otp => 'Vérification du code',
    _Step.password => 'Nouveau mot de passe',
  };

  String _subtitleForStep() => switch (_step) {
    _Step.email =>
      'Entrez votre e-mail. Nous vous enverrons un code à 6 chiffres valide 15 minutes.',
    _Step.otp => 'Saisissez le code reçu par e-mail.',
    _Step.password => 'Choisissez un mot de passe d\'au moins 6 caractères.',
  };

  String _ctaForStep() => switch (_step) {
    _Step.email => 'Envoyer le code',
    _Step.otp => 'Vérifier le code',
    _Step.password => 'Réinitialiser',
  };

  List<Widget> _fieldsForStep(bool isDark) {
    switch (_step) {
      case _Step.email:
        return [
          FuturisticTextField(
            controller: _emailController,
            label: 'EMAIL',
            hint: 'votre@email.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: Validators.email,
          ),
        ];
      case _Step.otp:
        return [
          FuturisticTextField(
            controller: _otpController,
            label: 'CODE OTP',
            hint: '123456',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.pin_outlined,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.length != 6 || int.tryParse(value) == null) {
                return 'Entrez les 6 chiffres reçus par e-mail';
              }
              return null;
            },
          ),
        ];
      case _Step.password:
        return [
          FuturisticTextField(
            controller: _passwordController,
            label: 'NOUVEAU MOT DE PASSE',
            hint: '••••••••',
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_outlined,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondaryLight,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 16),
          FuturisticTextField(
            controller: _confirmController,
            label: 'CONFIRMER',
            hint: '••••••••',
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_outlined,
            validator: (v) {
              if (v != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
        ];
    }
  }
}
