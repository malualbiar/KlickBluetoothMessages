import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class SplashScreen extends StatefulWidget {
  final KlickController controller;
  final VoidCallback onLoaded;

  const SplashScreen({
    super.key,
    required this.controller,
    required this.onLoaded,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  double _progress = 0.0;
  String _statusText = 'BOOTING KLICK COMMUNICATOR...';
  Timer? _bootTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _startBootSequence();
  }

  void _startBootSequence() {
    int step = 0;
    _bootTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      step++;
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _progress = (step / 8).clamp(0.0, 1.0);
        if (step == 2) {
          _statusText = 'INITIALIZING BLUETOOTH RADIO...';
        } else if (step == 4) {
          _statusText = 'CALIBRATING P2P PROTOCOL...';
        } else if (step == 6) {
          _statusText = 'AUTHENTICATING RADIO TERMINAL...';
        } else if (step >= 8) {
          _statusText = 'KLICK COMMUNICATOR READY';
        }
      });

      if (step >= 9) {
        timer.cancel();
        widget.onLoaded();
      }
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BitMechanicalTheme.hardwareBody,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top System Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '// KLICK OS',
                    style: BitMechanicalTheme.statusPixel(
                      color: BitMechanicalTheme.outline,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'REV. 2026.1',
                    style: BitMechanicalTheme.statusPixel(
                      color: BitMechanicalTheme.outline,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              // Center Logo & Pulsing Indicator
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: BitMechanicalTheme.primaryAmber,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: BitMechanicalTheme.primaryAmber.withValues(alpha: 0.35),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                          const BoxShadow(
                            color: Color(0x99000000),
                            offset: Offset(0, 8),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/icons/KlickIcon.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'lib/assets/icons/KlickIcon.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: BitMechanicalTheme.primaryAmber,
                            child: Center(
                              child: Text(
                                'KLIK',
                                style: BitMechanicalTheme.headlineMono(
                                  color: const Color(0xFF111111),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Brand Title
                  Text(
                    'KLICK',
                    style: BitMechanicalTheme.headlineMono(
                      color: const Color(0xFFF5F5F5),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OFFLINE BLUETOOTH COMMUNICATOR',
                    style: BitMechanicalTheme.statusPixel(
                      color: BitMechanicalTheme.primaryAmber,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),

              // Bottom Progress Bar & Diagnostics
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status text
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: BitMechanicalTheme.statusPixel(
                      color: BitMechanicalTheme.outline,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Segmented / Continuous Progress Bar
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: BitMechanicalTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: BitMechanicalTheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(1),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: BitMechanicalTheme.primaryAmber,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: BitMechanicalTheme.primaryAmber.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Percentage indicator
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: BitMechanicalTheme.statusPixel(
                      color: BitMechanicalTheme.primaryAmber,
                      fontWeight: FontWeight.w800,
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
}
