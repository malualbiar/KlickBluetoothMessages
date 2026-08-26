import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class QwertyKeyboard extends StatelessWidget {
  final KlickController controller;

  const QwertyKeyboard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Q - P
          _buildKeyRow([
            _KeyDef('Q'),
            _KeyDef('W'),
            _KeyDef('E'),
            _KeyDef('R'),
            _KeyDef('T'),
            _KeyDef('Y'),
            _KeyDef('U'),
            _KeyDef('I'),
            _KeyDef('O'),
            _KeyDef('P'),
          ]),

          const SizedBox(height: 3),

          // Row 2: A - L (with slight offset)
          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: _buildKeyRow([
                  _KeyDef('A'),
                  _KeyDef('S'),
                  _KeyDef('D'),
                  _KeyDef('F'),
                  _KeyDef('G'),
                  _KeyDef('H'),
                  _KeyDef('J'),
                  _KeyDef('K'),
                  _KeyDef('L'),
                ]),
              ),
              const SizedBox(width: 8),
            ],
          ),

          const SizedBox(height: 3),

          // Row 3: ^ (Shift), Z - M, <- (Backspace)
          _buildKeyRow([
            _KeyDef('^', flex: 15, isFunc: true, label: '^'),
            _KeyDef('Z', flex: 10),
            _KeyDef('X', flex: 10),
            _KeyDef('C', flex: 10),
            _KeyDef('V', flex: 10),
            _KeyDef('B', flex: 10),
            _KeyDef('N', flex: 10),
            _KeyDef('M', flex: 10),
            _KeyDef('<-', flex: 15, isFunc: true, label: '<-'),
          ]),

          const SizedBox(height: 3),

          // Row 4: ESC, , , _ (Space), . , ENT (Enter)
          _buildKeyRow([
            _KeyDef('ESC', flex: 18, isFunc: true, label: 'ESC'),
            _KeyDef(',', flex: 11),
            _KeyDef(' ', flex: 40, label: '_'),
            _KeyDef('.', flex: 11),
            _KeyDef('ENT', flex: 20, isFunc: true, label: 'ENT'),
          ]),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<_KeyDef> keys) {
    return Row(
      children: keys.map((k) {
        return Expanded(
          flex: k.flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _HardwareKey(
              keyDef: k,
              isActive: controller.activeHardwareKey == k.keyId.toUpperCase() ||
                  (k.keyId == ' ' && controller.activeHardwareKey == 'SPACE') ||
                  (k.keyId == '<-' && controller.activeHardwareKey == 'BACKSPACE') ||
                  (k.keyId == 'ENT' && (controller.activeHardwareKey == 'ENTER' || controller.activeHardwareKey == 'SELECT')),
              onTap: () => controller.handleKeyPress(k.keyId),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyDef {
  final String keyId;
  final String? label;
  final int flex;
  final bool isFunc;

  _KeyDef(this.keyId, {this.label, this.flex = 10, this.isFunc = false});
}

class _HardwareKey extends StatefulWidget {
  final _KeyDef keyDef;
  final bool isActive;
  final VoidCallback onTap;

  const _HardwareKey({
    required this.keyDef,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_HardwareKey> createState() => _HardwareKeyState();
}

class _HardwareKeyState extends State<_HardwareKey> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _isPressed || widget.isActive;
    final textColor = widget.keyDef.isFunc
        ? (pressed ? BitMechanicalTheme.primaryAmber : BitMechanicalTheme.outline)
        : (pressed ? const Color(0xFFFFFFFF) : BitMechanicalTheme.primaryAmber);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        height: 28,
        transform: pressed ? Matrix4.translationValues(0, 1.2, 0) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: pressed ? BitMechanicalTheme.hardwareKeyActive : BitMechanicalTheme.hardwareKeyBase,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: pressed ? BitMechanicalTheme.primaryAmber : const Color(0xFF333333),
            width: 0.8,
          ),
          boxShadow: pressed
              ? const [
                  BoxShadow(
                    color: Color(0xFF000000),
                    offset: Offset(0, 1),
                    blurRadius: 1,
                  )
                ]
              : const [
                  BoxShadow(
                    color: Color(0x33FFFFFF),
                    offset: Offset(0, -0.6),
                    blurRadius: 0.2,
                  ),
                  BoxShadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 1.5),
                    blurRadius: 1.5,
                  ),
                ],
        ),
        child: Center(
          child: Text(
            widget.keyDef.label ?? widget.keyDef.keyId,
            style: BitMechanicalTheme.statusPixel(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
