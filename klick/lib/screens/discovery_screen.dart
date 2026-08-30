import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../models/bluetooth_device.dart';
import '../theme/bit_mechanical_theme.dart';

class DiscoveryScreen extends StatelessWidget {
  final KlickController controller;

  const DiscoveryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bgColor = BitMechanicalTheme.getLcdBackground(controller.lcdTheme);
    final inkColor = BitMechanicalTheme.getLcdInk(controller.lcdTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: inkColor.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: controller.goBack,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        color: inkColor,
                        child: Text(
                          '◄',
                          style: BitMechanicalTheme.statusPixel(
                            color: bgColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'NEARBY DEVICES',
                        overflow: TextOverflow.ellipsis,
                        style: BitMechanicalTheme.bodyLg(
                          color: inkColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: controller.startDiscoveryScan,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: inkColor, width: 1),
                    color: controller.isScanning ? inkColor : Colors.transparent,
                  ),
                  child: Text(
                    controller.isScanning ? 'SCANNING...' : 'SCAN',
                    style: BitMechanicalTheme.statusPixel(
                      color: controller.isScanning ? bgColor : inkColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Progress bar if scanning
        if (controller.isScanning)
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: LinearProgressIndicator(
              backgroundColor: inkColor.withValues(alpha: 0.2),
              color: inkColor,
            ),
          ),

        // Discovered Devices List
        Expanded(
          child: controller.discoveredDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        controller.isScanning
                            ? Icons.bluetooth_searching
                            : Icons.bluetooth,
                        size: 24,
                        color: inkColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        controller.isScanning
                            ? 'Searching for nearby Bluetooth devices...'
                            : 'Tap "SCAN" to search for nearby\nBluetooth devices to message.',
                        textAlign: TextAlign.center,
                        style: BitMechanicalTheme.bodyMd(
                          color: inkColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 2),
                  itemCount: controller.discoveredDevices.length,
                  itemBuilder: (context, index) {
                    final device = controller.discoveredDevices[index];
                    final isFocused = controller.listFocusIndex == index;

                    final isAlreadyFriend = controller.devices.any(
                        (d) => d.matchesPeer(device.id, device.name) && d.isPaired);

                    return GestureDetector(
                      onTap: () {
                        controller.listFocusIndex = index;
                        controller.connectDiscoveredDevice(device);
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 5),
                        child: Row(
                          children: [
                            Icon(
                              isAlreadyFriend
                                  ? Icons.star
                                  : (device.deviceType == DeviceType.pcTerminal
                                      ? Icons.computer
                                      : Icons.bluetooth),
                              size: 14,
                              color: isFocused ? bgColor : inkColor,
                            ),
                            const SizedBox(width: 6),

                            // Device info
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      device.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: BitMechanicalTheme.bodyLg(
                                        color: isFocused ? bgColor : inkColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (device.connectionType == ConnectionType.localP2p) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? bgColor
                                            : inkColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: isFocused ? bgColor : inkColor,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'P2P',
                                        style: BitMechanicalTheme.statusPixel(
                                          color: isFocused ? inkColor : inkColor,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isAlreadyFriend) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 3, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isFocused
                                            ? bgColor
                                            : inkColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: isFocused ? bgColor : inkColor,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'FRIEND',
                                        style: BitMechanicalTheme.statusPixel(
                                          color: isFocused ? inkColor : inkColor,
                                          fontSize: 7,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Connect / Klicked Button
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAlreadyFriend
                                    ? (isFocused ? bgColor : Colors.transparent)
                                    : (isFocused ? bgColor : inkColor),
                                border: isAlreadyFriend
                                    ? Border.all(
                                        color: isFocused ? bgColor : inkColor,
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Text(
                                isAlreadyFriend
                                    ? 'KLICKED'
                                    : (controller.pendingKlickEndpointId == device.id
                                        ? 'PENDING...'
                                        : 'KLICK'),
                                style: BitMechanicalTheme.statusPixel(
                                  color: isAlreadyFriend
                                      ? (isFocused ? inkColor : inkColor)
                                      : (isFocused ? inkColor : bgColor),
                                  fontWeight: FontWeight.w900,
                                ),
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
