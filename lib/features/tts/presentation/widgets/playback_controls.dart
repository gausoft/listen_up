import 'package:flutter/material.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import '../controllers/tts_controller.dart';

class PlaybackControls extends StatelessWidget {
  final TtsController controller;
  final String text;
  final bool enabled;

  // Speed values: 1.2x, 1.4x, 1.6x, 1.8x, 2.0x (then cycle back)
  // Mapped to speechRate (0.0-1.0): formula is (displaySpeed - 0.5) / 1.5
  static const List<double> _speedValues = [0.467, 0.6, 0.733, 0.867, 1.0];

  const PlaybackControls({
    super.key,
    required this.controller,
    required this.text,
    this.enabled = true,
  });

  Future<void> _cycleSpeed(TtsController controller, String text) async {
    final currentSpeed = controller.speechRate;
    final wasPlaying = controller.isPlaying;

    // Find current index (with tolerance for floating point)
    int currentIndex = _speedValues.indexWhere(
      (s) => (s - currentSpeed).abs() < 0.05,
    );

    // Calculate new speed
    double newSpeed;
    if (currentIndex == -1 || currentIndex >= _speedValues.length - 1) {
      newSpeed = _speedValues[0]; // 1.2x
    } else {
      newSpeed = _speedValues[currentIndex + 1];
    }

    // Set new speed
    await controller.setSpeechRate(newSpeed);

    // If was playing, restart with new speed
    if (wasPlaying && text.isNotEmpty) {
      await controller.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Loading text (simple, non-intrusive)
        if (controller.isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Chargement...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.outline,
              ),
            ),
          ),

        // Playback controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Stop button
              IconButton(
                onPressed: enabled && !controller.isStopped
                    ? () => controller.stop()
                    : null,
                icon: Icon(
                  HugeIconsSolid.stop,
                  color: enabled && !controller.isStopped
                      ? colorScheme.onSurface
                      : colorScheme.outline,
                  size: 28,
                ),
                tooltip: 'Stop',
              ),

              // Play/Pause button (main control)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: enabled && !controller.isLoading
                      ? colorScheme.primary
                      : colorScheme.outline,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: enabled && !controller.isLoading
                      ? () => controller.togglePlayPause(text)
                      : null,
                  icon: Icon(
                    controller.isPlaying
                        ? HugeIconsSolid.pause
                        : HugeIconsSolid.play,
                    color: colorScheme.onPrimary,
                    size: 32,
                  ),
                  tooltip: controller.isPlaying ? 'Pause' : 'Play',
                ),
              ),

              // Speed indicator (interactive)
              _SpeedChip(
                speed: controller.speechRate,
                enabled: enabled,
                onTap: () => _cycleSpeed(controller, text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final double speed;
  final bool enabled;
  final VoidCallback? onTap;

  const _SpeedChip({
    required this.speed,
    required this.enabled,
    this.onTap,
  });

  String _formatSpeed(double speed) {
    // Convert 0.0-1.0 range to display value (0.5x to 2.0x)
    final displaySpeed = 0.5 + (speed * 1.5);
    return '${displaySpeed.toStringAsFixed(1)}x';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _formatSpeed(speed),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

