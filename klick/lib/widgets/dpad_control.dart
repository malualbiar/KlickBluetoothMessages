import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class DpadControl extends StatelessWidget {
  final KlickController controller;

  const DpadControl({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF222222),
            border: Border.all(color: BitMechanicalTheme.outlineVariant, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 6,
                spreadRadius: 1,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0x22FFFFFF),
                blurRadius: 2,
                offset: Offset(0, -1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Up Button
              Positioned(
                top: 0,
                child: _DpadButton(
                  icon: Icons.arrow_drop_up,
                  keyId: 'UP',
                  isActive: controller.activeHardwareKey == 'UP' ||
                      controller.activeHardwareKey == 'ARROWUP',
                  onTap: () => controller.handleKeyPress('UP'),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  width: 32,
                  height: 28,
                ),
              ),

              // Down Button
              Positioned(
                bottom: 0,
                child: _DpadButton(
                  icon: Icons.arrow_drop_down,
                  keyId: 'DOWN',
                  isActive: controller.activeHardwareKey == 'DOWN' ||
                      controller.activeHardwareKey == 'ARROWDOWN',
                  onTap: () => controller.handleKeyPress('DOWN'),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  width: 32,
                  height: 28,
                ),
              ),

              // Left Button
              Positioned(
                left: 0,
                child: _DpadButton(
                  icon: Icons.arrow_left,
                  keyId: 'LEFT',
                  isActive: controller.activeHardwareKey == 'LEFT' ||
                      controller.activeHardwareKey == 'ARROWLEFT',
                  onTap: () => controller.handleKeyPress('LEFT'),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  width: 28,
                  height: 32,
                ),
              ),

              // Right Button
              Positioned(
                right: 0,
                child: _DpadButton(
                  icon: Icons.arrow_right,
                  keyId: 'RIGHT',
                  isActive: controller.activeHardwareKey == 'RIGHT' ||
                      controller.activeHardwareKey == 'ARROWRIGHT',
                  onTap: () => controller.handleKeyPress('RIGHT'),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  width: 28,
                  height: 32,
                ),
              ),

              // Center Select / Enter Button
              _DpadCenterButton(
                isActive: controller.activeHardwareKey == 'SELECT' ||
                    controller.activeHardwareKey == 'ENTER' ||
                    controller.activeHardwareKey == 'ENT',
                onTap: () => controller.handleKeyPress('SELECT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DpadButton extends StatefulWidget {
  final IconData icon;
  final String keyId;
  final bool isActive;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final double width;
  final double height;

  const _DpadButton({
    required this.icon,
    required this.keyId,
    required this.isActive,
    required this.onTap,
    required this.borderRadius,
    required this.width,
    required this.height,
  });

  @override
  State<_DpadButton> createState() => _DpadButtonState();
}

class _DpadButtonState extends State<_DpadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _isPressed || widget.isActive;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: widget.width,
        height: widget.height,
        transform: pressed ? Matrix4.translationValues(0, 1.5, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: pressed ? const Color(0xFF111111) : const Color(0xFF1A1A1A),
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: pressed ? BitMechanicalTheme.primaryAmber : const Color(0xFF333333),
            width: 1,
          ),
          boxShadow: pressed
              ? [
                  const BoxShadow(
                    color: Color(0xFF000000),
                    offset: Offset(0, 1),
                    blurRadius: 1,
                  )
                ]
              : const [
                  BoxShadow(
                    color: Color(0x33FFFFFF),
                    offset: Offset(0, -0.8),
                    blurRadius: 0.5,
                  ),
                  BoxShadow(
                    color: Color(0xFF0A0A0A),
                    offset: Offset(0, 2),
                    blurRadius: 2,
                  ),
                ],
        ),
        child: Center(
          child: Icon(
            widget.icon,
            size: 16,
            color: pressed
                ? BitMechanicalTheme.primaryAmber
                : BitMechanicalTheme.outline,
          ),
        ),
      ),
    );
  }
}

class _DpadCenterButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _DpadCenterButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_DpadCenterButton> createState() => _DpadCenterButtonState();
}

class _DpadCenterButtonState extends State<_DpadCenterButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _isPressed || widget.isActive;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 36,
        height: 36,
        transform: pressed ? Matrix4.translationValues(0, 1.5, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: pressed
                ? [const Color(0xFF151515), const Color(0xFF0A0A0A)]
                : [const Color(0xFF333333), const Color(0xFF141414)],
          ),
          border: Border.all(
            color: pressed ? BitMechanicalTheme.primaryAmber : const Color(0xFF444444),
            width: 1.2,
          ),
          boxShadow: pressed
              ? const [
                  BoxShadow(
                    color: Color(0xFF000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  )
                ]
              : const [
                  BoxShadow(
                    color: Color(0x44FFFFFF),
                    offset: Offset(0, -1),
                    blurRadius: 1,
                  ),
                  BoxShadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pressed ? BitMechanicalTheme.primaryAmber : const Color(0xFF222222),
            ),
          ),
        ),
      ),
    );
  }
}
