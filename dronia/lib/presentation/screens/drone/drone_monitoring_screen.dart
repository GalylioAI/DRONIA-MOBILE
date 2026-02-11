import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../data/models/detection_model.dart';
import '../../../data/models/intervention_model.dart';
import '../../../data/services/detection_service.dart';
import '../../../data/services/intervention_service.dart';
import 'fullscreen_player_screen.dart';
import 'planned_interventions_screen.dart';

/// Live drone surveillance screen with video playback and detection
class DroneMonitoringScreen extends StatefulWidget {
  final String? droneId;

  const DroneMonitoringScreen({super.key, this.droneId});

  @override
  State<DroneMonitoringScreen> createState() => _DroneMonitoringScreenState();
}

class _DroneMonitoringScreenState extends State<DroneMonitoringScreen> {
  // Video player
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  // Screen capture
  final GlobalKey _videoGlobalKey = GlobalKey();
  String? _lastCaptureTime;
  bool _isCapturing = false;

  // Recording state
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Detection
  final DetectionService _detectionService = DetectionService();
  final InterventionService _interventionService = InterventionService();
  Timer? _detectionTimer;
  Detection? _currentDetection;
  final List<Detection> _recentDetections = [];
  bool _showDetectionAlert = false;
  int _pendingInterventionsCount = 0;

  // Mission state
  bool _isMissionActive = true;

  // Telemetry data (simulated)
  int _battery = 86;
  double _altitude = 43.3;
  double _speed = 12.0;
  final double _temperature = 22.1;
  Timer? _telemetryTimer;

  // Stats
  int _healthyCount = 4;
  int _detectionCount = 0;
  int _alertCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _startTelemetrySimulation();
    _loadRecentDetections();
    _loadPendingInterventionsCount();
  }

  Future<void> _loadPendingInterventionsCount() async {
    final count = await _interventionService.getPendingCount();
    if (mounted) {
      setState(() => _pendingInterventionsCount = count);
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset('assets/videos/pov.mp4');

    try {
      await _videoController.initialize();
      _videoController.setLooping(true);
      _videoController.play();

      setState(() {
        _isVideoInitialized = true;
      });

      // Start detection after video is ready
      _startDetection();
      _startRecording();
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _startRecording() {
    _isRecording = true;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordingSeconds++);
      }
    });
  }

  void _stopRecording() {
    _recordingTimer?.cancel();
    _isRecording = false;
  }

  void _startDetection() {
    // Run detection every 3-5 seconds
    _detectionTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!_isMissionActive || !mounted) return;

      final detection = await _detectionService.runDetection();

      if (detection != null && mounted) {
        // Save to history
        await _detectionService.saveDetection(detection);

        // Pause video when disease is detected
        if (detection.type == DetectionType.disease) {
          _videoController.pause();
        }

        setState(() {
          _currentDetection = detection;
          _recentDetections.insert(0, detection);
          if (_recentDetections.length > 5) {
            _recentDetections.removeLast();
          }
          _detectionCount++;

          if (detection.type == DetectionType.disease) {
            _alertCount++;
            _showDetectionAlert = true;
          }
        });

        // Hide alert after 2 seconds and resume video
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showDetectionAlert = false);
            // Resume video after alert is dismissed
            if (_isMissionActive) {
              _videoController.play();
            }
          }
        });
      }
    });
  }

  void _startTelemetrySimulation() {
    _telemetryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        // Simulate small variations
        _altitude += (DateTime.now().millisecond % 3 - 1) * 0.1;
        _speed += (DateTime.now().millisecond % 5 - 2) * 0.1;
        _altitude = _altitude.clamp(30.0, 50.0);
        _speed = _speed.clamp(8.0, 15.0);
      });
    });
  }

  Future<void> _loadRecentDetections() async {
    final history = await _detectionService.getDetectionHistory();
    if (mounted && history.isNotEmpty) {
      setState(() {
        _recentDetections.addAll(history.take(5));
        _detectionCount = history.length;
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _recordingTimer?.cancel();
    _detectionTimer?.cancel();
    _telemetryTimer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    int hours = _recordingSeconds ~/ 3600;
    int minutes = (_recordingSeconds % 3600) ~/ 60;
    int secs = _recordingSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleFullScreen() {
    // Navigate to separate fullscreen page
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullscreenPlayerScreen(
            videoController: _videoController,
            isRecording: _isRecording,
            recordingSeconds: _recordingSeconds,
            altitude: _altitude,
            speed: _speed,
            currentDetection: _currentDetection,
            showDetectionAlert: _showDetectionAlert,
            isMissionActive: _isMissionActive,
            onVoirPressed: () {
              if (_currentDetection != null) {
                _showDetectionDetailsDialog(_currentDetection!);
              }
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  /// Toggle mission - stops/starts the drone surveillance
  void _toggleMission() {
    setState(() {
      _isMissionActive = !_isMissionActive;
      if (_isMissionActive) {
        // Resume mission - restore values
        _battery = 86;
        _altitude = 31.0;
        _speed = 6.3;
        _videoController.play();
        _startRecording();
        _startTelemetrySimulation();
        _startDetection();
      } else {
        // Stop mission
        _videoController.pause();
        _stopRecording();
        _recordingSeconds = 0;
        _telemetryTimer?.cancel();
        _detectionTimer?.cancel();
        // Reset telemetry to 0
        _battery = 0;
        _altitude = 0;
        _speed = 0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMissionActive ? 'Mission reprise' : 'Mission arrêtée'),
        backgroundColor: _isMissionActive
            ? AppColors.primaryGreen
            : AppColors.error,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _dismissDetectionAlert() {
    setState(() {
      _showDetectionAlert = false;
    });
    // Resume video when alert is dismissed
    if (_isMissionActive) {
      _videoController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildQuickStats(),
                  const SizedBox(height: 12),
                  _buildVideoSection(),
                  const SizedBox(height: 12),
                  _buildScreenCaptureSection(),
                  const SizedBox(height: 12),
                  _buildDroneControlPalette(isFullScreen: false),
                  const SizedBox(height: 12),
                  _buildTelemetry(),
                  const SizedBox(height: 12),
                  _buildDetectionHistory(),
                ],
              ),
            ),
          ),
          // Detection Alert Overlay
          if (_showDetectionAlert && _currentDetection != null)
            _buildDetectionAlertOverlay(),
        ],
      ),
    );
  }

  /// Drone control palette for non-fullscreen mode - compact bar
  Widget _buildDroneControlPalette({bool isFullScreen = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Main control buttons
          _buildCompactButton(
            icon: Icons.arrow_upward,
            label: 'Monter',
            onTap: () => _onDroneCommand('up'),
          ),
          const SizedBox(width: 8),
          _buildCompactButton(
            icon: Icons.arrow_downward,
            label: 'Descendre',
            onTap: () => _onDroneCommand('down'),
          ),
          const SizedBox(width: 8),
          _buildCompactButton(
            icon: Icons.play_arrow,
            label: 'Avancer',
            onTap: () => _onDroneCommand('forward'),
            color: AppColors.primaryGreen,
          ),
          const Spacer(),
          // More options button
          GestureDetector(
            onTap: _showMoreControls,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Plus',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: buttonColor.withOpacity(0.3)),
        ),
        child: Icon(icon, color: buttonColor, size: 20),
      ),
    );
  }

  void _showMoreControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.gamepad,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Commandes Drone',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Voir moins',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Movement controls
              const Text(
                'Mouvement',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildOptionButton(Icons.keyboard_arrow_up, 'Avancer', () {
                    _onDroneCommand('forward');
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 6),
                  _buildOptionButton(Icons.keyboard_arrow_down, 'Reculer', () {
                    _onDroneCommand('backward');
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 6),
                  _buildOptionButton(Icons.keyboard_arrow_left, 'Gauche', () {
                    _onDroneCommand('left');
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 6),
                  _buildOptionButton(Icons.keyboard_arrow_right, 'Droite', () {
                    _onDroneCommand('right');
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              // Altitude controls
              const Text(
                'Altitude',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildOptionButton(Icons.arrow_upward, 'Monter', () {
                    _onDroneCommand('up');
                    Navigator.pop(context);
                  }),
                  const SizedBox(width: 6),
                  _buildOptionButton(Icons.arrow_downward, 'Descendre', () {
                    _onDroneCommand('down');
                    Navigator.pop(context);
                  }),
                ],
              ),
              const SizedBox(height: 12),
              // Actions
              const Text(
                'Actions',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildOptionButton(
                    _isMissionActive ? Icons.stop : Icons.play_arrow,
                    _isMissionActive ? 'Arrêter' : 'Reprendre',
                    () {
                      _toggleMission();
                      Navigator.pop(context);
                    },
                    color: _isMissionActive
                        ? AppColors.error
                        : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  _buildOptionButton(Icons.home, 'Retour Base', () {
                    _onDroneCommand('return_home');
                    Navigator.pop(context);
                  }, color: AppColors.warning),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    final buttonColor = color ?? AppColors.primaryGreen;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: buttonColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: buttonColor, size: 18),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(color: buttonColor, fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDroneCommand(String command) {
    // In production, this would send commands to the drone via API
    String message;
    switch (command) {
      case 'up':
        message = 'Drone: Monter';
        break;
      case 'down':
        message = 'Drone: Descendre';
        break;
      case 'forward':
        message = 'Drone: Avancer';
        break;
      case 'backward':
        message = 'Drone: Reculer';
        break;
      case 'left':
        message = 'Drone: Tourner à gauche';
        break;
      case 'right':
        message = 'Drone: Tourner à droite';
        break;
      case 'return_home':
        message = 'Drone: Retour au point de départ';
        break;
      default:
        message = 'Commande inconnue';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryGreen,
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _saveRecordingToGallery() {
    if (_isRecording) {
      _stopRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistrement sauvegardé dans la galerie'),
          backgroundColor: AppColors.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _startRecording();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enregistrement démarré'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildDetectionAlertOverlay() {
    final detection = _currentDetection!;
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : AppColors.warning;

    return Positioned(
      top: 100,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: color, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      detection.type == DetectionType.disease
                          ? 'Maladie!'
                          : 'Stress!',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismissDetectionAlert,
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                detection.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${(detection.confidence * 100).toStringAsFixed(0)}% • ${detection.zone}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _dismissDetectionAlert();
                    _showDetectionDetailsDialog(detection);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Voir', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Surveillance ',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: 'Drone',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analyse temps réel • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Calendar icon for planned interventions
        Stack(
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlannedInterventionsScreen(),
                  ),
                );
                // Refresh count when returning
                _loadPendingInterventionsCount();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
              ),
            ),
            if (_pendingInterventionsCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundDark,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    _pendingInterventionsCount > 9
                        ? '9+'
                        : '$_pendingInterventionsCount',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStat('$_healthyCount', 'Saines', AppColors.primaryGreen),
          _buildMiniStat('$_detectionCount', 'Détect.', AppColors.warning),
          _buildMiniStat('$_alertCount', 'Alertes', AppColors.error),
          _buildMiniStat('En vol', 'Statut', AppColors.info),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Video Player
            if (_isVideoInitialized)
              RepaintBoundary(
                key: _videoGlobalKey,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoPlayer(_videoController),
                ),
              )
            else
              Container(
                height: 220,
                width: double.infinity,
                color: Colors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primaryGreen),
                      SizedBox(height: 12),
                      Text(
                        'Chargement du flux...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            // Top overlay - badges
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _buildVideoBadge('LIVE', AppColors.error, true),
                  const SizedBox(width: 6),
                  _buildVideoBadge(
                    'REC $_formattedTime',
                    AppColors.error,
                    _isRecording,
                  ),
                  const Spacer(),
                  _buildVideoBadge(
                    '${_altitude.toStringAsFixed(1)}m',
                    AppColors.info,
                    false,
                  ),
                ],
              ),
            ),
            // Bottom overlay - controls
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildVideoControl(
                    _isMissionActive ? Icons.stop : Icons.play_arrow,
                    _toggleMission,
                    isRed: _isMissionActive,
                  ),
                  const SizedBox(width: 12),
                  _buildVideoControl(Icons.fullscreen, _toggleFullScreen),
                ],
              ),
            ),
            // Detection marker on video when disease detected
            if (_showDetectionAlert && _currentDetection != null)
              _buildDetectionMarkerOnVideo(),
          ],
        ),
      ),
    );
  }

  Future<void> _captureFrame() async {
    if (_isCapturing || !_isVideoInitialized) return;

    setState(() => _isCapturing = true);

    try {
      // Find the RenderRepaintBoundary
      final RenderRepaintBoundary? boundary =
          _videoGlobalKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary != null) {
        // Capture the image
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData != null) {
          final Uint8List pngBytes = byteData.buffer.asUint8List();

          // Save to gallery using gal package
          try {
            // First save to temp file
            final tempDir = await getTemporaryDirectory();
            final fileName =
                'drone_capture_${DateTime.now().millisecondsSinceEpoch}.png';
            final file = File('${tempDir.path}/$fileName');
            await file.writeAsBytes(pngBytes);

            // Then save to gallery
            await Gal.putImage(file.path, album: 'DronIA');

            // Clean up temp file
            await file.delete();

            if (mounted) {
              final now = DateTime.now();
              setState(() {
                _lastCaptureTime =
                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Capture enregistrée dans la galerie'),
                  backgroundColor: AppColors.primaryGreen,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error saving to gallery: $e');
            rethrow;
          }
        }
      }
    } catch (e) {
      debugPrint('Error capturing frame: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la capture: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Widget _buildScreenCaptureSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Capture Button - Compact gradient
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _isCapturing ? null : _captureFrame,
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.8),
                      AppColors.warning.withOpacity(0.6),
                      AppColors.error.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: _isCapturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCapturing ? 'Capture...' : 'Capturer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Zone',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Last capture status
          Expanded(
            flex: 3,
            child: Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _lastCaptureTime != null
                    ? AppColors.primaryGreen.withOpacity(0.1)
                    : AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _lastCaptureTime != null
                      ? AppColors.primaryGreen.withOpacity(0.3)
                      : AppColors.dividerColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastCaptureTime != null
                        ? Icons.check_circle
                        : Icons.info_outline,
                    color: _lastCaptureTime != null
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastCaptureTime != null
                              ? 'Capture enregistrée'
                              : 'Aucune capture',
                          style: TextStyle(
                            color: _lastCaptureTime != null
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _lastCaptureTime != null
                              ? 'À $_lastCaptureTime'
                              : 'Appuyez pour capturer',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBadge(String text, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? color : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive && text == 'LIVE')
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            text,
            style: TextStyle(
              color: isActive ? AppColors.white : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControl(
    IconData icon,
    VoidCallback onTap, {
    bool isRed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isRed
              ? AppColors.error.withOpacity(0.8)
              : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.white, size: 20),
      ),
    );
  }

  Widget _buildModeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Detection marker overlay on video - simple circled point
  Widget _buildDetectionMarkerOnVideo() {
    final detection = _currentDetection!;
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : AppColors.warning;

    return Positioned(
      // Position the marker at center of the video
      top: 90,
      left: 120,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.3),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetry() {
    // Simulated values for the new telemetry data
    final double humidity = 66.0;
    final double windSpeed = 6.3;
    final double surfaceScanned = 100.0;
    final double haTotal = 4.2;

    return Column(
      children: [
        // TÉLÉMÉTRIE & CAPTEURS Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sensors,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'TÉLÉMÉTRIE & CAPTEURS',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _isMissionActive
                          ? AppColors.primaryGreen.withOpacity(0.2)
                          : AppColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          color: _isMissionActive
                              ? AppColors.primaryGreen
                              : AppColors.error,
                          size: 6,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isMissionActive ? 'ACTIF' : 'INACTIF',
                          style: TextStyle(
                            color: _isMissionActive
                                ? AppColors.primaryGreen
                                : AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // DRONE STATUS Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.dividerColor.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: AppColors.warning,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'DRONE STATUS',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDroneStatusTile(
                            'Batterie',
                            '$_battery',
                            '%',
                            AppColors.primaryGreen,
                            _battery / 100,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDroneStatusTile(
                            'Altitude',
                            '${_altitude.toStringAsFixed(1)}',
                            'm',
                            AppColors.primaryGreen,
                            null,
                            subtitle: 'Optimal',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDroneStatusTile(
                            'Vitesse',
                            '${_speed.toStringAsFixed(1)}',
                            'm/s',
                            AppColors.textPrimary,
                            null,
                            subtitle:
                                '≈ ${(_speed * 3.6).toStringAsFixed(0)} km/h',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _buildGpsSignalTile()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // CONDITIONS ENVIRONNEMENTALES
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.public,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CONDITIONS ENVIRONNEMENTALES',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildEnvironmentRow(
                Icons.thermostat,
                AppColors.warning,
                'Température',
                '${_temperature.toStringAsFixed(1)}°C',
                'Idéal',
                AppColors.primaryGreen,
              ),
              const SizedBox(height: 8),
              _buildEnvironmentRow(
                Icons.water_drop,
                AppColors.info,
                'Humidité',
                '${humidity.toStringAsFixed(0)}%',
                null,
                null,
                showBar: true,
                barValue: humidity / 100,
              ),
              const SizedBox(height: 8),
              _buildEnvironmentRow(
                Icons.air,
                AppColors.primaryGreen,
                'Vent',
                '${windSpeed.toStringAsFixed(1)} km/h',
                'Faible',
                AppColors.primaryGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // STATISTIQUES MISSION
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'STATISTIQUES MISSION',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Surface Scannée
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Surface Scannée',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${surfaceScanned.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Progress bar with gradient
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, AppColors.warning],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildMissionStatTile(
                      '$_detectionCount',
                      'Détections',
                      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMissionStatTile(
                      '${(_detectionCount / haTotal).toStringAsFixed(1)}',
                      'Taux/ha',
                      AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMissionStatTile(
                      '$haTotal',
                      'ha total',
                      AppColors.info,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDroneStatusTile(
    String label,
    String value,
    String unit,
    Color valueColor,
    double? progress, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              Icon(
                label == 'Batterie' ? Icons.bolt : Icons.arrow_upward,
                color: AppColors.textSecondary,
                size: 12,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(valueColor),
                minHeight: 4,
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.arrow_drop_up,
                  color: AppColors.primaryGreen,
                  size: 14,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsSignalTile() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Signal GPS',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
              Icon(
                Icons.signal_cellular_alt,
                color: AppColors.textSecondary,
                size: 12,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSignalBar(AppColors.error),
              const SizedBox(width: 3),
              _buildSignalBar(AppColors.warning),
              const SizedBox(width: 3),
              _buildSignalBar(AppColors.warning),
              const SizedBox(width: 3),
              _buildSignalBar(AppColors.primaryGreen),
              const SizedBox(width: 3),
              _buildSignalBar(AppColors.dividerColor),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Excellent',
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBar(Color color) {
    return Container(
      width: 18,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildEnvironmentRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    String? status,
    Color? statusColor, {
    bool showBar = false,
    double barValue = 0,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor?.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (showBar)
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: barValue,
                  backgroundColor: AppColors.dividerColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.info,
                  ),
                  minHeight: 6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMissionStatTile(String value, String label, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionHistory() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.info, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Historique Détections',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (_recentDetections.isNotEmpty)
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.detectionHistory),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${_recentDetections.length} nouvelles',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentDetections.isEmpty)
            _buildEmptyDetections()
          else
            ..._recentDetections
                .take(3)
                .map((detection) => _buildDetectionItem(detection)),
        ],
      ),
    );
  }

  Widget _buildEmptyDetections() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 36,
            color: AppColors.primaryGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aucune détection',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Text(
            'Surveillance active',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionItem(Detection detection) {
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : detection.type == DetectionType.stress
        ? AppColors.warning
        : AppColors.primaryGreen;

    final icon = detection.type == DetectionType.disease
        ? Icons.bug_report
        : detection.type == DetectionType.stress
        ? Icons.warning_amber
        : Icons.check_circle;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      detection.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(detection.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${detection.zone} • ${_formatTime(detection.timestamp)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _showDetectionDetailsDialog(detection);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Détails',
              style: TextStyle(color: AppColors.info, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Show detection details dialog like the web version
  void _showDetectionDetailsDialog(Detection detection) {
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : detection.type == DetectionType.stress
        ? AppColors.warning
        : AppColors.primaryGreen;

    final icon = detection.type == DetectionType.disease
        ? Icons.bug_report
        : detection.type == DetectionType.stress
        ? Icons.warning_amber
        : Icons.check_circle;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Détails - ${detection.label}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Disease info row
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // Disease icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    // Name and date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            detection.label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Détecté le ${detection.timestamp.day.toString().padLeft(2, '0')}/${detection.timestamp.month.toString().padLeft(2, '0')}/${detection.timestamp.year} à ${_formatTime(detection.timestamp)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Confidence badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(detection.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Severity and Zone row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: AppColors.textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'SÉVÉRITÉ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'À évaluer',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textSecondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'ZONE',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detection.zone,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recommended treatment
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Traitement recommandé',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Consulter un expert agricole',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Prevention
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.info,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prévention',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Surveillance régulière des cultures',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action buttons - using Flexible to prevent overflow
              Row(
                children: [
                  Flexible(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _generatePdfReport(detection);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Générer rapport',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showLocationDialog(detection);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.dividerColor),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Voir carte',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show location dialog with grid map
  void _showLocationDialog(Detection detection) {
    // Generate random coordinates for demo
    final xCoord = (30 + (detection.label.hashCode % 40)).abs();
    final yCoord = (30 + (detection.zone.hashCode % 40)).abs();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Localisation - ${detection.label}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Grid map
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Stack(
                  children: [
                    // Grid
                    GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 1,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        // Highlight the cell with detection (center cell = 5)
                        final isDetected = index == 5;
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDetected
                                ? AppColors.error.withOpacity(0.3)
                                : AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDetected
                                  ? AppColors.error
                                  : AppColors.primaryGreen.withOpacity(0.3),
                              width: isDetected ? 2 : 1,
                            ),
                          ),
                          child: isDetected
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.priority_high,
                                      color: AppColors.white,
                                      size: 16,
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    // North indicator
                    Positioned(
                      top: 8,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'N',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Scale
                    Positioned(
                      bottom: 8,
                      left: 12,
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 3,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '50m',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Zone and Coordinates
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ZONE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          detection.zone,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COORDONNÉES',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'X: $xCoord% | Y: $yCoord%',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Plan intervention button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showInterventionPlanningDialog(detection);
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Planifier une intervention'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show intervention planning dialog
  void _showInterventionPlanningDialog(Detection detection) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String? selectedInterventionType;
    final notesController = TextEditingController();

    final interventionTypes = [
      'Traitement phytosanitaire',
      'Inspection manuelle',
      'Irrigation ciblée',
      'Prélèvement échantillon',
      'Application engrais',
      'Autre',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: const Text(
                          'Planifier une intervention',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Detection info
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      children: [
                        const TextSpan(text: 'Détection: '),
                        TextSpan(
                          text: detection.label,
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' (${(detection.confidence * 100).toStringAsFixed(0)}%)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date picker
                  const Text(
                    'Date',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primaryGreen,
                                surface: AppColors.cardDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedDate != null
                                ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                                : 'mm/dd/yyyy',
                            style: TextStyle(
                              color: selectedDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time picker
                  const Text(
                    'Heure',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primaryGreen,
                                surface: AppColors.cardDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setDialogState(() => selectedTime = time);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedTime != null
                                ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                : '--:--',
                            style: TextStyle(
                              color: selectedTime != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.access_time,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Intervention type dropdown
                  const Text(
                    'Type d\'intervention',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedInterventionType,
                        hint: const Text(
                          'Sélectionner...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        dropdownColor: AppColors.cardDark,
                        items: interventionTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(
                            () => selectedInterventionType = value,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  const Text(
                    'Notes',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ajoutez des notes ou instructions...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(
                              color: AppColors.dividerColor,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Validate required fields
                            if (selectedDate == null ||
                                selectedTime == null ||
                                selectedInterventionType == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Veuillez remplir tous les champs obligatoires',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            // Create intervention object
                            final intervention = Intervention(
                              id: _interventionService.generateId(),
                              detectionId: detection.id,
                              detectionLabel: detection.label,
                              detectionConfidence: detection.confidence,
                              zone: detection.zone,
                              scheduledDate: selectedDate!,
                              scheduledTime:
                                  '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}',
                              interventionType: selectedInterventionType!,
                              notes: notesController.text.isNotEmpty
                                  ? notesController.text
                                  : null,
                              createdAt: DateTime.now(),
                            );

                            // Save intervention
                            await _interventionService.saveIntervention(
                              intervention,
                            );

                            // Refresh count
                            _loadPendingInterventionsCount();

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Intervention planifiée pour ${detection.label}',
                                ),
                                backgroundColor: AppColors.primaryGreen,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error.withOpacity(0.9),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Planifier',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Generate and download PDF report for detection
  Future<void> _generatePdfReport(Detection detection) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      ),
    );

    try {
      final pdf = pw.Document();

      // Determine severity color
      final severityText = detection.confidence >= 0.9
          ? 'Critique'
          : detection.confidence >= 0.7
          ? 'Élevée'
          : 'Modérée';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green800,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DronIA',
                            style: pw.TextStyle(
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.Text(
                            'Rapport de Détection',
                            style: const pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'AGRONOMIE DE\nPRÉCISION',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // Detection title
                pw.Text(
                  'Détection: ${detection.label}',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Date and time
                pw.Text(
                  'Date: ${detection.timestamp.day.toString().padLeft(2, '0')}/${detection.timestamp.month.toString().padLeft(2, '0')}/${detection.timestamp.year} à ${detection.timestamp.hour.toString().padLeft(2, '0')}:${detection.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 30),

                // Info cards row
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildPdfInfoCard(
                        'Confiance',
                        '${(detection.confidence * 100).toStringAsFixed(0)}%',
                        PdfColors.red,
                      ),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: _buildPdfInfoCard(
                        'Sévérité',
                        severityText,
                        PdfColors.orange,
                      ),
                    ),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: _buildPdfInfoCard(
                        'Zone',
                        detection.zone,
                        PdfColors.blue,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),

                // Type section
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Type de Détection',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        detection.type == DetectionType.disease
                            ? 'Maladie végétale'
                            : detection.type == DetectionType.stress
                            ? 'Stress environnemental'
                            : 'État sain',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Recommendations section
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green200),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Traitement Recommandé',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '• Consulter un expert agricole pour évaluation\n'
                        '• Isoler la zone affectée si nécessaire\n'
                        '• Effectuer des prélèvements pour analyse',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Prevention section
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue200),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Mesures Préventives',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '• Surveillance régulière des cultures\n'
                        '• Maintenir une bonne rotation des cultures\n'
                        '• Optimiser l\'irrigation et le drainage',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                pw.Spacer(),

                // Footer
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Généré par DronIA',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Page 1/1',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Close loading dialog
      Navigator.pop(context);

      // Save and share PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'rapport_detection_${detection.label.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapport PDF généré avec succès'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  pw.Widget _buildPdfInfoCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}
