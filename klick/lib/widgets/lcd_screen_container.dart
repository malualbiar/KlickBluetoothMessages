import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class BubbleScreenClipper extends CustomClipper<Path> {
  final double bulgeXFactor;
  final double bulgeYFactor;
  final double cornerRadius;

  const BubbleScreenClipper({
    this.bulgeXFactor = 0.026,
    this.bulgeYFactor = 0.020,
    this.cornerRadius = 20.0,
  });

  @override
  Path getClip(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double bx = w * bulgeXFactor;
    final double by = h * bulgeYFactor;
    final double r = cornerRadius.clamp(4.0, (w < h ? w : h) / 4);

    final path = Path();
    path.moveTo(bx + r, by);
    // Top edge curved upwards towards center
    path.quadraticBezierTo(w / 2, 0.5, w - bx - r, by);
    // Top-Right corner
    path.arcToPoint(
      Offset(w - bx, by + r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Right edge curved outwards towards center
    path.quadraticBezierTo(w - 0.5, h / 2, w - bx, h - by - r);
    // Bottom-Right corner
    path.arcToPoint(
      Offset(w - bx - r, h - by),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Bottom edge curved downwards towards center
    path.quadraticBezierTo(w / 2, h - 0.5, bx + r, h - by);
    // Bottom-Left corner
    path.arcToPoint(
      Offset(bx, h - by - r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Left edge curved outwards towards center
    path.quadraticBezierTo(0.5, h / 2, bx, by + r);
    // Top-Left corner
    path.arcToPoint(
      Offset(bx + r, by),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant BubbleScreenClipper oldClipper) =>
      oldClipper.bulgeXFactor != bulgeXFactor ||
      oldClipper.bulgeYFactor != bulgeYFactor ||
      oldClipper.cornerRadius != cornerRadius;
}

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
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.all(Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0xBB000000),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Color(0x18FFFFFF),
            offset: Offset(0, -1),
            blurRadius: 1.5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: ClipPath(
        clipper: const BubbleScreenClipper(),
        child: Stack(
          children: [
            // LCD Base Color & Micro Pixel Grid
            Positioned.fill(
              child: CustomPaint(
                painter: _LcdPixelGridPainter(
                  backgroundColor: bgColor,
                  gridColor: inkColor.withValues(alpha: 0.05),
                ),
              ),
            ),

            // CRT Spherical Bubble Vignette / Inner Shadow
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                      stops: const [0.0, 0.65, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Subtle Glass Specular Reflection Highlight at Top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content Area (Status Bar, Screen Body, Softkeys)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  children: [
                    // Top App / Status Bar
                    _buildStatusBar(inkColor),

                    const SizedBox(height: 3),

                    // Active Screen Body
                    Expanded(child: child),

                    // Bottom Soft-Keys
                    _buildSoftKeys(inkColor),
                  ],
                ),
              ),
            ),

            // In-App Toast Banner
            if (controller.inAppToast != null)
              Positioned(
                top: 26,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: inkColor,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    controller.inAppToast!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: BitMechanicalTheme.statusPixel(
                      color: bgColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

            // Interactive Connection Request Modal ("Username is trying to Klick!")
            if (controller.activeConnectionRequest != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        border: Border.all(color: inkColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: inkColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '// INCOMING KLICK //',
                            style: BitMechanicalTheme.statusPixel(
                              color: inkColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${controller.activeConnectionRequest!.endpointName}\nis trying to Klick!',
                            textAlign: TextAlign.center,
                            style: BitMechanicalTheme.headlineMono(
                              color: inkColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: controller.rejectConnectionRequest,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: inkColor, width: 1.2),
                                  ),
                                  child: Text(
                                    'REJECT',
                                    style: BitMechanicalTheme.statusPixel(
                                      color: inkColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: controller.acceptConnectionRequest,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  color: inkColor,
                                  child: Text(
                                    'ACCEPT',
                                    style: BitMechanicalTheme.statusPixel(
                                      color: bgColor,
                                      fontWeight: FontWeight.w900,
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

            // Outer Bubble Border / Bezel Frame
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BubbleBorderPainter(
                    borderColor: const Color(0xFF080808),
                    borderWidth: 2.5,
                  ),
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
          // Left: Cellular/Radio Bars + Bluetooth + Message indicator
          Row(
            children: [
              _buildSignalBars(inkColor, 4),
              const SizedBox(width: 5),
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
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(color: inkColor),
              ),
              const SizedBox(width: 1),
              Expanded(
                flex: 3,
                child: Container(color: inkColor),
              ),
              const SizedBox(width: 1),
              Expanded(
                flex: 3,
                child: Container(color: inkColor),
              ),
            ],
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
          top: BorderSide(color: inkColor.withValues(alpha: 0.25), width: 1),
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
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

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

class _BubbleBorderPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;

  _BubbleBorderPainter({
    required this.borderColor,
    this.borderWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const clipper = BubbleScreenClipper();
    final path = clipper.getClip(size);

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
