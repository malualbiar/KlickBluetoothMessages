import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bluetooth_device.dart';
import '../services/bluetooth_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/bit_mechanical_theme.dart';

enum KlickScreen {
  chats,
  conversation,
  scan,
}

class KlickController extends ChangeNotifier {
  // Persistence & Notifications
  final StorageService _storageService;
  final NotificationService _notificationService;
  bool isInitialized = false;

  // Onboarding
  bool isOnboardingComplete = false;

  Future<void> completeOnboarding({String? userName}) async {
    if (userName != null && userName.trim().isNotEmpty) {
      localDeviceName = userName.trim().toUpperCase();
      await _storageService.setUserName(localDeviceName);
    }
    isOnboardingComplete = true;
    await _storageService.setOnboardingComplete(true);

    // Restart advertising with verified permanent callsign
    await _bluetoothService.stopAdvertising();
    await _bluetoothService.startAdvertising(localDeviceName);

    notifyListeners();
  }

  // Navigation
  KlickScreen currentScreen = KlickScreen.chats;
  final List<KlickScreen> _screenHistory = [];

  // Theme
  LcdThemeMode lcdTheme = LcdThemeMode.amberGold;

  // Local Device Identity
  String localDeviceName = 'KLICK-USER';

  // Active Key Pressed (for tactile hardware visual state)
  String? activeHardwareKey;
  Timer? _keyReleaseTimer;

  // D-Pad Focus index
  int listFocusIndex = 0;

  // Text Input buffer (for QWERTY input / composer)
  final TextEditingController textInputController = TextEditingController();

  // Devices & Conversations (Real physical devices + persisted history)
  List<KlickDevice> devices = [];
  Map<String, List<KlickMessage>> conversationMessages = {};
  Map<String, List<KlickMessage>> pendingMessages = {};
  KlickDevice? activeChatDevice;

  // Incoming Connection Request ("Username is trying to Klick!")
  KlickConnectionRequest? activeConnectionRequest;

  // In-App Notification Toast
  String? inAppToast;
  Timer? _toastTimer;

  // Discovery / Scanner
  bool isScanning = false;
  Timer? _scanTimeoutTimer;
  List<KlickDevice> discoveredDevices = [];

  // Bluetooth Service
  final BluetoothService _bluetoothService;

  // Clock
  String currentTimeString = '11:57';
  Timer? _clockTimer;

  KlickController({
    BluetoothService? bluetoothService,
    StorageService? storageService,
    NotificationService? notificationService,
  })  : _bluetoothService = bluetoothService ?? NearbyBluetoothService(),
        _storageService = storageService ?? StorageService(),
        _notificationService = notificationService ?? NotificationService() {
    _initBluetoothListeners();
    _initAsync();
    _startClockTimer();
  }

  Future<void> _initAsync() async {
    await _storageService.init();
    await _notificationService.init();

    isOnboardingComplete = await _storageService.isOnboardingComplete();
    
    final savedName = await _storageService.getUserName();
    if (savedName != null && savedName.isNotEmpty) {
      localDeviceName = savedName;
    } else {
      localDeviceName = 'KLICK-${Random().nextInt(9000) + 1000}';
    }

    // Load persisted contacts, messages, and pending queue
    final loadedContacts = await _storageService.loadContacts();
    devices = loadedContacts.map((d) => d.copyWith(isConnected: false)).toList();
    conversationMessages = await _storageService.loadMessages();
    pendingMessages = await _storageService.loadPendingQueue();

    await _initRadio();

    isInitialized = true;
    notifyListeners();
  }

  void _initBluetoothListeners() {
    _bluetoothService.onDeviceFound = (device) {
      if (!discoveredDevices.any((d) => d.id == device.id)) {
        discoveredDevices.add(device);
        notifyListeners();
      }

      // Auto-reconnect to known paired peers in background
      final isKnown = devices.any((d) => d.id == device.id || d.macAddress == device.macAddress);
      if (isKnown && !device.isConnected) {
        debugPrint('Auto-reconnecting to known peer: ${device.name} (${device.id})');
        _bluetoothService.connect(device.id, localDeviceName);
      }
    };

    _bluetoothService.onDeviceLost = (endpointId) {
      discoveredDevices.removeWhere((d) => d.id == endpointId);
      final index = devices.indexWhere((d) => d.id == endpointId);
      if (index != -1) {
        devices[index] = devices[index].copyWith(isConnected: false);
      }
      if (activeChatDevice?.id == endpointId) {
        activeChatDevice = activeChatDevice?.copyWith(isConnected: false);
      }
      notifyListeners();
    };

    // Interactive connection authorization ("Username is trying to Klick!")
    _bluetoothService.onConnectionRequest = (endpointId, endpointName, accept, reject) {
      final displayName = _getPreservedName(endpointId, endpointName);
      activeConnectionRequest = KlickConnectionRequest(
        endpointId: endpointId,
        endpointName: displayName,
        onAccept: () async {
          await accept();
          activeConnectionRequest = null;
          notifyListeners();
        },
        onReject: () async {
          await reject();
          activeConnectionRequest = null;
          notifyListeners();
        },
        timestamp: DateTime.now(),
      );
      HapticFeedback.heavyImpact();
      notifyListeners();
    };

    _bluetoothService.onConnected = (endpointId, name) {
      final index = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      final devName = _getPreservedName(endpointId, name);

      if (index != -1) {
        devices[index] = devices[index].copyWith(
          isConnected: true,
          name: devName,
          lastSeen: DateTime.now(),
        );
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

      if (activeChatDevice?.id == endpointId) {
        activeChatDevice = activeChatDevice?.copyWith(isConnected: true, lastSeen: DateTime.now());
      }

      _storageService.saveContacts(devices);

      // Flush and deliver any queued messages for this peer!
      _flushPendingQueue(endpointId);

      notifyListeners();
    };

    _bluetoothService.onDisconnected = (endpointId) {
      final index = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      if (index != -1) {
        devices[index] = devices[index].copyWith(
          isConnected: false,
          lastSeen: DateTime.now(),
        );
      }

      if (activeChatDevice?.id == endpointId) {
        activeChatDevice = activeChatDevice?.copyWith(isConnected: false, lastSeen: DateTime.now());
      }

      _storageService.saveContacts(devices);
      notifyListeners();
    };

    _bluetoothService.onMessageReceived = (endpointId, message) {
      _handleIncomingMessage(endpointId, message);
    };
  }

  void acceptConnectionRequest() {
    activeConnectionRequest?.onAccept();
  }

  void rejectConnectionRequest() {
    activeConnectionRequest?.onReject();
  }

  // Preserve established callsign and prevent overwriting with temporary generic names
  String _getPreservedName(String endpointId, String incomingName) {
    final existingIdx = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
    if (existingIdx != -1) {
      final existingName = devices[existingIdx].name;
      if (existingName.isNotEmpty &&
          existingName != 'Nearby Contact' &&
          existingName != 'Nearby Device' &&
          existingName != 'KLICK-USER') {
        return existingName;
      }
    }

    if (incomingName.isNotEmpty &&
        incomingName != 'Nearby Contact' &&
        incomingName != 'Nearby Device') {
      return incomingName;
    }

    return 'Nearby Contact';
  }

  Future<void> _initRadio() async {
    final granted = await _bluetoothService.requestPermissions();
    if (granted) {
      await _bluetoothService.startAdvertising(localDeviceName);
    }
  }

  void _handleIncomingMessage(String endpointId, String text) {
    final senderName = _getDeviceName(endpointId);

    // Ensure device exists in contacts list
    if (!devices.any((d) => d.id == endpointId || d.macAddress == endpointId)) {
      final newDev = KlickDevice(
        id: endpointId,
        name: senderName,
        macAddress: endpointId,
        rssi: -50,
        isConnected: true,
        deviceType: DeviceType.smartphone,
        lastSeen: DateTime.now(),
      );
      devices.insert(0, newDev);
    } else {
      final idx = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      devices[idx] = devices[idx].copyWith(isConnected: true, lastSeen: DateTime.now());
    }

    final msg = KlickMessage(
      id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
      senderId: endpointId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.received,
      isMe: false,
    );

    final list = List<KlickMessage>.from(conversationMessages[endpointId] ?? []);
    list.add(msg);
    conversationMessages[endpointId] = list;

    // Trigger in-app toast & local notification if not in active chat
    final isInThisChat = currentScreen == KlickScreen.conversation && activeChatDevice?.id == endpointId;
    if (!isInThisChat) {
      final idx = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      if (idx != -1) {
        devices[idx] = devices[idx].copyWith(
          unreadCount: devices[idx].unreadCount + 1,
        );
      }

      showInAppToast('// NEW KLICK // $senderName: $text');
      _notificationService.showMessageNotification(
        title: 'Klick from $senderName',
        body: text,
        payload: endpointId,
      );
    }

    // Persist messages and contacts
    _storageService.saveMessages(conversationMessages);
    _storageService.saveContacts(devices);

    notifyListeners();
  }

  void showInAppToast(String message) {
    inAppToast = message;
    HapticFeedback.lightImpact();
    notifyListeners();

    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 4), () {
      inAppToast = null;
      notifyListeners();
    });
  }

  String _getDeviceName(String endpointId) {
    final dev = devices.firstWhere(
      (d) => d.id == endpointId || d.macAddress == endpointId,
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
    final idx = devices.indexWhere((d) => d.id == device.id || d.macAddress == device.id);
    if (idx != -1) {
      devices[idx] = devices[idx].copyWith(unreadCount: 0);
      _storageService.saveContacts(devices);
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

  // Messaging actions with Store-and-Forward Queue
  void sendMessageFromInput() {
    final text = textInputController.text.trim();
    if (text.isEmpty || activeChatDevice == null) return;

    textInputController.clear();
    sendDirectMessage(activeChatDevice!, text);
  }

  void sendDirectMessage(KlickDevice device, String text) {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final isOnline = device.isConnected;

    final userMsg = KlickMessage(
      id: msgId,
      senderId: 'me',
      senderName: 'Me',
      text: text,
      timestamp: DateTime.now(),
      status: isOnline ? MessageStatus.sent : MessageStatus.queued,
      isMe: true,
    );

    final list = List<KlickMessage>.from(conversationMessages[device.id] ?? []);
    list.add(userMsg);
    conversationMessages[device.id] = list;

    if (!isOnline) {
      // Store in outgoing pending queue
      final qList = List<KlickMessage>.from(pendingMessages[device.id] ?? []);
      qList.add(userMsg);
      pendingMessages[device.id] = qList;
      _storageService.savePendingQueue(pendingMessages);
      showInAppToast('// RADIO OFFLINE: MESSAGE QUEUED //');
    } else {
      // Transmit live over Bluetooth
      _bluetoothService.sendMessage(device.id, text).then((success) {
        if (!success) {
          // If transmit failed, move to pending queue
          _queueFailedMessage(device.id, userMsg);
        }
      });
    }

    // Persist messages and contacts
    _storageService.saveMessages(conversationMessages);
    _storageService.saveContacts(devices);

    notifyListeners();
  }

  void _queueFailedMessage(String endpointId, KlickMessage originalMsg) {
    final qMsg = originalMsg.copyWith(status: MessageStatus.queued);
    final conv = List<KlickMessage>.from(conversationMessages[endpointId] ?? []);
    final idx = conv.indexWhere((m) => m.id == originalMsg.id);
    if (idx != -1) {
      conv[idx] = qMsg;
      conversationMessages[endpointId] = conv;
    }

    final qList = List<KlickMessage>.from(pendingMessages[endpointId] ?? []);
    qList.add(qMsg);
    pendingMessages[endpointId] = qList;

    _storageService.savePendingQueue(pendingMessages);
    _storageService.saveMessages(conversationMessages);
    notifyListeners();
  }

  // Automatic Queue Flushing on Reconnect
  Future<void> _flushPendingQueue(String endpointId) async {
    final queue = pendingMessages[endpointId];
    if (queue == null || queue.isEmpty) return;

    debugPrint('Flushing ${queue.length} pending queued messages for $endpointId...');
    final queueCopy = List<KlickMessage>.from(queue);
    pendingMessages[endpointId] = [];
    await _storageService.savePendingQueue(pendingMessages);

    for (final qMsg in queueCopy) {
      final success = await _bluetoothService.sendMessage(endpointId, qMsg.text);
      if (success) {
        final conv = List<KlickMessage>.from(conversationMessages[endpointId] ?? []);
        final idx = conv.indexWhere((m) => m.id == qMsg.id);
        if (idx != -1) {
          conv[idx] = conv[idx].copyWith(status: MessageStatus.sent);
          conversationMessages[endpointId] = conv;
        }
      } else {
        // Re-queue if still failed
        _queueFailedMessage(endpointId, qMsg);
      }
    }

    await _storageService.saveMessages(conversationMessages);
    notifyListeners();
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
    // If already known and paired, open directly
    final existingIdx = devices.indexWhere((d) => d.id == device.id || d.macAddress == device.macAddress);
    if (existingIdx != -1) {
      openChat(devices[existingIdx]);
      return;
    }

    await _bluetoothService.connect(device.id, localDeviceName);

    if (!devices.any((d) => d.id == device.id)) {
      final paired = device.copyWith(isConnected: true, lastSeen: DateTime.now());
      devices.insert(0, paired);
      conversationMessages[paired.id] ??= [];
      _storageService.saveContacts(devices);
      _storageService.saveMessages(conversationMessages);
      openChat(paired);
    } else {
      final existing = devices.firstWhere((d) => d.id == device.id);
      openChat(existing.copyWith(isConnected: true, lastSeen: DateTime.now()));
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    _keyReleaseTimer?.cancel();
    _toastTimer?.cancel();
    textInputController.dispose();
    _bluetoothService.dispose();
    super.dispose();
  }
}
