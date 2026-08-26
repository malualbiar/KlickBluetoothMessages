import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class LcdScreenContainer extends StatelessWidget {
  final KlickController controller;
  final Widget child;
  final String leftSoftKey;
  final String centerTitle;
  final String rightSoftKey;
  final VoidCallback? onLeftSoftKey;
  final VoidCallback? onRightSoftKey;

  const LcdScreenContainer({
    super.key,
    required this.controller,
    required this.child,
    this.leftSoftKey = 'Menu',
    this.centerTitle = 'KLICK',
    this.rightSoftKey = 'Scan',
    this.onLeftSoftKey,
    this.onRightSoftKey,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = BitMechanicalTheme.getLcdBackground(controller.lcdTheme);
    final inkColor = BitMechanicalTheme.getLcdInk(controller.lcdTheme);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, 3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x15FFFFFF),
            offset: Offset(0, -1),
            blurRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // LCD Base Color & Pixel Grid
            Positioned.fill(
              child: CustomPaint(
                painter: _LcdPixelGridPainter(
                  backgroundColor: bgColor,
                  gridColor: inkColor.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Inner Vignette / CRT curve shadow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.05,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.38),
                    ],
                    stops: const [0.0, 0.7, 0.9, 1.0],
                  ),
                ),
              ),
            ),

            // Main Content Area & Navigation Softkeys
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  children: [
                    // Top App / Status Bar
                    _buildStatusBar(inkColor),

                    const SizedBox(height: 4),

                    // Active Screen Body
                    Expanded(child: child),

                    // Bottom Soft-Keys
                    _buildSoftKeys(inkColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(Color inkColor) {
    int unreadCount = 0;
    for (final dev in controller.devices) {
      unreadCount += dev.unreadCount;
    }

    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Signal + Radio Icon + Message indicator
          Row(
            children: [
              _buildSignalBars(inkColor, 4),
              const SizedBox(width: 6),
              Icon(Icons.bluetooth, size: 13, color: inkColor),
              if (unreadCount > 0) ...[
                const SizedBox(width: 4),
                Icon(Icons.mail, size: 12, color: inkColor),
              ],
            ],
          ),

          // Right: Time + Battery Gauge
          Row(
            children: [
              Text(
                controller.currentTimeString,
                style: BitMechanicalTheme.statusPixel(
                  color: inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              _buildBatteryIcon(inkColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBars(Color inkColor, int level) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final height = (i + 1) * 2.5 + 2.0;
        final filled = i < level;
        return Container(
          width: 2.5,
          height: height,
          margin: const EdgeInsets.only(right: 1.5),
          color: filled ? inkColor : inkColor.withValues(alpha: 0.25),
        );
      }),
    );
  }

  Widget _buildBatteryIcon(Color inkColor) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 8,
          decoration: BoxDecoration(
            border: Border.all(color: inkColor, width: 1),
          ),
          padding: const EdgeInsets.all(1),
          child: Container(
            color: inkColor,
          ),
        ),
        Container(
          width: 1.5,
          height: 4,
          color: inkColor,
        ),
      ],
    );
  }

  Widget _buildSoftKeys(Color inkColor) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: inkColor.withValues(alpha: 0.3), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          // Left SoftKey
          GestureDetector(
            onTap: () {
              controller.triggerKeyFeedback('LEFT_KEY');
              if (onLeftSoftKey != null) {
                onLeftSoftKey!();
              }
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                leftSoftKey,
                style: BitMechanicalTheme.statusPixel(
                  color: inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // Center Title
          Expanded(
            child: Center(
              child: Text(
                centerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BitMechanicalTheme.statusPixel(
                  color: inkColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // Right SoftKey
          GestureDetector(
            onTap: () {
              controller.triggerKeyFeedback('RIGHT_KEY');
              if (onRightSoftKey != null) {
                onRightSoftKey!();
              }
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                rightSoftKey,
                style: BitMechanicalTheme.statusPixel(
                  color: inkColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LcdPixelGridPainter extends CustomPainter {
  final Color backgroundColor;
  final Color gridColor;

  _LcdPixelGridPainter({
    required this.backgroundColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw fine pixel grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    const double step = 3.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LcdPixelGridPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gridColor != gridColor;
  }
}
