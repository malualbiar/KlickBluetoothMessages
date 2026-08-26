import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../screens/chats_list_screen.dart';
import '../screens/conversation_screen.dart';
import '../screens/discovery_screen.dart';
import '../theme/bit_mechanical_theme.dart';
import 'dpad_control.dart';
import 'lcd_screen_container.dart';
import 'qwerty_keyboard.dart';

class HardwareShell extends StatelessWidget {
  final KlickController controller;

  const HardwareShell({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: BitMechanicalTheme.hardwareBody,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          // Top Speaker Grill
          _buildSpeakerGrill(),

          const SizedBox(height: 6),

          // Display Area (CRT Bubble Bezel + LCD Screen) - Expands to fill available vertical space
          Expanded(
            child: _buildDisplayArea(),
          ),

          const SizedBox(height: 8),

          // Hardware Controls Area (D-Pad + QWERTY)
          DpadControl(controller: controller),

          const SizedBox(height: 8),

          // QWERTY Tactile Keyboard
          QwertyKeyboard(controller: controller),

          const SizedBox(height: 4),

          // Microphone Pin Hole
          _buildMicrophoneHole(),
        ],
      ),
    );
  }

  Widget _buildSpeakerGrill() {
    return Container(
      width: 56,
      height: 6,
      decoration: BoxDecoration(
        color: BitMechanicalTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: BitMechanicalTheme.hardwareBody,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDisplayArea() {
    String leftSoftKey = 'Scan';
    String centerTitle = 'KLICK';
    String rightSoftKey = 'Open';
    VoidCallback? onLeftSoftKey;
    VoidCallback? onRightSoftKey;

    Widget currentBody;

    switch (controller.currentScreen) {
      case KlickScreen.chats:
        currentBody = ChatsListScreen(controller: controller);
        leftSoftKey = 'Scan';
        centerTitle = 'KLICK';
        rightSoftKey = 'Open';
        onLeftSoftKey = () {
          controller.startDiscoveryScan();
          controller.navigateTo(KlickScreen.scan);
        };
        onRightSoftKey = () {
          if (controller.devices.isNotEmpty && controller.listFocusIndex < controller.devices.length) {
            controller.openChat(controller.devices[controller.listFocusIndex]);
          }
        };
        break;
      case KlickScreen.conversation:
        final dev = controller.activeChatDevice;
        currentBody = dev != null
            ? ConversationScreen(controller: controller, device: dev)
            : ChatsListScreen(controller: controller);
        leftSoftKey = 'Back';
        centerTitle = dev?.name ?? 'CHAT';
        rightSoftKey = 'Send';
        onLeftSoftKey = controller.goBack;
        onRightSoftKey = controller.sendMessageFromInput;
        break;
      case KlickScreen.scan:
        currentBody = DiscoveryScreen(controller: controller);
        leftSoftKey = 'Back';
        centerTitle = 'SCAN';
        rightSoftKey = 'Connect';
        onLeftSoftKey = controller.goBack;
        onRightSoftKey = () {
          if (controller.discoveredDevices.isNotEmpty &&
              controller.listFocusIndex < controller.discoveredDevices.length) {
            controller.connectDiscoveredDevice(controller.discoveredDevices[controller.listFocusIndex]);
          } else {
            controller.startDiscoveryScan();
          }
        };
        break;
    }

    return LcdScreenContainer(
      controller: controller,
      leftSoftKey: leftSoftKey,
      centerTitle: centerTitle,
      rightSoftKey: rightSoftKey,
      onLeftSoftKey: onLeftSoftKey,
      onRightSoftKey: onRightSoftKey,
      child: currentBody,
    );
  }

  Widget _buildMicrophoneHole() {
    return Container(
      width: 3.5,
      height: 3.5,
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x33FFFFFF),
            offset: Offset(0, 0.5),
            blurRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
