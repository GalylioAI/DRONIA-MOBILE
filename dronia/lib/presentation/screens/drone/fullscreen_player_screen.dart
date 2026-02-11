import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/detection_model.dart';
import '../../../data/services/detection_service.dart';

class FullscreenPlayerScreen extends StatefulWidget {
  final VideoPlayerController videoController;
  final bool isRecording;
  final int recordingSeconds;
  final double altitude;
  final double speed;
  final Detection? currentDetection;
  final bool showDetectionAlert;
  final bool isMissionActive;
  final VoidCallback? onVoirPressed;

  const FullscreenPlayerScreen({
    Key? key,
    required this.videoController,
    required this.isRecording,
    required this.recordingSeconds,
    required this.altitude,
    required this.speed,
    this.currentDetection,
    this.showDetectionAlert = false,
    this.isMissionActive = true,
    this.onVoirPressed,
  }) : super(key: key);

  @override
  State<FullscreenPlayerScreen> createState() => _FullscreenPlayerScreenState();
}

class _FullscreenPlayerScreenState extends State<FullscreenPlayerScreen> {
  late int _currentSeconds;
  Timer? _timer;
  Timer? _alertTimer;
  Timer? _detectionTimer;
  bool _showAlert = false;
  Detection? _currentDetection;
  final DetectionService _detectionService = DetectionService();

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.recordingSeconds;
    _currentDetection = widget.currentDetection;

    // Show alert if there's a current detection when entering fullscreen
    if (widget.currentDetection != null) {
      _showAlert = true;
      _startAlertTimer();
    }

    // Start timer to update recording time
    if (widget.isMissionActive) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _currentSeconds++);
        }
      });

      // Start detection simulation in fullscreen
      _startDetection();
    }

    // Force landscape and hide system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startDetection() {
    // Run detection every 4 seconds
    _detectionTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!widget.isMissionActive || !mounted) return;

      final detection = await _detectionService.runDetection();

      if (detection != null && mounted) {
        // Pause video when disease is detected
        if (detection.type == DetectionType.disease) {
          widget.videoController.pause();
        }

        setState(() {
          _currentDetection = detection;
          if (detection.type == DetectionType.disease) {
            _showAlert = true;
          }
        });

        // Start timer to hide alert
        _startAlertTimer();
      }
    });
  }

  void _startAlertTimer() {
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showAlert = false);
        // Resume video after alert is dismissed
        if (widget.isMissionActive) {
          widget.videoController.play();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    _detectionTimer?.cancel();
    // Restore portrait and system UI
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String get _formattedTime {
    int hours = _currentSeconds ~/ 3600;
    int minutes = (_currentSeconds % 3600) ~/ 60;
    int secs = _currentSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _exitFullScreen() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _exitFullScreen();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _exitFullScreen,
          child: Stack(
            children: [
              // Video fills entire screen
              Positioned.fill(
                child: widget.videoController.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: widget.videoController.value.size.width,
                          height: widget.videoController.value.size.height,
                          child: VideoPlayer(widget.videoController),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      ),
              ),
              // Top overlay - status badges (left side)
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadge(
                      'LIVE',
                      AppColors.error,
                      widget.isMissionActive,
                    ),
                    const SizedBox(height: 6),
                    _buildBadge(
                      'REC $_formattedTime',
                      AppColors.error,
                      widget.isMissionActive,
                    ),
                  ],
                ),
              ),
              // Top right - telemetry badges
              Positioned(
                top: 16,
                right: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildBadge(
                      '${widget.altitude.toStringAsFixed(1)}m',
                      AppColors.info,
                      false,
                    ),
                    const SizedBox(height: 6),
                    _buildBadge(
                      '${widget.speed.toStringAsFixed(1)}m/s',
                      AppColors.warning,
                      false,
                    ),
                  ],
                ),
              ),
              // Exit button - bottom right corner
              Positioned(
                bottom: 20,
                right: 20,
                child: GestureDetector(
                  onTap: _exitFullScreen,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              // Hint text at bottom left
              Positioned(
                bottom: 20,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Appuyez pour quitter le plein écran',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
              // Legend bar - Sain | Stress | Maladie
              Positioned(
                bottom: 70,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendChip('Sain', AppColors.primaryGreen),
                      const SizedBox(width: 6),
                      _buildLegendChip('Stress', AppColors.warning),
                      const SizedBox(width: 6),
                      _buildLegendChip('Maladie', AppColors.error),
                    ],
                  ),
                ),
              ),
              // Detection marker on video when disease detected
              if (_showAlert && _currentDetection != null)
                _buildDetectionMarkerOnVideo(),
              // Detection alert popup (same as main screen)
              if (_showAlert && _currentDetection != null)
                _buildDetectionAlertPopup(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool showPulse) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPulse) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
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
      top: 150,
      left: 200,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.3),
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  /// Detection alert popup - similar to main screen but for landscape
  Widget _buildDetectionAlertPopup() {
    final detection = _currentDetection!;
    final color = detection.type == DetectionType.disease
        ? AppColors.error
        : AppColors.warning;

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 16,
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
                  onTap: () => setState(() => _showAlert = false),
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
                  _exitFullScreen();
                  widget.onVoirPressed?.call();
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
    );
  }
}
