import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive cosmic Nebula animation widget for voice interactions.
///
/// Features:
/// - When idle: A compact, luminous cosmic button with nebula stardust and glowing mic.
/// - When speaking / listening: Blooms into a dynamic multi-layered organic nebula
///   with rotating cosmic clouds, fluid soundwave ripples, and reactive glowing core.
/// - Auto-manages animation ticker (pauses when idle to prevent test timeouts).
class NebulaVisualizer extends StatefulWidget {
  const NebulaVisualizer({
    super.key,
    required this.isListening,
    required this.isSpeaking,
    required this.isLoading,
    required this.isVoiceConversation,
    required this.onToggleVoice,
    this.voiceBusy = false,
  });

  final bool isListening;
  final bool isSpeaking;
  final bool isLoading;
  final bool isVoiceConversation;
  final bool voiceBusy;
  final VoidCallback onToggleVoice;

  @override
  State<NebulaVisualizer> createState() => _NebulaVisualizerState();
}

class _NebulaVisualizerState extends State<NebulaVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _shouldAnimate =>
      widget.isListening ||
      widget.isSpeaking ||
      widget.isLoading ||
      widget.isVoiceConversation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (_shouldAnimate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(NebulaVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _statusLabel {
    if (widget.isSpeaking) return 'Saathi is speaking…';
    if (widget.isListening) return 'Listening — speak naturally';
    if (widget.isLoading) return 'Saathi is thinking…';
    if (widget.voiceBusy) return 'Getting ready…';
    if (widget.isVoiceConversation) return 'Voice session active';
    return 'Tap to talk with Saathi';
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.isVoiceConversation || widget.isListening;
    final isListening = widget.isListening;

    // Compact cosmic nebula hero button when idle
    if (!active) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0C241D), Color(0xFF185A49), Color(0xFF14375A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF2E7564), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3000F2FE),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _NebulaPainter(
                    progress: 0.0,
                    isListening: false,
                    isSpeaking: false,
                    isLoading: widget.isLoading,
                    isActive: false,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isLoading ? null : widget.onToggleVoice,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0x3300F2FE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Color(0xFF00F2FE),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Start voice conversation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
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
      );
    }

    // Active blooming Nebula Visualizer when user or Saathi is speaking
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1714),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isListening ? const Color(0xFF00F2FE) : const Color(0xFF10B981),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isListening
                ? const Color(0x6000F2FE)
                : const Color(0x4010B981),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nebula Canvas & Core
          GestureDetector(
            onTap: widget.isLoading ? null : widget.onToggleVoice,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 110),
                  painter: _NebulaPainter(
                    progress: _controller.value,
                    isListening: widget.isListening,
                    isSpeaking: widget.isSpeaking,
                    isLoading: widget.isLoading,
                    isActive: true,
                  ),
                  child: Center(
                    child: _buildCoreIcon(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Status subtitle
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            child: Text(
              _statusLabel,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),

          // End conversation button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: widget.isLoading ? null : widget.onToggleVoice,
              icon: const Icon(
                Icons.stop_circle_outlined,
                size: 24,
                color: Colors.white,
              ),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'End voice conversation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreIcon() {
    final isListening = widget.isListening;
    final isSpeaking = widget.isSpeaking;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isListening
              ? [
                  const Color(0xFF00F2FE),
                  const Color(0xFF7C3AED),
                ]
              : isSpeaking
              ? [
                  const Color(0xFF10B981),
                  const Color(0xFFF59E0B),
                ]
              : [
                  const Color(0xFF185A49),
                  const Color(0xFF0A2B23),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isListening
                    ? const Color(0xFF00F2FE)
                    : const Color(0xFF10B981))
                .withOpacity(0.6),
            blurRadius: 22,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isListening
              ? Icons.graphic_eq
              : isSpeaking
              ? Icons.volume_up_rounded
              : widget.isLoading
              ? Icons.hourglass_top_rounded
              : Icons.mic,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

/// Custom painter that draws undulating, multi-layered cosmic nebula clouds
/// and concentric soundwave ripples.
class _NebulaPainter extends CustomPainter {
  _NebulaPainter({
    required this.progress,
    required this.isListening,
    required this.isSpeaking,
    required this.isLoading,
    required this.isActive,
  });

  final double progress;
  final bool isListening;
  final bool isSpeaking;
  final bool isLoading;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.38;

    // 1. Concentric sound ripples (when user is speaking / listening)
    if (isListening || isSpeaking) {
      final rippleCount = isListening ? 3 : 2;
      for (int i = 0; i < rippleCount; i++) {
        final phase = (progress + (i / rippleCount)) % 1.0;
        final rippleRadius = baseRadius + (phase * baseRadius * 1.6);
        final opacity = (1.0 - phase) * (isListening ? 0.65 : 0.4);

        final ripplePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - phase * 0.5)
          ..color = (isListening
                  ? const Color(0xFF00F2FE)
                  : const Color(0xFF10B981))
              .withOpacity(opacity.clamp(0.0, 1.0));

        canvas.drawCircle(center, rippleRadius, ripplePaint);
      }
    }

    // 2. Cosmic Nebula Cloud Layers
    // Layer A: Ultraviolet / Violet swirling cloud
    _drawNebulaBlob(
      canvas: canvas,
      center: center,
      baseRadius: baseRadius * (isActive ? 1.35 : 1.1),
      angle: progress * 2 * math.pi,
      eccentricity: 0.28,
      gradientColors: [
        const Color(0xFF7C3AED).withOpacity(isActive ? 0.55 : 0.35),
        const Color(0xFF4C1D95).withOpacity(isActive ? 0.30 : 0.15),
        Colors.transparent,
      ],
    );

    // Layer B: Electric Astral Cyan / Emerald cloud (counter-rotates)
    _drawNebulaBlob(
      canvas: canvas,
      center: center,
      baseRadius: baseRadius * (isActive ? 1.2 : 0.95),
      angle: -progress * 2.8 * math.pi,
      eccentricity: 0.32,
      gradientColors: [
        (isListening
                ? const Color(0xFF00F2FE)
                : const Color(0xFF10B981))
            .withOpacity(isActive ? 0.60 : 0.30),
        const Color(0xFF06B6D4).withOpacity(isActive ? 0.25 : 0.10),
        Colors.transparent,
      ],
    );

    // Layer C: Vibrant Magenta / Gold Stardust cloud
    if (isActive) {
      _drawNebulaBlob(
        canvas: canvas,
        center: center,
        baseRadius: baseRadius * 1.1,
        angle: progress * 3.4 * math.pi + (math.pi / 3),
        eccentricity: 0.35,
        gradientColors: [
          (isSpeaking
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEC4899))
              .withOpacity(0.45),
          const Color(0xFFBE185D).withOpacity(0.18),
          Colors.transparent,
        ],
      );

      // Layer D: Small Stardust specks
      _drawStarDust(canvas, center, baseRadius * 1.5, progress);
    }
  }

  void _drawNebulaBlob({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double angle,
    required double eccentricity,
    required List<Color> gradientColors,
  }) {
    final offsetDistance = baseRadius * eccentricity;
    final blobCenter = Offset(
      center.dx + offsetDistance * math.cos(angle),
      center.dy + offsetDistance * math.sin(angle),
    );

    final paint = Paint()
      ..shader = RadialGradient(
        colors: gradientColors,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: blobCenter, radius: baseRadius),
      );

    canvas.drawCircle(blobCenter, baseRadius, paint);
  }

  void _drawStarDust(
    Canvas canvas,
    Offset center,
    double maxRadius,
    double progress,
  ) {
    final starPaint = Paint()..style = PaintingStyle.fill;
    const starCount = 8;
    for (int i = 0; i < starCount; i++) {
      final baseAngle = (i * (2 * math.pi / starCount));
      final distance = (0.45 + (0.45 * math.sin(progress * 2 * math.pi + i))) * maxRadius;
      final starPos = Offset(
        center.dx + distance * math.cos(baseAngle + progress * math.pi),
        center.dy + distance * math.sin(baseAngle + progress * math.pi),
      );
      final alpha = (0.3 + 0.6 * math.sin(progress * 4 * math.pi + i)).abs().clamp(0.1, 0.9);

      starPaint.color = Colors.white.withOpacity(alpha);
      canvas.drawCircle(starPos, (i % 2 == 0) ? 1.8 : 1.2, starPaint);
    }
  }

  @override
  bool shouldRepaint(_NebulaPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.isLoading != isLoading ||
        oldDelegate.isActive != isActive;
  }
}
