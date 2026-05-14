import 'package:flutter/material.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/service_locator.dart';
import '../../widgets/auth/auth_widgets.dart';

/// Login screen — theme-aware (light + dark).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1100),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await services.auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar(_friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyErrorMessage(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (raw.contains('Email ou mot de passe incorrect')) {
      return 'Email ou mot de passe incorrect';
    }
    if (lower.contains('not found') || lower.contains('404')) {
      return 'Compte non trouvé. Vérifiez votre email.';
    }
    if (lower.contains('invalid') ||
        lower.contains('401') ||
        lower.contains('unauthorized')) {
      return 'Email ou mot de passe incorrect';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return 'Erreur réseau. Vérifiez votre connexion internet.';
    }
    if (lower.contains('timeout')) return 'Serveur lent. Réessayez.';
    if (lower.contains('500') || lower.contains('server')) {
      return 'Erreur serveur. Réessayez plus tard.';
    }
    return 'Erreur: ${raw.replaceAll('ApiException: ', '').replaceAll('Exception: ', '')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : AppColors.textSecondaryLight;
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.textHintLight;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      _buildLogo(),
                      const SizedBox(height: 28),
                      _buildWelcomeText(titleColor, subtitleColor),
                      const SizedBox(height: 28),
                      GlassCard(
                        child: Column(
                          children: [
                            _buildForm(isDark),
                            const SizedBox(height: 20),
                            FuturisticButton(
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                              text: 'SE CONNECTER',
                              icon: Icons.login_rounded,
                            ),
                            const SizedBox(height: 8),
                            _buildForgotPassword(mutedColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildRegisterLink(subtitleColor),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/images/Logo_DronIA-11.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText(Color titleColor, Color subtitleColor) {
    return Column(
      children: [
        Text(
          'Bienvenue',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: titleColor,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Connectez-vous pour accéder à DronIA',
          style: TextStyle(fontSize: 14, color: subtitleColor),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    return Column(
      children: [
        FuturisticTextField(
          controller: _emailController,
          label: 'EMAIL',
          hint: 'votre@email.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: Validators.email,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: 16),
        FuturisticTextField(
          controller: _passwordController,
          label: 'MOT DE PASSE',
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
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleLogin(),
        ),
      ],
    );
  }

  Widget _buildForgotPassword(Color color) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        child: Text(
          'Mot de passe oublié ?',
          style: TextStyle(color: color, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(Color subtitleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pas encore de compte ? ',
          style: TextStyle(color: subtitleColor, fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text(
            "S'inscrire",
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
