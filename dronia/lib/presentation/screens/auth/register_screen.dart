import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/models/models.dart';
import '../../../data/services/service_locator.dart';
import '../../widgets/auth/auth_widgets.dart';
import 'fullscreen_map_picker.dart';

/// Modern futuristic register screen with animated background
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // New fields
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String? _selectedCulture;
  final List<String> _cultureTypes = [
    'Blé',
    'Orge',
    'Olivier',
    'Tomate',
    'Pomme de terre',
    'Vigne',
    'Agrumes',
    'Amandier',
    'Palmier dattier',
    'Légumes',
    'Fruits',
    'Céréales',
    'Autre',
  ];
  double _selectedLat = 34.0;
  double _selectedLng = 9.0;
  String? _locationLabel;

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Convert profile image to base64 if selected
      String? profileImageBase64;
      if (_profileImage != null) {
        final bytes = await _profileImage!.readAsBytes();
        profileImageBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      await services.auth.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        plantTypes: _selectedCulture != null ? [_selectedCulture!] : null,
        profileImage: profileImageBase64,
        location: Location(lat: _selectedLat, lng: _selectedLng),
      );

      if (!mounted) return;
      UIHelper.showSnackBar(
        context,
        'Inscription réussie ! Bienvenue sur DronIA.',
        isSuccess: true,
      );
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      UIHelper.showSnackBar(
        context,
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
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
                      const SizedBox(height: 20),
                      _buildBackButton(),
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      GlassCard(
                        child: Column(
                          children: [
                            _buildForm(),
                            const SizedBox(height: 24),
                            FuturisticButton(
                              onPressed: _handleRegister,
                              isLoading: _isLoading,
                              text: "FINALISER L'INSCRIPTION",
                              icon: Icons.person_add_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTermsText(),
                      const SizedBox(height: 24),
                      _buildLoginLink(),
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

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/Drone_Logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Créer un Compte',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rejoignez DronIA',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Name row
        Row(
          children: [
            Expanded(
              child: FuturisticTextField(
                controller: _firstNameController,
                label: 'PRÉNOM',
                hint: 'Jean',
                prefixIcon: Icons.person_outlined,
                validator: Validators.name,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FuturisticTextField(
                controller: _lastNameController,
                label: 'NOM',
                hint: 'Dupont',
                prefixIcon: Icons.person_outlined,
                validator: Validators.name,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Profile photo picker
        _buildProfilePhotoPicker(),
        const SizedBox(height: 16),

        FuturisticTextField(
          controller: _emailController,
          label: 'EMAIL',
          hint: 'jean.dupont@email.com',
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.email_outlined,
          validator: Validators.email,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        FuturisticTextField(
          controller: _phoneController,
          label: 'TÉLÉPHONE (optionnel)',
          hint: '+216 XX XXX XXX',
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: Validators.optionalPhone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        FuturisticTextField(
          controller: _passwordController,
          label: 'MOT DE PASSE',
          hint: 'Min 8 caractères',
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
          validator: Validators.strongPassword,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        FuturisticTextField(
          controller: _confirmPasswordController,
          label: 'CONFIRMER MOT DE PASSE',
          hint: 'Répéter le mot de passe',
          obscureText: _obscureConfirmPassword,
          prefixIcon: Icons.lock_outlined,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
            onPressed: () {
              setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              );
            },
          ),
          validator: Validators.confirmPassword(_passwordController.text),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),

        // Culture type dropdown
        _buildCultureTypeDropdown(),
        const SizedBox(height: 16),

        // Location picker
        _buildLocationPicker(),
      ],
    );
  }

  Widget _buildProfilePhotoPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                image: _profileImage != null
                    ? DecorationImage(
                        image: FileImage(_profileImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _profileImage == null
                  ? Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white.withOpacity(0.5),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'PHOTO DE PROFIL ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextSpan(
                          text: '(optionnel)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliquez pour ajouter une photo',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCultureTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TYPE DE CULTURE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCulture,
              hint: Row(
                children: [
                  Icon(
                    Icons.grass_outlined,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sélectionner une culture...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              dropdownColor: const Color(0xFF1E293B),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withOpacity(0.5),
              ),
              items: _cultureTypes.map((culture) {
                return DropdownMenuItem<String>(
                  value: culture,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.grass_outlined,
                        color: Color(0xFF4CAF50),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        culture,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCulture = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LOCALISATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 1,
              ),
            ),
            GestureDetector(
              onTap: _isGettingLocation ? null : _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGettingLocation)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4CAF50),
                        ),
                      )
                    else
                      const Icon(
                        Icons.my_location,
                        color: Color(0xFF4CAF50),
                        size: 14,
                      ),
                    const SizedBox(width: 4),
                    const Text(
                      'Ma position',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openFullscreenMap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Stack(
                children: [
                  // Interactive Map
                  IgnorePointer(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_selectedLat, _selectedLng),
                        initialZoom: 10,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'com.dronia.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_selectedLat, _selectedLng),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Color(0xFF4CAF50),
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Fullscreen button overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  // Coordinates overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _locationLabel ?? 'Position sélectionnée',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  // Tap instruction
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 50,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Appuyez pour ouvrir la carte',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFullscreenMap() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMapPicker(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLat = result['lat']!;
        _selectedLng = result['lng']!;
        _locationLabel = result['label'] as String?;
      });
    }
  }

  bool _isGettingLocation = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          UIHelper.showSnackBar(
            context,
            'Veuillez activer les services de localisation',
            isError: true,
          );
        }
        setState(() => _isGettingLocation = false);
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            UIHelper.showSnackBar(
              context,
              'Permission de localisation refusée',
              isError: true,
            );
          }
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          UIHelper.showSnackBar(
            context,
            'Permission refusée. Activez-la dans les paramètres.',
            isError: true,
          );
        }
        setState(() => _isGettingLocation = false);
        return;
      }

      // Get current position - use LOW accuracy for faster response
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('Délai dépassé'),
          );

      if (mounted) {
        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _isGettingLocation = false;
        });
        UIHelper.showSnackBar(
          context,
          'Position obtenue avec succès',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGettingLocation = false);
        String errorMsg = 'Impossible d\'obtenir la position';
        if (e.toString().contains('Délai')) {
          errorMsg = 'Délai dépassé. Réessayez à l\'extérieur.';
        }
        UIHelper.showSnackBar(context, errorMsg, isError: true);
      }
    }
  }

  Widget _buildTermsText() {
    return Text.rich(
      TextSpan(
        text: "En créant un compte, vous acceptez nos ",
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        children: [
          TextSpan(
            text: "Conditions d'utilisation",
            style: TextStyle(
              color: const Color(0xFF4CAF50).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: " et notre "),
          TextSpan(
            text: "Politique de confidentialité",
            style: TextStyle(
              color: const Color(0xFF4CAF50).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const TextSpan(text: "."),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Déjà un compte ? ",
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            "Se connecter",
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
