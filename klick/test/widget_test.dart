import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klick/controllers/klick_controller.dart';
import 'package:klick/main.dart';
import 'package:klick/models/bluetooth_device.dart';
import 'package:klick/services/bluetooth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  @override
  ConnectionRequestCallback? onConnectionRequest;

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
    // Peer connects / accepts
    final name = endpointId == 'dev_peer_7' ? 'Alpha Node' : 'Pixel 9 Pro';
    onConnected?.call(endpointId, name);
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

/// Helper: complete onboarding by entering a callsign (SKIP was removed).
Future<void> completeOnboarding(WidgetTester tester) async {
  // Tap CONTINUE 3 times to reach the callsign form (page index 3)
  for (int i = 0; i < 3; i++) {
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
  }
  // Enter callsign and launch
  await tester.enterText(find.byType(TextField), 'TESTER');
  await tester.tap(find.text('LAUNCH KLICK'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Klick Loading Splash Screen 5-second boot test', (WidgetTester tester) async {
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

    // Advance 5-second boot sequence
    await tester.pump(const Duration(milliseconds: 5500));
    await tester.pumpAndSettle();

    // Verify transition to Onboarding
    expect(find.text('OFFLINE MESSAGING'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Onboarding Callsign form, discovery, and messaging flow test', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    // 1. Launch App with controller (skip splash)
    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();

    // Complete onboarding with a callsign (SKIP removed — name required)
    await completeOnboarding(tester);

    // Verify Clean Empty Messages state
    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('NO BLUETOOTH CONTACTS'), findsOneWidget);
    expect(find.text('SCAN FOR RADIOS'), findsOneWidget);

    // 2. Tap Scan to search for real devices
    await tester.tap(find.text('SCAN FOR RADIOS'));
    await tester.pumpAndSettle();

    // Verify Scanner screen
    expect(find.text('NEARBY DEVICES'), findsOneWidget);

    // Verify discovered real physical device shows KLICK button
    expect(find.text('Pixel 9 Pro'), findsOneWidget);
    expect(find.text('KLICK'), findsWidgets);

    // 3. Tap KLICK (User requests connection)
    await tester.tap(find.text('KLICK').first);
    await tester.pumpAndSettle();

    // Verify Chat Screen opens once accepted and shows ONLINE presence
    expect(find.text('Pixel 9 Pro'), findsWidgets);
    expect(find.text('ONLINE'), findsOneWidget);
    expect(find.text('Type message...'), findsOneWidget);

    // 4. Send a real Bluetooth text message
    await tester.enterText(find.byType(TextField), 'Testing real radio transmission');
    await tester.tap(find.text('SEND'));
    await tester.pump();

    // Verify sent message appears on screen
    expect(find.text('Testing real radio transmission'), findsOneWidget);
    expect(controller.conversationMessages['real_endpoint_99']?.length ?? 0, 1);

    // 5. Navigate back to Scanner -> Verify it now says KLICKED
    controller.navigateTo(KlickScreen.scan);
    await tester.pumpAndSettle();
    expect(find.text('KLICKED'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Interactive connection request authorization modal test', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();
    await completeOnboarding(tester);

    // Trigger incoming connection request
    bool accepted = false;
    mockService.onConnectionRequest?.call(
      'ep_incoming_1',
      'VIPER',
      () async { accepted = true; },
      () async {},
    );
    await tester.pump();

    // Verify modal appeared
    expect(find.text('// INCOMING KLICK //'), findsOneWidget);
    expect(find.text('VIPER\nis trying to Klick!'), findsOneWidget);
    expect(find.text('ACCEPT'), findsOneWidget);
    expect(find.text('REJECT'), findsOneWidget);

    // Tap ACCEPT
    await tester.tap(find.text('ACCEPT'));
    await tester.pumpAndSettle();

    expect(accepted, isTrue);
    expect(controller.activeConnectionRequest, isNull);

    controller.dispose();
  });

  testWidgets('Block messaging when peer has not accepted Klick', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    final unacceptedPeer = KlickDevice(
      id: 'peer_unaccepted_1',
      name: 'Ghost',
      macAddress: '11:22:33:44:55:66',
      rssi: -60,
      isConnected: false,
      lastSeen: DateTime.now(),
    );
    controller.devices.add(unacceptedPeer);

    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();
    await completeOnboarding(tester);

    // Open chat with unaccepted peer
    controller.openChat(unacceptedPeer);
    await tester.pumpAndSettle();

    // Verify locked banner is displayed
    expect(find.text('WAITING FOR GHOST TO ACCEPT KLICK'), findsOneWidget);

    // Verify input box is not available
    expect(find.byType(TextField), findsNothing);

    controller.dispose();
  });

  testWidgets('Name required: LAUNCH KLICK blocked when callsign is empty', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();

    // Navigate to the callsign form page (3 CONTINUE taps)
    for (int i = 0; i < 3; i++) {
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
    }

    // Tap LAUNCH KLICK with empty name
    await tester.tap(find.text('LAUNCH KLICK'));
    await tester.pumpAndSettle();

    // Verify error message is shown and app did NOT navigate away
    expect(find.text('YOU MUST ENTER A CALLSIGN TO CONTINUE'), findsOneWidget);
    expect(find.text('OFFLINE MESSAGING'), findsNothing); // still on onboarding form
    expect(find.text('MESSAGES'), findsNothing); // didn't reach home

    controller.dispose();
  });

  testWidgets('Already-paired friend auto-accepts reconnection without modal', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    final pairedFriend = KlickDevice(
      id: 'ep_friend_1',
      name: 'MAVERICK',
      macAddress: 'ep_friend_1',
      rssi: -50,
      isConnected: false,
      isPaired: true,
      lastSeen: DateTime.now(),
    );
    controller.devices.add(pairedFriend);

    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();
    await completeOnboarding(tester);

    bool autoAccepted = false;
    mockService.onConnectionRequest?.call(
      'ep_friend_1',
      'MAVERICK',
      () async { autoAccepted = true; },
      () async {},
    );
    await tester.pump();

    // Verify NO interactive modal appeared because they are already paired friends
    expect(find.text('// INCOMING KLICK //'), findsNothing);
    expect(autoAccepted, isTrue);
    expect(controller.activeConnectionRequest, isNull);

    controller.dispose();
  });

  testWidgets('Paired offline contact allows typing and queues message', (WidgetTester tester) async {
    final mockService = TestBluetoothService();
    final controller = KlickController(bluetoothService: mockService);

    final pairedOfflineContact = KlickDevice(
      id: 'ep_friend_2',
      name: 'NOVA',
      macAddress: 'ep_friend_2',
      rssi: -55,
      isConnected: false,
      isPaired: true,
      lastSeen: DateTime.now(),
    );
    controller.devices.add(pairedOfflineContact);

    await tester.pumpWidget(
      KlickApp(controller: controller, showSplash: false),
    );
    await tester.pumpAndSettle();
    await completeOnboarding(tester);

    // Open chat with paired offline contact
    controller.openChat(pairedOfflineContact);
    await tester.pumpAndSettle();

    // Verify input box IS available (not locked) with offline hint
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Type message (queued offline)...'), findsOneWidget);

    // Send a message while offline
    await tester.enterText(find.byType(TextField), 'Hello offline friend');
    await tester.tap(find.text('SEND'));
    await tester.pump();

    // Verify message is saved and queued
    expect(controller.pendingMessages['ep_friend_2']?.length, 1);
    expect(find.text('Hello offline friend'), findsOneWidget);

    controller.dispose();
  });
}

