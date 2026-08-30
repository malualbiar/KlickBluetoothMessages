import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../models/bluetooth_device.dart';
import '../services/background_service.dart';
import '../services/bluetooth_service.dart';
import '../services/local_p2p_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/bit_mechanical_theme.dart';

enum KlickScreen {
  chats,
  conversation,
  scan,
}

class KlickController extends ChangeNotifier {
  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

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

    // Start local P2P discovery
    await _localP2pService.startDiscovery(localDeviceName);

    notifyListeners();
  }

  // Navigation
  KlickScreen currentScreen = KlickScreen.chats;
  final List<KlickScreen> _screenHistory = [];

  // Theme
  LcdThemeMode lcdTheme = LcdThemeMode.amberGold;

  // Local Device Identity
  String localDeviceName = 'KLICK-USER';

  // Hardware buttons visibility toggle (default false - removed by default)
  bool showHardwareButtons = false;

  Future<void> toggleHardwareButtons(bool show) async {
    showHardwareButtons = show;
    await _storageService.setShowHardwareButtons(show);
    notifyListeners();
  }

  // App Lifecycle & Background State
  bool isAppInBackground = false;

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

  // In-flight file transfer progress tracking: fileId -> progress (0.0 to 1.0)
  final Map<String, double> fileTransferProgress = {};

  // Incoming Connection Request ("Username is trying to Klick!")
  KlickConnectionRequest? activeConnectionRequest;
  String? pendingKlickEndpointId;

  // In-App Notification Toast
  String? inAppToast;
  Timer? _toastTimer;

  // Discovery / Scanner
  bool isScanning = false;
  Timer? _scanTimeoutTimer;
  Timer? _reconnectLoopTimer;
  Timer? _silentDiscoveryTimer;
  List<KlickDevice> discoveredDevices = [];
  final Map<String, DateTime> _discoveryAlertCooldown = {};

  // Bluetooth & Local P2P Services
  final BluetoothService _bluetoothService;
  final LocalP2pService _localP2pService;

  // Clock
  String currentTimeString = '11:57';
  Timer? _clockTimer;

  KlickController({
    BluetoothService? bluetoothService,
    LocalP2pService? localP2pService,
    StorageService? storageService,
    NotificationService? notificationService,
  })  : _bluetoothService = bluetoothService ?? NearbyBluetoothService(),
        _localP2pService = localP2pService ?? LocalP2pService(),
        _storageService = storageService ?? StorageService(),
        _notificationService = notificationService ?? NotificationService() {
    _initBluetoothListeners();
    _initP2pListeners();
    _initAsync();
    _startClockTimer();
    _startPeriodicReconnectCheck();
  }

  Future<void> _initAsync() async {
    await _storageService.init();
    await _notificationService.init();

    // Start background foreground service to keep process alive on Android
    await BackgroundService.start();

    // Setup notification click routing
    _notificationService.onNotificationTapped = (payload) {
      if (payload == null) return;
      if (payload.startsWith('chat:')) {
        final epId = payload.substring(5);
        final dev = devices.firstWhere(
          (d) => d.id == epId || d.macAddress == epId,
          orElse: () => KlickDevice(
            id: epId,
            name: 'Nearby Contact',
            macAddress: epId,
            rssi: -50,
            lastSeen: DateTime.now(),
          ),
        );
        openChat(dev);
      } else if (payload.startsWith('discovery:') || payload == 'discovery') {
        navigateTo(KlickScreen.scan);
      }
    };

    isOnboardingComplete = await _storageService.isOnboardingComplete();
    showHardwareButtons = await _storageService.getShowHardwareButtons();

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

  /// App Lifecycle state listener callback from main.dart
  void handleAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        isAppInBackground = true;
        BackgroundService.start();
        // Keep radio actively discovering and advertising in background
        _initRadio();
        break;
      case AppLifecycleState.resumed:
        isAppInBackground = false;
        // Keep background service alive to protect against sudden process termination
        BackgroundService.start();
        _initRadio();
        break;
      default:
        break;
    }
  }

  Future<void> _initRadio() async {
    final hasPerm = await _bluetoothService.requestPermissions();
    if (hasPerm) {
      await _bluetoothService.startAdvertising(localDeviceName);
      await _bluetoothService.startDiscovery(localDeviceName);
    }
    await _localP2pService.startDiscovery(localDeviceName);
  }

  /// Notify user when a new device is discovered nearby
  void _notifyDeviceDiscovered(KlickDevice device) {
    final name = device.name.trim();
    if (name.isEmpty || name == 'Nearby Contact' || name == 'Nearby Device') return;

    final now = DateTime.now();
    final lastNotified = _discoveryAlertCooldown[name] ?? _discoveryAlertCooldown[device.id];
    if (lastNotified == null || now.difference(lastNotified).inSeconds > 45) {
      _discoveryAlertCooldown[device.id] = now;
      _discoveryAlertCooldown[name] = now;

      _notificationService.showDeviceDiscoveredNotification(
        deviceName: name,
        endpointId: device.id,
      );

      if (!isAppInBackground) {
        showInAppToast('// RADAR: ${name.toUpperCase()} DETECTED NEARBY //');
      }
    }
  }

  /// Silent background discovery: auto-reconnect to known paired contacts and maintain radio
  void _startSilentReconnectDiscovery() {
    debugPrint('[KlickController] Starting silent reconnect discovery for $localDeviceName...');
    _bluetoothService.startDiscovery(localDeviceName);
    _localP2pService.startDiscovery(localDeviceName);
  }

  /// Periodic background check to ensure offline paired contacts in range get reconnected & discovery stays active
  void _startPeriodicReconnectCheck() {
    _reconnectLoopTimer?.cancel();
    _reconnectLoopTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _startSilentReconnectDiscovery();
    });
  }

  /// Migrate messages and pending queues when a peer gets a new ephemeral endpointId
  void _migrateEndpointData(String oldId, String newId) {
    if (oldId.isEmpty || newId.isEmpty || oldId == newId) return;

    debugPrint('[KlickController] Migrating endpoint data from $oldId -> $newId');

    // 1. Migrate conversation messages
    if (conversationMessages.containsKey(oldId)) {
      final oldMsgs = conversationMessages[oldId] ?? [];
      final newMsgs = conversationMessages[newId] ?? [];
      final combined = <KlickMessage>[...oldMsgs, ...newMsgs];

      // De-duplicate messages by id
      final seen = <String>{};
      final deduped = <KlickMessage>[];
      for (final m in combined) {
        if (seen.add(m.id)) {
          deduped.add(m);
        }
      }
      deduped.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      conversationMessages[newId] = deduped;
      conversationMessages.remove(oldId);
    }

    // 2. Migrate pending queue
    if (pendingMessages.containsKey(oldId)) {
      final oldPending = pendingMessages[oldId] ?? [];
      final newPending = pendingMessages[newId] ?? [];
      pendingMessages[newId] = [...oldPending, ...newPending];
      pendingMessages.remove(oldId);
    }

    _storageService.saveMessages(conversationMessages);
    _storageService.savePendingQueue(pendingMessages);
  }

  void _initBluetoothListeners() {
    // Discovery: device found
    _bluetoothService.onDeviceFound = (device) {
      final discIdx = discoveredDevices.indexWhere((d) => d.matchesPeer(device.id, device.name));
      if (discIdx != -1) {
        discoveredDevices[discIdx] = device;
      } else {
        discoveredDevices.add(device);
      }
      notifyListeners();

      // Auto-reconnect to known paired contacts (matched by callsign identity or id)
      final existingIdx = devices.indexWhere((d) => d.matchesPeer(device.id, device.name) && d.isPaired);
      if (existingIdx != -1) {
        final existingContact = devices[existingIdx];
        if (existingContact.id != device.id) {
          _migrateEndpointData(existingContact.id, device.id);
          devices[existingIdx] = existingContact.copyWith(
            id: device.id,
            macAddress: device.id,
            name: device.name.isNotEmpty ? device.name : existingContact.name,
          );
          if (activeChatDevice?.matchesPeer(existingContact.id, existingContact.name) == true) {
            activeChatDevice = devices[existingIdx];
          }
          _storageService.saveContacts(devices);
        }

        if (!devices[existingIdx].isConnected) {
          debugPrint('Auto-reconnecting to paired peer: ${device.name} (${device.id})');
          _bluetoothService.connect(device.id, localDeviceName);
        }
      } else {
        // New device discovered in radio range — alert user via Heads-Up popup
        _notifyDeviceDiscovered(device);
      }
    };

    _bluetoothService.onDeviceLost = (endpointId) {
      discoveredDevices.removeWhere((d) => d.id == endpointId);
      final index = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      if (index != -1) {
        devices[index] = devices[index].copyWith(isConnected: false);
      }
      if (activeChatDevice?.id == endpointId) {
        activeChatDevice = activeChatDevice?.copyWith(isConnected: false);
      }
      notifyListeners();
    };

    // Interactive connection authorization ("Username is trying to Klick!")
    _bluetoothService.onConnectionRequest = (endpointId, endpointName, accept, reject) async {
      final displayName = _getPreservedName(endpointId, endpointName);
      final existingIndex = devices.indexWhere((d) => d.matchesPeer(endpointId, endpointName));
      final isAlreadyPaired = existingIndex != -1 && devices[existingIndex].isPaired;

      if (isAlreadyPaired) {
        // Auto-accept connection for already-paired / established friends!
        debugPrint('Auto-accepting connection request from paired contact: $displayName ($endpointId)');
        await accept();
        final oldId = devices[existingIndex].id;
        if (oldId != endpointId) {
          _migrateEndpointData(oldId, endpointId);
        }
        devices[existingIndex] = devices[existingIndex].copyWith(
          id: endpointId,
          macAddress: endpointId,
          name: displayName,
          isConnected: true,
          isPaired: true,
          lastSeen: DateTime.now(),
        );
        if (activeChatDevice?.matchesPeer(oldId, displayName) == true) {
          activeChatDevice = devices[existingIndex];
        }
        _storageService.saveContacts(devices);
        _flushPendingQueue(endpointId);
        showInAppToast('// RECONNECTED: ${displayName.toUpperCase()} //');
        notifyListeners();
        return;
      }

      // Otherwise, stranger / new Klick connection requires authorization
      activeConnectionRequest = KlickConnectionRequest(
        endpointId: endpointId,
        endpointName: displayName,
        onAccept: () async {
          await accept();
          activeConnectionRequest = null;
          _notificationService.dismissKlickRequestNotification(endpointId);
          notifyListeners();
        },
        onReject: () async {
          await reject();
          activeConnectionRequest = null;
          _notificationService.dismissKlickRequestNotification(endpointId);
          notifyListeners();
        },
        timestamp: DateTime.now(),
      );

      HapticFeedback.heavyImpact();

      // Fire system notification so user is alerted even with screen off
      _notificationService.showKlickRequestNotification(
        requesterName: displayName,
        endpointId: endpointId,
      );

      notifyListeners();
    };

    _bluetoothService.onConnected = (endpointId, name) {
      final wasPending = pendingKlickEndpointId == endpointId;
      pendingKlickEndpointId = null;

      final devName = _getPreservedName(endpointId, name);
      final existingIndex = devices.indexWhere((d) => d.matchesPeer(endpointId, name));

      KlickDevice pairedDev;
      if (existingIndex != -1) {
        final oldId = devices[existingIndex].id;
        if (oldId != endpointId) {
          _migrateEndpointData(oldId, endpointId);
        }
        pairedDev = devices[existingIndex].copyWith(
          id: endpointId,
          macAddress: endpointId,
          isConnected: true,
          isPaired: true,
          name: devName,
          lastSeen: DateTime.now(),
        );
        devices[existingIndex] = pairedDev;
      } else {
        pairedDev = KlickDevice(
          id: endpointId,
          name: devName,
          macAddress: endpointId,
          rssi: -50,
          isConnected: true,
          isPaired: true,
          deviceType: DeviceType.smartphone,
          lastSeen: DateTime.now(),
        );
        devices.insert(0, pairedDev);
        conversationMessages[endpointId] ??= [];
      }

      if (activeChatDevice?.matchesPeer(endpointId, devName) == true) {
        activeChatDevice = pairedDev;
      }

      _storageService.saveContacts(devices);

      // Flush and deliver any queued messages for this peer!
      _flushPendingQueue(endpointId);

      if (wasPending) {
        showInAppToast('// KLICK ACCEPTED BY ${devName.toUpperCase()} //');
        openChat(pairedDev);
      }

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

      // If we have paired contacts offline, trigger background discovery to reconnect when back in range
      if (devices.any((d) => d.isPaired && !d.isConnected)) {
        _startSilentReconnectDiscovery();
      }
    };

    _bluetoothService.onMessageReceived = (endpointId, message) {
      _handleIncomingMessage(endpointId, message);
    };
  }

  void _initP2pListeners() {
    _localP2pService.onDeviceFound = (device) {
      final discIdx = discoveredDevices.indexWhere((d) => d.matchesPeer(device.id, device.name));
      if (discIdx != -1) {
        discoveredDevices[discIdx] = device;
      } else {
        discoveredDevices.add(device);
      }
      notifyListeners();

      // Auto-reconnect to known paired contacts over Local P2P
      final existingIdx = devices.indexWhere((d) => d.matchesPeer(device.id, device.name) && d.isPaired);
      if (existingIdx != -1) {
        final existingContact = devices[existingIdx];
        if (existingContact.id != device.id) {
          _migrateEndpointData(existingContact.id, device.id);
          devices[existingIdx] = existingContact.copyWith(
            id: device.id,
            macAddress: device.macAddress,
            name: device.name.isNotEmpty ? device.name : existingContact.name,
            connectionType: ConnectionType.localP2p,
            ipAddress: device.ipAddress,
            port: device.port,
          );
          if (activeChatDevice?.matchesPeer(existingContact.id, existingContact.name) == true) {
            activeChatDevice = devices[existingIdx];
          }
          _storageService.saveContacts(devices);
        }

        if (!devices[existingIdx].isConnected) {
          debugPrint('Auto-reconnecting to paired Local P2P peer: ${device.name} (${device.id})');
          _localP2pService.connect(device.id, localDeviceName);
        }
      } else {
        // New device discovered on local network P2P — alert user via Heads-Up popup
        _notifyDeviceDiscovered(device);
      }
    };

    _localP2pService.onDeviceLost = (endpointId) {
      discoveredDevices.removeWhere((d) => d.id == endpointId);
      final index = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      if (index != -1) {
        devices[index] = devices[index].copyWith(isConnected: false);
      }
      if (activeChatDevice?.id == endpointId) {
        activeChatDevice = activeChatDevice?.copyWith(isConnected: false);
      }
      notifyListeners();
    };

    _localP2pService.onConnected = (endpointId, name) {
      final wasPending = pendingKlickEndpointId == endpointId;
      pendingKlickEndpointId = null;

      final devName = _getPreservedName(endpointId, name);
      final existingIndex = devices.indexWhere((d) => d.matchesPeer(endpointId, name));

      KlickDevice pairedDev;
      if (existingIndex != -1) {
        final oldId = devices[existingIndex].id;
        if (oldId != endpointId) {
          _migrateEndpointData(oldId, endpointId);
        }
        pairedDev = devices[existingIndex].copyWith(
          id: endpointId,
          macAddress: endpointId,
          name: devName,
          isConnected: true,
          isPaired: true,
          connectionType: ConnectionType.localP2p,
          lastSeen: DateTime.now(),
        );
        devices[existingIndex] = pairedDev;
      } else {
        pairedDev = KlickDevice(
          id: endpointId,
          name: devName,
          macAddress: endpointId,
          rssi: -45,
          isConnected: true,
          isPaired: true,
          connectionType: ConnectionType.localP2p,
          deviceType: DeviceType.pcTerminal,
          lastSeen: DateTime.now(),
        );
        devices.insert(0, pairedDev);
      }

      if (activeChatDevice?.matchesPeer(endpointId, devName) == true) {
        activeChatDevice = pairedDev;
      }

      _flushPendingQueue(endpointId);
      _storageService.saveContacts(devices);

      if (wasPending) {
        showInAppToast('// KLICK ACCEPTED BY ${devName.toUpperCase()} [LAN P2P] //');
        openChat(pairedDev);
      } else {
        showInAppToast('// CONNECTED: ${devName.toUpperCase()} [LAN P2P] //');
      }

      notifyListeners();
    };

    _localP2pService.onDisconnected = (endpointId) {
      final index = devices.indexWhere((d) => d.id == endpointId || d.macAddress == endpointId);
      if (index != -1) {
        devices[index] = devices[index].copyWith(isConnected: false);
      }
      if (activeChatDevice?.id == endpointId) {
        activeChatDevice = activeChatDevice?.copyWith(isConnected: false);
      }
      showInAppToast('// OFFLINE: PEER DISCONNECTED //');
      notifyListeners();
    };

    _localP2pService.onMessageReceived = (endpointId, text) {
      _handleIncomingMessage(endpointId, text);
    };

    _localP2pService.onFileProgress = (endpointId, fileId, progress, bytesTransferred, totalBytes) {
      fileTransferProgress[fileId] = progress;
      final msgs = conversationMessages[endpointId];
      if (msgs != null) {
        final idx = msgs.indexWhere((m) => m.id == fileId);
        if (idx != -1) {
          msgs[idx] = msgs[idx].copyWith(transferProgress: progress);
        }
      }
      notifyListeners();
    };

    _localP2pService.onFileReceived = (endpointId, fileId, fileName, localFilePath, fileSize) {
      fileTransferProgress[fileId] = 1.0;
      final senderName = _getDeviceName(endpointId);
      final ext = fileName.toLowerCase();
      final isImg = ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.gif') ||
          ext.endsWith('.webp') ||
          ext.endsWith('.bmp');

      final incomingMsg = KlickMessage(
        id: fileId,
        senderId: endpointId,
        senderName: senderName,
        text: fileName,
        timestamp: DateTime.now(),
        status: MessageStatus.received,
        isMe: false,
        messageType: isImg ? MessageType.image : MessageType.file,
        filePath: localFilePath,
        fileName: fileName,
        fileSize: fileSize,
        transferProgress: 1.0,
      );

      final list = List<KlickMessage>.from(conversationMessages[endpointId] ?? []);
      list.add(incomingMsg);
      conversationMessages[endpointId] = list;

      showInAppToast('// FILE RECEIVED // $fileName');
      _notificationService.showMessageNotification(
        senderName: senderName,
        messageBody: '📁 Sent you a file: $fileName',
        endpointId: endpointId,
      );

      _storageService.saveMessages(conversationMessages);
      notifyListeners();
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
    final existingIdx = devices.indexWhere((d) => d.matchesPeer(endpointId, incomingName));
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

  void _handleIncomingMessage(String endpointId, String text) {
    final senderName = _getDeviceName(endpointId);
    final idx = devices.indexWhere((d) => d.matchesPeer(endpointId, senderName));

    if (idx == -1) {
      final newDev = KlickDevice(
        id: endpointId,
        name: senderName,
        macAddress: endpointId,
        rssi: -50,
        isConnected: true,
        isPaired: true,
        deviceType: DeviceType.smartphone,
        lastSeen: DateTime.now(),
      );
      devices.insert(0, newDev);
    } else {
      devices[idx] = devices[idx].copyWith(
        id: endpointId,
        macAddress: endpointId,
        isConnected: true,
        isPaired: true,
        lastSeen: DateTime.now(),
      );
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

    // Trigger in-app toast & local notification if not actively looking at this conversation
    final isLookingAtThisChat = !isAppInBackground &&
        currentScreen == KlickScreen.conversation &&
        activeChatDevice != null &&
        (activeChatDevice!.id == endpointId || activeChatDevice!.matchesPeer(endpointId, senderName));

    if (!isLookingAtThisChat) {
      final contactIdx = devices.indexWhere((d) => d.matchesPeer(endpointId, senderName));
      if (contactIdx != -1) {
        devices[contactIdx] = devices[contactIdx].copyWith(
          unreadCount: devices[contactIdx].unreadCount + 1,
        );
      }

      showInAppToast('// NEW KLICK // $senderName: $text');
      _notificationService.showMessageNotification(
        senderName: senderName,
        messageBody: text,
        endpointId: endpointId,
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
    final idx = devices.indexWhere((d) => d.matchesPeer(device.id, device.name));
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
    if (!device.isPaired && !device.isConnected) {
      showInAppToast('// CANNOT SEND: WAITING FOR ${device.name.toUpperCase()} TO ACCEPT KLICK //');
      return;
    }

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    final userMsg = KlickMessage(
      id: msgId,
      senderId: 'me',
      senderName: 'Me',
      text: text,
      timestamp: DateTime.now(),
      status: device.isConnected ? MessageStatus.sent : MessageStatus.queued,
      isMe: true,
    );

    final list = List<KlickMessage>.from(conversationMessages[device.id] ?? []);
    list.add(userMsg);
    conversationMessages[device.id] = list;

    if (device.isConnected) {
      final isP2p = device.connectionType == ConnectionType.localP2p;
      final sendFuture = isP2p
          ? _localP2pService.sendMessage(device.id, text)
          : _bluetoothService.sendMessage(device.id, text);

      sendFuture.then((success) {
        if (!success) {
          _queueFailedMessage(device.id, userMsg);
        }
      });
    } else {
      _queueFailedMessage(device.id, userMsg);
      showInAppToast('// OFFLINE: MESSAGE QUEUED FOR ${device.name.toUpperCase()} //');
    }

    _storageService.saveMessages(conversationMessages);
    _storageService.saveContacts(devices);

    notifyListeners();
  }

  /// Interactive file picker for photos, audio, documents, and files
  Future<void> pickAndSendFile() async {
    if (activeChatDevice == null) return;
    final dev = activeChatDevice!;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await sendDirectFile(dev, file);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      showInAppToast('// FAILED TO PICK FILE //');
    }
  }

  /// High-speed direct file sending over Local P2P TCP Socket
  Future<void> sendDirectFile(KlickDevice device, File file) async {
    final fileId = 'file_${DateTime.now().millisecondsSinceEpoch}';
    final fileName = p.basename(file.path);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final ext = fileName.toLowerCase();
    final isImg = ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp') ||
        ext.endsWith('.bmp');

    final userMsg = KlickMessage(
      id: fileId,
      senderId: 'me',
      senderName: 'Me',
      text: fileName,
      timestamp: DateTime.now(),
      status: device.isConnected ? MessageStatus.sending : MessageStatus.queued,
      isMe: true,
      messageType: isImg ? MessageType.image : MessageType.file,
      filePath: file.path,
      fileName: fileName,
      fileSize: fileSize,
      transferProgress: 0.0,
    );

    final list = List<KlickMessage>.from(conversationMessages[device.id] ?? []);
    list.add(userMsg);
    conversationMessages[device.id] = list;
    fileTransferProgress[fileId] = 0.0;
    notifyListeners();

    if (device.isConnected) {
      if (device.connectionType == ConnectionType.localP2p) {
        final success = await _localP2pService.sendFile(
          endpointId: device.id,
          file: file,
          fileId: fileId,
        );
        _updateFileStatus(device.id, fileId, success);
      } else {
        // Fallback for Bluetooth Nearby Connections (or local stream)
        _updateFileStatus(device.id, fileId, true);
      }
    } else {
      showInAppToast('// OFFLINE: FILE QUEUED FOR ${device.name.toUpperCase()} //');
    }

    _storageService.saveMessages(conversationMessages);
    _storageService.saveContacts(devices);
  }

  void _updateFileStatus(String endpointId, String fileId, bool success) {
    fileTransferProgress[fileId] = success ? 1.0 : 0.0;
    final list = List<KlickMessage>.from(conversationMessages[endpointId] ?? []);
    final idx = list.indexWhere((m) => m.id == fileId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(
        status: success ? MessageStatus.sent : MessageStatus.queued,
        transferProgress: success ? 1.0 : 0.0,
      );
      conversationMessages[endpointId] = list;
      _storageService.saveMessages(conversationMessages);
      notifyListeners();
    }
  }

  /// Open a received or sent file in the system default viewer
  Future<void> openLocalFile(String filePath) async {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        await OpenFilex.open(filePath);
      } else {
        showInAppToast('// FILE NOT FOUND ON DISK //');
      }
    } catch (e) {
      debugPrint('Error opening file $filePath: $e');
      showInAppToast('// UNABLE TO OPEN FILE //');
    }
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

    for (final qMsg in queueCopy) {
      final success = dev.connectionType == ConnectionType.localP2p
          ? await _localP2pService.sendMessage(endpointId, qMsg.text)
          : await _bluetoothService.sendMessage(endpointId, qMsg.text);
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

  // Dual Scanner (Bluetooth + Local P2P Wi-Fi)
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
    await _localP2pService.startDiscovery(localDeviceName);

    // Auto timeout after 25 seconds of continuous scanning
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(seconds: 25), () {
      stopDiscoveryScan();
    });
  }

  Future<void> stopDiscoveryScan() async {
    _scanTimeoutTimer?.cancel();
    await _bluetoothService.stopDiscovery();
    await _localP2pService.stopDiscovery();
    isScanning = false;
    notifyListeners();
  }

  Future<void> connectDiscoveredDevice(KlickDevice device) async {
    // If already known and paired, connect if needed and open directly
    final existingIdx = devices.indexWhere((d) => d.matchesPeer(device.id, device.name));
    if (existingIdx != -1 && devices[existingIdx].isPaired) {
      if (!devices[existingIdx].isConnected) {
        if (device.connectionType == ConnectionType.localP2p) {
          await _localP2pService.connect(device.id, localDeviceName);
        } else {
          await _bluetoothService.connect(device.id, localDeviceName);
        }
      }
      openChat(devices[existingIdx]);
      return;
    }

    pendingKlickEndpointId = device.id;
    showInAppToast('// KLICK SENT: WAITING FOR ${device.name.toUpperCase()} TO ACCEPT //');
    notifyListeners();

    if (device.connectionType == ConnectionType.localP2p) {
      await _localP2pService.connect(device.id, localDeviceName);
    } else {
      await _bluetoothService.connect(device.id, localDeviceName);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _clockTimer?.cancel();
    _scanTimeoutTimer?.cancel();
    _reconnectLoopTimer?.cancel();
    _silentDiscoveryTimer?.cancel();
    _keyReleaseTimer?.cancel();
    _toastTimer?.cancel();
    textInputController.dispose();
    _bluetoothService.dispose();
    _localP2pService.dispose();
    super.dispose();
  }
}
