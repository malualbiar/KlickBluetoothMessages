import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klick/controllers/klick_controller.dart';
import 'package:klick/main.dart';
import 'package:klick/models/bluetooth_device.dart';
import 'package:klick/services/bluetooth_service.dart';

class TestBluetoothService implements BluetoothService {
  @override
  DeviceFoundCallback? onDeviceFound;
  @override
  DeviceLostCallback? onDeviceLost;
  @override
  ConnectionCallback? onConnected;
  @override
  DisconnectCallback? onDisconnected;
  @override
  MessageReceivedCallback? onMessageReceived;

  final List<String> sentMessages = [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> startAdvertising(String localName) async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> startDiscovery(String localName) async {
    onDeviceFound?.call(
      KlickDevice(
        id: 'real_endpoint_99',
        name: 'Pixel 9 Pro',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        rssi: -48,
        isConnected: false,
        deviceType: DeviceType.smartphone,
        lastSeen: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> stopDiscovery() async {}

  @override
  Future<void> connect(String endpointId, String localName) async {
    onConnected?.call(endpointId, 'Pixel 9 Pro');
  }

  @override
  Future<void> disconnect(String endpointId) async {
    onDisconnected?.call(endpointId);
  }

  @override
  Future<bool> sendMessage(String endpointId, String text) async {
    sentMessages.add('$endpointId: $text');
    return true;
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('Klick Loading Splash Screen boot test', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    // 1. Launch App with Splash enabled
    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: true),
    );
    await tester.pump();

    // Verify Splash Screen UI elements
    expect(find.text('KLICK'), findsOneWidget);
    expect(find.text('OFFLINE BLUETOOTH COMMUNICATOR'), findsOneWidget);
    expect(find.text('// KLICK OS'), findsOneWidget);

    // Advance boot sequence
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // Verify transition to Onboarding
    expect(find.text('OFFLINE MESSAGING'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Real Bluetooth device search and messaging flow test', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    // 1. Launch App with controller (skip splash)
    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();

    // Verify Onboarding Screen
    expect(find.text('OFFLINE MESSAGING'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);

    // Skip onboarding
    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    // Verify Clean Empty Messages state (no dummy contacts)
    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('NO BLUETOOTH CONTACTS'), findsOneWidget);
    expect(find.text('SCAN FOR RADIOS'), findsOneWidget);

    // 2. Tap Scan to search for real devices
    await tester.tap(find.text('SCAN FOR RADIOS'));
    await tester.pumpAndSettle();

    // Verify Scanner screen
    expect(find.text('NEARBY DEVICES'), findsOneWidget);

    // Verify discovered real physical device
    expect(find.text('Pixel 9 Pro'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);

    // 3. Tap Connect
    await tester.tap(find.text('CONNECT'));
    await tester.pumpAndSettle();

    // Verify Chat Screen opens
    expect(find.text('Pixel 9 Pro'), findsWidgets);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Type message...'), findsOneWidget);

    // 4. Send a real Bluetooth text message
    await tester.enterText(find.byType(TextField), 'Testing real radio transmission');
    await tester.tap(find.text('SEND'));
    await tester.pump();

    // Verify sent message appears on screen
    expect(find.text('Testing real radio transmission'), findsOneWidget);
    expect(controller.conversationMessages['real_endpoint_99']?.length ?? 0, 1);

    // 5. Simulate real incoming message from peer
    mockService.onMessageReceived?.call('real_endpoint_99', 'Received loud and clear!');
    await tester.pumpAndSettle();

    expect(find.text('Received loud and clear!'), findsOneWidget);

    // Clean up controller timers
    controller.dispose();
  });

  test('KlickController unit test with real clean state', () async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    // Starts completely empty (no dummy devices)
    expect(controller.devices.isEmpty, isTrue);
    expect(controller.discoveredDevices.isEmpty, isTrue);
    expect(controller.conversationMessages.isEmpty, isTrue);

    // Discover real device
    mockService.onDeviceFound?.call(
      KlickDevice(
        id: 'dev_real_1',
        name: 'Galaxy S24',
        macAddress: '11:22:33:44:55:66',
        rssi: -50,
        isConnected: false,
        lastSeen: DateTime.now(),
      ),
    );

    expect(controller.discoveredDevices.length, 1);
    expect(controller.discoveredDevices.first.name, 'Galaxy S24');

    // Connect
    await controller.connectDiscoveredDevice(controller.discoveredDevices.first);
    expect(controller.devices.length, 1);

    // Send Message
    controller.sendDirectMessage(controller.devices.first, 'Hello over Bluetooth');
    expect(mockService.sentMessages.contains('dev_real_1: Hello over Bluetooth'), isTrue);

    controller.dispose();
  });
}
