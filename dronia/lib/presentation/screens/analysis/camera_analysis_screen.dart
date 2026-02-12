import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CameraAnalysisScreen extends StatelessWidget {
  const CameraAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Camera Analysis'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Camera Analysis - Coming Soon',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
