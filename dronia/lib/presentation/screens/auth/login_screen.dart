import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../data/services/service_locator.dart';
import '../../widgets/auth/auth_widgets.dart';

/// Modern futuristic login screen with animated background
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

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
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
        backgroundColor: Colors.red.shade700,
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

      // Login successful - navigate to home
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (!mounted) return;

      // Handle errors with more detail
      String message = 'Erreur de connexion';
      final errorStr = e.toString();
      final errorStrLower = errorStr.toLowerCase();

      // Check for common backend messages
      if (errorStr.contains('Email ou mot de passe incorrect')) {
        message = 'Email ou mot de passe incorrect';
      } else if (errorStrLower.contains('not found') ||
          errorStrLower.contains('404')) {
        message = 'Compte non trouvé. Vérifiez votre email.';
      } else if (errorStrLower.contains('invalid') ||
          errorStrLower.contains('401') ||
          errorStrLower.contains('unauthorized')) {
        message = 'Email ou mot de passe incorrect';
      } else if (errorStrLower.contains('network') ||
          errorStrLower.contains('socket') ||
          errorStrLower.contains('connection')) {
        message = 'Erreur réseau. Vérifiez votre connexion internet.';
      } else if (errorStrLower.contains('timeout')) {
        message = 'Serveur lent. Réessayez.';
      } else if (errorStrLower.contains('500') ||
          errorStrLower.contains('server')) {
        message = 'Erreur serveur. Réessayez plus tard.';
      } else {
        // Show actual error for debugging
        message =
            'Erreur: ${errorStr.replaceAll('ApiException: ', '').replaceAll('Exception: ', '')}';
      }

      _showErrorSnackbar(message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const SizedBox(height: 60),
                      _buildLogo(),
                      const SizedBox(height: 40),
                      _buildWelcomeText(),
                      const SizedBox(height: 40),
                      GlassCard(
                        child: Column(
                          children: [
                            _buildForm(),
                            const SizedBox(height: 24),
                            FuturisticButton(
                              onPressed: _handleLogin,
                              isLoading: _isLoading,
                              text: 'SE CONNECTER',
                              icon: Icons.login_rounded,
                            ),
                            const SizedBox(height: 16),
                            _buildForgotPassword(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildSocialLogin(),
                      const SizedBox(height: 32),
                      _buildRegisterLink(),
                      const SizedBox(height: 60),
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
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/Icone.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          'Bienvenue',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connectez-vous pour accéder à DronIA',
          style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildForm() {
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
        const SizedBox(height: 20),
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
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          validator: Validators.password,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleLogin(),
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          // TODO: Implement forgot password
        },
        child: Text(
          'Mot de passe oublié ?',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OU',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: Colors.white.withOpacity(0.1)),
        ),
      ],
    );
  }

  Widget _buildSocialLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(Icons.g_mobiledata_rounded, 'Google'),
        const SizedBox(width: 16),
        _buildSocialButton(Icons.apple_rounded, 'Apple'),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon, String label) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Pas encore de compte ? ",
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.register),
          child: const Text(
            "S'inscrire",
            style: TextStyle(
              color: Color(0xFF4CAF50),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
