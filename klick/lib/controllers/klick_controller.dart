import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bluetooth_device.dart';
import '../services/bluetooth_service.dart';
import '../theme/bit_mechanical_theme.dart';

enum KlickScreen {
  chats,
  conversation,
  scan,
}

class KlickController extends ChangeNotifier {
  // Onboarding
  bool isOnboardingComplete = false;

  void completeOnboarding() {
    isOnboardingComplete = true;
    notifyListeners();
  }

  // Navigation
  KlickScreen currentScreen = KlickScreen.chats;
  final List<KlickScreen> _screenHistory = [];

  // Theme
  LcdThemeMode lcdTheme = LcdThemeMode.amberGold;

  // Local Device Identity
  late final String localDeviceName;

  // Active Key Pressed (for tactile hardware visual state)
  String? activeHardwareKey;
  Timer? _keyReleaseTimer;

  // D-Pad Focus index
  int listFocusIndex = 0;

  // Text Input buffer (for QWERTY input / composer)
  final TextEditingController textInputController = TextEditingController();

  // Devices & Conversations (Real physical devices only)
  List<KlickDevice> devices = [];
  Map<String, List<KlickMessage>> conversationMessages = {};
  KlickDevice? activeChatDevice;

  // Discovery / Scanner
  bool isScanning = false;
  Timer? _scanTimeoutTimer;
  List<KlickDevice> discoveredDevices = [];

  // Bluetooth Service
  final BluetoothService _bluetoothService;

  // Clock
  String currentTimeString = '11:57';
  Timer? _clockTimer;

  KlickController({BluetoothService? bluetoothService})
      : _bluetoothService = bluetoothService ?? NearbyBluetoothService() {
    localDeviceName = 'KLICK-${Random().nextInt(9000) + 1000}';
    _initBluetoothListeners();
    _startClockTimer();
    _initRadio();
  }

  void _initBluetoothListeners() {
    _bluetoothService.onDeviceFound = (device) {
      if (!discoveredDevices.any((d) => d.id == device.id)) {
        discoveredDevices.add(device);
        notifyListeners();
      }
    };

    _bluetoothService.onDeviceLost = (endpointId) {
      discoveredDevices.removeWhere((d) => d.id == endpointId);
      notifyListeners();
    };

    _bluetoothService.onConnected = (endpointId, name) {
      final index = devices.indexWhere((d) => d.id == endpointId);
      final devName = name.isNotEmpty ? name : 'Nearby Contact';
      if (index != -1) {
        devices[index] = devices[index].copyWith(isConnected: true, name: devName);
      } else {
        final newDev = KlickDevice(
          id: endpointId,
          name: devName,
          macAddress: endpointId,
          rssi: -50,
          isConnected: true,
          deviceType: DeviceType.smartphone,
          lastSeen: DateTime.now(),
        );
        devices.insert(0, newDev);
        conversationMessages[endpointId] ??= [];
      }
      notifyListeners();
    };

    _bluetoothService.onDisconnected = (endpointId) {
      final index = devices.indexWhere((d) => d.id == endpointId);
      if (index != -1) {
        devices[index] = devices[index].copyWith(isConnected: false);
        notifyListeners();
      }
    };

    _bluetoothService.onMessageReceived = (endpointId, message) {
      _handleIncomingMessage(endpointId, message);
    };
  }

  Future<void> _initRadio() async {
    final granted = await _bluetoothService.requestPermissions();
    if (granted) {
      await _bluetoothService.startAdvertising(localDeviceName);
    }
  }

  void _handleIncomingMessage(String endpointId, String text) {
    // Ensure device exists in contacts list
    if (!devices.any((d) => d.id == endpointId)) {
      final newDev = KlickDevice(
        id: endpointId,
        name: 'Nearby Contact',
        macAddress: endpointId,
        rssi: -50,
        isConnected: true,
        deviceType: DeviceType.smartphone,
        lastSeen: DateTime.now(),
      );
      devices.insert(0, newDev);
    }

    final msg = KlickMessage(
      id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
      senderId: endpointId,
      senderName: _getDeviceName(endpointId),
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.received,
      isMe: false,
    );

    final list = List<KlickMessage>.from(conversationMessages[endpointId] ?? []);
    list.add(msg);
    conversationMessages[endpointId] = list;

    // Update unread count if not currently in active chat with this device
    if (currentScreen != KlickScreen.conversation ||
        activeChatDevice?.id != endpointId) {
      final idx = devices.indexWhere((d) => d.id == endpointId);
      if (idx != -1) {
        devices[idx] = devices[idx].copyWith(
          unreadCount: devices[idx].unreadCount + 1,
        );
      }
    }

    notifyListeners();
  }

  String _getDeviceName(String endpointId) {
    final dev = devices.firstWhere(
      (d) => d.id == endpointId,
      orElse: () => KlickDevice(
        id: endpointId,
        name: 'Nearby Contact',
        macAddress: endpointId,
        rssi: -50,
        lastSeen: DateTime.now(),
      ),
    );
    return dev.name;
  }

  void _startClockTimer() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final newTime = '$h:$m';
    if (currentTimeString != newTime) {
      currentTimeString = newTime;
      notifyListeners();
    }
  }

  // Navigation
  void navigateTo(KlickScreen screen) {
    if (currentScreen != screen) {
      _screenHistory.add(currentScreen);
      currentScreen = screen;
      listFocusIndex = 0;
      notifyListeners();
    }
  }

  void openChat(KlickDevice device) {
    activeChatDevice = device;
    final idx = devices.indexWhere((d) => d.id == device.id);
    if (idx != -1) {
      devices[idx] = devices[idx].copyWith(unreadCount: 0);
    }
    navigateTo(KlickScreen.conversation);
  }

  void goBack() {
    if (_screenHistory.isNotEmpty) {
      currentScreen = _screenHistory.removeLast();
      listFocusIndex = 0;
      notifyListeners();
    } else {
      if (currentScreen != KlickScreen.chats) {
        currentScreen = KlickScreen.chats;
        listFocusIndex = 0;
        notifyListeners();
      }
    }
  }

  // Key feedback trigger
  void triggerKeyFeedback(String key) {
    activeHardwareKey = key.toUpperCase();
    HapticFeedback.lightImpact();
    notifyListeners();

    _keyReleaseTimer?.cancel();
    _keyReleaseTimer = Timer(const Duration(milliseconds: 120), () {
      activeHardwareKey = null;
      notifyListeners();
    });
  }

  // Hardware key press handler
  void handleKeyPress(String key) {
    triggerKeyFeedback(key);
    final k = key.toUpperCase();

    if (k == 'ESCAPE' || k == 'ESC') {
      goBack();
      return;
    }

    if (k == 'ARROWUP' || k == 'UP') {
      _moveFocus(-1);
      return;
    } else if (k == 'ARROWDOWN' || k == 'DOWN') {
      _moveFocus(1);
      return;
    } else if (k == 'ENTER' || k == 'ENT' || k == 'SELECT') {
      _handleSelect();
      return;
    }

    // Backspace
    if (k == 'BACKSPACE' || k == '<-') {
      final text = textInputController.text;
      if (text.isNotEmpty) {
        textInputController.text = text.substring(0, text.length - 1);
        notifyListeners();
      }
      return;
    }

    if (k == 'SHIFT' || k == '^') {
      return;
    }

    // Typing in chat
    if (currentScreen == KlickScreen.conversation) {
      textInputController.text += key;
      notifyListeners();
    }
  }

  void _moveFocus(int delta) {
    int maxItems = currentScreen == KlickScreen.chats
        ? devices.length
        : (currentScreen == KlickScreen.scan ? discoveredDevices.length : 1);

    if (maxItems > 0) {
      listFocusIndex = (listFocusIndex + delta + maxItems) % maxItems;
      notifyListeners();
    }
  }

  void _handleSelect() {
    switch (currentScreen) {
      case KlickScreen.chats:
        if (devices.isNotEmpty && listFocusIndex < devices.length) {
          openChat(devices[listFocusIndex]);
        } else {
          startDiscoveryScan();
          navigateTo(KlickScreen.scan);
        }
        break;
      case KlickScreen.scan:
        if (discoveredDevices.isNotEmpty && listFocusIndex < discoveredDevices.length) {
          connectDiscoveredDevice(discoveredDevices[listFocusIndex]);
        } else {
          startDiscoveryScan();
        }
        break;
      case KlickScreen.conversation:
        sendMessageFromInput();
        break;
    }
  }

  // Messaging actions
  void sendMessageFromInput() {
    final text = textInputController.text.trim();
    if (text.isEmpty || activeChatDevice == null) return;

    textInputController.clear();
    sendDirectMessage(activeChatDevice!, text);
  }

  void sendDirectMessage(KlickDevice device, String text) {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final userMsg = KlickMessage(
      id: msgId,
      senderId: 'me',
      senderName: 'Me',
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      isMe: true,
    );

    final list = List<KlickMessage>.from(conversationMessages[device.id] ?? []);
    list.add(userMsg);
    conversationMessages[device.id] = list;
    notifyListeners();

    // Send real Bluetooth payload to physical device
    _bluetoothService.sendMessage(device.id, text);
  }

  // Real Bluetooth Scanner
  Future<void> startDiscoveryScan() async {
    if (isScanning) {
      await stopDiscoveryScan();
      return;
    }

    isScanning = true;
    discoveredDevices.clear();
    notifyListeners();

    final granted = await _bluetoothService.requestPermissions();
    if (granted) {
      await _bluetoothService.startDiscovery(localDeviceName);
    }

    // Auto timeout after 25 seconds of continuous scanning
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(seconds: 25), () {
      stopDiscoveryScan();
    });
  }

  Future<void> stopDiscoveryScan() async {
    _scanTimeoutTimer?.cancel();
    await _bluetoothService.stopDiscovery();
    isScanning = false;
    notifyListeners();
  }

  Future<void> connectDiscoveredDevice(KlickDevice device) async {
    await _bluetoothService.connect(device.id, localDeviceName);

    if (!devices.any((d) => d.id == device.id)) {
      final paired = device.copyWith(isConnected: true);
      devices.insert(0, paired);
      conversationMessages[paired.id] ??= [];
      openChat(paired);
    } else {
      final existing = devices.firstWhere((d) => d.id == device.id);
      openChat(existing);
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    _keyReleaseTimer?.cancel();
    textInputController.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }
}
