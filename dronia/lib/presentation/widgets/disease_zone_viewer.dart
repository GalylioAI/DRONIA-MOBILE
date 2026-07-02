import 'dart:io';
import 'dart:math' show min;
import 'dart:ui' as ui show decodeImageFromList;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// CustomPainter — contours organiques rouges (style pathologie végétale).
/// Utilise les points de contour OpenCV fournis par le backend (champ
/// `contourPoints` de chaque zone), ou un rectangle de fallback si absent.
class DiseaseZonePainter extends CustomPainter {
  final List<Map<String, dynamic>> zones;
  final double glowOpacity;

  const DiseaseZonePainter({required this.zones, this.glowOpacity = 0.6});

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      final pts = zone['contourPoints'] as List<dynamic>?;

      if (pts != null && pts.length >= 3) {
        // Contour organique depuis les points OpenCV
        final path = Path();
        for (int i = 0; i < pts.length; i++) {
          final pt = pts[i] as List<dynamic>;
          final dx = (pt[0] as num).toDouble() / 100 * size.width;
          final dy = (pt[1] as num).toDouble() / 100 * size.height;
          if (i == 0) { path.moveTo(dx, dy); }
          else        { path.lineTo(dx, dy); }
        }
        path.close();

        // Remplissage rouge translucide
        canvas.drawPath(path,
          Paint()
            ..color = const Color(0xFFFF2222).withValues(alpha: 0.22)
            ..style = PaintingStyle.fill);

        // Halo glow extérieur pulsant
        canvas.drawPath(path,
          Paint()
            ..color = const Color(0xFFFF1111).withValues(alpha: glowOpacity * 0.40)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

        // Contour rouge vif principal
        canvas.drawPath(path,
          Paint()
            ..color = const Color(0xFFFF1111)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);

        // Filet blanc interne (double ligne)
        canvas.drawPath(path,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8);

      } else {
        // Fallback rectangle si contour absent
        final x1 = ((zone['x1Pct'] as num?)?.toDouble() ?? 0)   / 100 * size.width;
        final y1 = ((zone['y1Pct'] as num?)?.toDouble() ?? 0)   / 100 * size.height;
        final x2 = ((zone['x2Pct'] as num?)?.toDouble() ?? 100) / 100 * size.width;
        final y2 = ((zone['y2Pct'] as num?)?.toDouble() ?? 100) / 100 * size.height;
        final rect = Rect.fromLTRB(x1, y1, x2, y2);
        canvas.drawRect(rect,
          Paint()..color = const Color(0x33FF1111)..style = PaintingStyle.fill);
        canvas.drawRect(rect,
          Paint()
            ..color = const Color(0xFFFF1111)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
      }
    }
  }

  @override
  bool shouldRepaint(DiseaseZonePainter old) =>
      old.zones != zones || old.glowOpacity != glowOpacity;
}

/// Viewer plein écran : zoom/pan + contours pulsants animés.
class DiseaseZoneFullScreenViewer extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> zones;

  const DiseaseZoneFullScreenViewer({
    super.key,
    required this.imagePath,
    required this.zones,
  });

  @override
  State<DiseaseZoneFullScreenViewer> createState() =>
      _DiseaseZoneFullScreenViewerState();
}

class _DiseaseZoneFullScreenViewerState
    extends State<DiseaseZoneFullScreenViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glowAnim;

  // Dimensions réelles de l'image (chargées au démarrage)
  Size? _imgSize;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      ui.decodeImageFromList(bytes, (img) {
        if (mounted) {
          setState(() => _imgSize =
              Size(img.width.toDouble(), img.height.toDouble()));
        }
      });
    } catch (_) {}
  }

  /// Calcule les bounds de l'image après BoxFit.contain dans [container].
  /// Retourne (offsetX, offsetY, renderedW, renderedH).
  (double, double, double, double) _containBounds(Size container) {
    final imgW = _imgSize?.width  ?? container.width;
    final imgH = _imgSize?.height ?? container.height;
    final scale = min(container.width / imgW, container.height / imgH);
    final rW = imgW * scale;
    final rH = imgH * scale;
    final oX = (container.width  - rW) / 2;
    final oY = (container.height - rH) / 2;
    return (oX, oY, rW, rH);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image zoomable + overlay parfaitement aligné ────────────────
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 8.0,
            clipBehavior: Clip.none,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final container = Size(constraints.maxWidth, constraints.maxHeight);
                final (oX, oY, rW, rH) = _containBounds(container);

                return Stack(
                  children: [
                    // Image centrée
                    Positioned.fill(
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Overlay contours — exactement sur la zone image
                    if (widget.zones.isNotEmpty)
                      Positioned(
                        left:   oX,
                        top:    oY,
                        width:  rW,
                        height: rH,
                        child: AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, __) => CustomPaint(
                            painter: DiseaseZonePainter(
                              zones:       widget.zones,
                              glowOpacity: _glowAnim.value,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // ── Barre supérieure ────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bouton fermer
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),

                    // Badge zones affectées
                    if (widget.zones.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            color: Colors.black.withValues(alpha: 0.45),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 10, height: 10,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFF1111),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.zones.length} zone${widget.zones.length > 1 ? "s" : ""} affectée${widget.zones.length > 1 ? "s" : ""}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Hint zoom bas ───────────────────────────────────────────────
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: Colors.black.withValues(alpha: 0.40),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in_rounded,
                            color: Colors.white70, size: 16),
                        SizedBox(width: 6),
                        Text('Pincez pour zoomer',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper : ouvre le viewer plein écran avec une transition fade.
void openDiseaseZoneViewer(
  BuildContext context,
  String imagePath,
  List<Map<String, dynamic>> zones,
) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => DiseaseZoneFullScreenViewer(
        imagePath: imagePath,
        zones: zones,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}
