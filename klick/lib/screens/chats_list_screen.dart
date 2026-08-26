import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class ChatsListScreen extends StatelessWidget {
  final KlickController controller;

  const ChatsListScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bgColor = BitMechanicalTheme.getLcdBackground(controller.lcdTheme);
    final inkColor = BitMechanicalTheme.getLcdInk(controller.lcdTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header & Scan Action Button
        Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: inkColor.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MESSAGES',
                style: BitMechanicalTheme.headlineMd(
                  color: inkColor,
                  fontWeight: FontWeight.w900,
                ).copyWith(fontSize: 14),
              ),
              GestureDetector(
                onTap: () {
                  controller.startDiscoveryScan();
                  controller.navigateTo(KlickScreen.scan);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: inkColor,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth_searching, size: 11, color: bgColor),
                      const SizedBox(width: 3),
                      Text(
                        'SCAN',
                        style: BitMechanicalTheme.statusPixel(
                          color: bgColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 3),

        // List of Bluetooth Chats
        Expanded(
          child: controller.devices.isEmpty
              ? Center(
                  child: Text(
                    'No Bluetooth messages yet.\nTap "SCAN" to find nearby devices.',
                    textAlign: TextAlign.center,
                    style: BitMechanicalTheme.bodyMd(
                      color: inkColor.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: controller.devices.length,
                  itemBuilder: (context, index) {
                    final device = controller.devices[index];
                    final isFocused = controller.listFocusIndex == index;
                    final messages = controller.conversationMessages[device.id] ?? [];
                    final lastMessage = messages.isNotEmpty ? messages.last : null;

                    return GestureDetector(
                      onTap: () {
                        controller.listFocusIndex = index;
                        controller.openChat(device);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isFocused ? inkColor : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: isFocused
                                  ? Colors.transparent
                                  : inkColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Contact Name, Online Indicator, Time
                            Row(
                              children: [
                                if (isFocused)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      '►',
                                      style: TextStyle(
                                        color: bgColor,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                // Bluetooth icon or connection dot
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: device.isConnected
                                        ? (isFocused ? bgColor : inkColor)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isFocused ? bgColor : inkColor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    device.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: BitMechanicalTheme.bodyLg(
                                      color: isFocused ? bgColor : inkColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (lastMessage != null)
                                  Text(
                                    lastMessage.timeFormatted,
                                    style: BitMechanicalTheme.statusPixel(
                                      color: isFocused
                                          ? bgColor.withValues(alpha: 0.8)
                                          : inkColor.withValues(alpha: 0.65),
                                    ),
                                  ),
                              ],
                            ),

                            // Last message snippet
                            Padding(
                              padding: EdgeInsets.only(left: isFocused ? 15 : 11, top: 1),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMessage != null
                                          ? (lastMessage.isMe ? 'You: ' : '') + lastMessage.text
                                          : 'Tap to start chatting',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BitMechanicalTheme.bodyMd(
                                        color: isFocused
                                            ? bgColor.withValues(alpha: 0.85)
                                            : inkColor.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                  if (device.unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                                      color: isFocused ? bgColor : inkColor,
                                      child: Text(
                                        '1',
                                        style: BitMechanicalTheme.statusPixel(
                                          color: isFocused ? inkColor : bgColor,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
