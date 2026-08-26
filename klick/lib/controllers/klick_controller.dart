import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bluetooth_device.dart';
import '../theme/bit_mechanical_theme.dart';

enum KlickScreen {
  chats,
  conversation,
  scan,
}

class KlickController extends ChangeNotifier {
  // Navigation
  KlickScreen currentScreen = KlickScreen.chats;
  final List<KlickScreen> _screenHistory = [];

  // Theme
  LcdThemeMode lcdTheme = LcdThemeMode.amberGold;

  // Active Key Pressed (for tactile hardware visual state)
  String? activeHardwareKey;
  Timer? _keyReleaseTimer;

  // D-Pad Focus index
  int listFocusIndex = 0;

  // Text Input buffer (for QWERTY input / composer)
  final TextEditingController textInputController = TextEditingController();

  // Devices & Conversations
  List<KlickDevice> devices = [];
  Map<String, List<KlickMessage>> conversationMessages = {};
  KlickDevice? activeChatDevice;

  // Discovery / Scanner
  bool isScanning = false;
  Timer? _scanTimer;
  List<KlickDevice> discoveredDevices = [];

  // Clock
  String currentTimeString = '11:57';
  Timer? _clockTimer;

  KlickController() {
    _initDemoData();
    _startClockTimer();
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

  void _initDemoData() {
    final now = DateTime.now();

    devices = [
      KlickDevice(
        id: 'dev_01',
        name: 'Alex (Phone)',
        macAddress: 'AC:22:98:54:10:0A',
        rssi: -45,
        isConnected: true,
        deviceType: DeviceType.smartphone,
        lastSeen: now.subtract(const Duration(minutes: 2)),
        unreadCount: 1,
      ),
      KlickDevice(
        id: 'dev_02',
        name: 'Maya (Laptop)',
        macAddress: 'F4:84:4C:19:BE:88',
        rssi: -58,
        isConnected: true,
        deviceType: DeviceType.klickTerminal,
        lastSeen: now.subtract(const Duration(minutes: 8)),
        unreadCount: 0,
      ),
      KlickDevice(
        id: 'dev_03',
        name: 'David (Tablet)',
        macAddress: 'E0:D5:5E:7B:12:44',
        rssi: -72,
        isConnected: false,
        deviceType: DeviceType.smartphone,
        lastSeen: now.subtract(const Duration(minutes: 25)),
        unreadCount: 0,
      ),
    ];

    conversationMessages = {
      'dev_01': [
        KlickMessage(
          id: 'm1',
          senderId: 'dev_01',
          senderName: 'Alex',
          text: 'Hey! Connected via Bluetooth.',
          timestamp: now.subtract(const Duration(minutes: 15)),
          status: MessageStatus.acknowledged,
          isMe: false,
        ),
        KlickMessage(
          id: 'm2',
          senderId: 'me',
          senderName: 'Me',
          text: 'Great, Bluetooth messaging is working smoothly.',
          timestamp: now.subtract(const Duration(minutes: 10)),
          status: MessageStatus.acknowledged,
          isMe: true,
        ),
        KlickMessage(
          id: 'm3',
          senderId: 'dev_01',
          senderName: 'Alex',
          text: 'Are you nearby? Send me the notes.',
          timestamp: now.subtract(const Duration(minutes: 2)),
          status: MessageStatus.received,
          isMe: false,
        ),
      ],
      'dev_02': [
        KlickMessage(
          id: 'm20',
          senderId: 'dev_02',
          senderName: 'Maya',
          text: 'Files received over Bluetooth transfer.',
          timestamp: now.subtract(const Duration(minutes: 8)),
          status: MessageStatus.received,
          isMe: false,
        ),
      ],
      'dev_03': [
        KlickMessage(
          id: 'm30',
          senderId: 'dev_03',
          senderName: 'David',
          text: 'See you in the meeting room.',
          timestamp: now.subtract(const Duration(minutes: 25)),
          status: MessageStatus.received,
          isMe: false,
        ),
      ],
    };
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

    // Simulate real Bluetooth peer reply
    Timer(const Duration(milliseconds: 1500), () {
      final replies = [
        'Got your message!',
        'Sounds good, connecting now.',
        'Message received via Bluetooth.',
        'Thanks for the update!',
      ];
      final replyText = replies[Random().nextInt(replies.length)];

      final reply = KlickMessage(
        id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
        senderId: device.id,
        senderName: device.name,
        text: replyText,
        timestamp: DateTime.now(),
        status: MessageStatus.received,
        isMe: false,
      );

      final updated = List<KlickMessage>.from(conversationMessages[device.id] ?? []);
      updated.add(reply);
      conversationMessages[device.id] = updated;
      notifyListeners();
    });
  }

  // Bluetooth Scanner
  void startDiscoveryScan() {
    isScanning = true;
    discoveredDevices.clear();
    notifyListeners();

    _scanTimer?.cancel();
    int step = 0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      step++;
      if (step == 1) {
        discoveredDevices.add(
          KlickDevice(
            id: 'disc_01',
            name: 'Sarah (Pixel 8)',
            macAddress: 'D4:F5:13:88:99:A1',
            rssi: -52,
            isConnected: false,
            deviceType: DeviceType.smartphone,
            lastSeen: DateTime.now(),
          ),
        );
      } else if (step == 3) {
        discoveredDevices.add(
          KlickDevice(
            id: 'disc_02',
            name: 'Office Headset',
            macAddress: '1A:89:C4:00:22:9E',
            rssi: -67,
            isConnected: false,
            deviceType: DeviceType.klickTerminal,
            lastSeen: DateTime.now(),
          ),
        );
      } else if (step == 5) {
        discoveredDevices.add(
          KlickDevice(
            id: 'disc_03',
            name: 'Sam (MacBook)',
            macAddress: '84:CC:A8:11:7F:43',
            rssi: -79,
            isConnected: false,
            deviceType: DeviceType.klickTerminal,
            lastSeen: DateTime.now(),
          ),
        );
      }

      if (step >= 6) {
        isScanning = false;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void connectDiscoveredDevice(KlickDevice device) {
    if (!devices.any((d) => d.id == device.id)) {
      final paired = device.copyWith(isConnected: true);
      devices.insert(0, paired);
      conversationMessages[paired.id] = [
        KlickMessage(
          id: 'init_${DateTime.now().millisecondsSinceEpoch}',
          senderId: paired.id,
          senderName: paired.name,
          text: 'Connected via Bluetooth.',
          timestamp: DateTime.now(),
          status: MessageStatus.received,
          isMe: false,
        ),
      ];
      openChat(paired);
    } else {
      final existing = devices.firstWhere((d) => d.id == device.id);
      openChat(existing);
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scanTimer?.cancel();
    _keyReleaseTimer?.cancel();
    textInputController.dispose();
    super.dispose();
  }
}
