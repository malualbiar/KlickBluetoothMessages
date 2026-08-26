import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bluetooth_device.dart';

typedef DeviceFoundCallback = void Function(KlickDevice device);
typedef DeviceLostCallback = void Function(String endpointId);
typedef ConnectionCallback = void Function(String endpointId, String name);
typedef DisconnectCallback = void Function(String endpointId);
typedef MessageReceivedCallback = void Function(String endpointId, String message);

abstract class BluetoothService {
  Future<bool> requestPermissions();
  Future<void> startAdvertising(String localName);
  Future<void> stopAdvertising();
  Future<void> startDiscovery(String localName);
  Future<void> stopDiscovery();
  Future<void> connect(String endpointId, String localName);
  Future<void> disconnect(String endpointId);
  Future<bool> sendMessage(String endpointId, String text);

  DeviceFoundCallback? onDeviceFound;
  DeviceLostCallback? onDeviceLost;
  ConnectionCallback? onConnected;
  DisconnectCallback? onDisconnected;
  MessageReceivedCallback? onMessageReceived;

  void dispose();
}

class NearbyBluetoothService implements BluetoothService {
  static const Strategy _strategy = Strategy.P2P_STAR;
  static const String _serviceId = 'com.klick.bluetooth.messages';

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

  final Map<String, String> _connectedEndpoints = {};
  bool _isAdvertising = false;
  bool _isDiscovering = false;

  bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<bool> requestPermissions() async {
    if (!isSupportedPlatform) return true;

    try {
      final permissions = <Permission>[
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
      ];

      final statuses = await permissions.request();
      bool granted = true;
      statuses.forEach((perm, status) {
        if (perm != Permission.nearbyWifiDevices &&
            perm != Permission.bluetooth &&
            status == PermissionStatus.permanentlyDenied) {
          granted = false;
        }
      });
      return granted;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
  }

  @override
  Future<void> startAdvertising(String localName) async {
    if (!isSupportedPlatform) return;
    if (_isAdvertising) return;

    try {
      final success = await Nearby().startAdvertising(
        localName,
        _strategy,
        onConnectionInitiated: (endpointId, connectionInfo) async {
          debugPrint('Connection initiated from: ${connectionInfo.endpointName}');
          await Nearby().acceptConnection(
            endpointId,
            onPayLoadRecieved: (epId, payload) {
              if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                final message = utf8.decode(payload.bytes!);
                onMessageReceived?.call(epId, message);
              }
            },
          );
        },
        onConnectionResult: (endpointId, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpoints[endpointId] = localName;
            onConnected?.call(endpointId, localName);
          } else {
            _connectedEndpoints.remove(endpointId);
            onDisconnected?.call(endpointId);
          }
        },
        onDisconnected: (endpointId) {
          _connectedEndpoints.remove(endpointId);
          onDisconnected?.call(endpointId);
        },
        serviceId: _serviceId,
      );

      _isAdvertising = success;
      debugPrint('Nearby advertising started: $success');
    } catch (e) {
      debugPrint('Error starting advertising: $e');
    }
  }

  @override
  Future<void> stopAdvertising() async {
    if (!isSupportedPlatform) return;
    try {
      await Nearby().stopAdvertising();
      _isAdvertising = false;
    } catch (e) {
      debugPrint('Error stopping advertising: $e');
    }
  }

  @override
  Future<void> startDiscovery(String localName) async {
    if (!isSupportedPlatform) return;
    if (_isDiscovering) return;

    try {
      final success = await Nearby().startDiscovery(
        localName,
        _strategy,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          debugPrint('Found nearby device: $endpointName ($endpointId)');
          final device = KlickDevice(
            id: endpointId,
            name: endpointName.isNotEmpty ? endpointName : 'Nearby Device',
            macAddress: endpointId,
            rssi: -55,
            isConnected: false,
            deviceType: DeviceType.smartphone,
            lastSeen: DateTime.now(),
          );
          onDeviceFound?.call(device);
        },
        onEndpointLost: (endpointId) {
          debugPrint('Lost nearby device: $endpointId');
          onDeviceLost?.call(endpointId ?? '');
        },
        serviceId: _serviceId,
      );

      _isDiscovering = success;
      debugPrint('Nearby discovery started: $success');
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!isSupportedPlatform) return;
    try {
      await Nearby().stopDiscovery();
      _isDiscovering = false;
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }

  @override
  Future<void> connect(String endpointId, String localName) async {
    if (!isSupportedPlatform) return;

    try {
      await Nearby().requestConnection(
        localName,
        endpointId,
        onConnectionInitiated: (epId, connectionInfo) async {
          await Nearby().acceptConnection(
            epId,
            onPayLoadRecieved: (id, payload) {
              if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                final message = utf8.decode(payload.bytes!);
                onMessageReceived?.call(id, message);
              }
            },
          );
        },
        onConnectionResult: (epId, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpoints[epId] = endpointId;
            onConnected?.call(epId, endpointId);
          } else {
            _connectedEndpoints.remove(epId);
            onDisconnected?.call(epId);
          }
        },
        onDisconnected: (epId) {
          _connectedEndpoints.remove(epId);
          onDisconnected?.call(epId);
        },
      );
    } catch (e) {
      debugPrint('Error connecting to endpoint $endpointId: $e');
    }
  }

  @override
  Future<void> disconnect(String endpointId) async {
    if (!isSupportedPlatform) return;
    try {
      await Nearby().disconnectFromEndpoint(endpointId);
      _connectedEndpoints.remove(endpointId);
      onDisconnected?.call(endpointId);
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  @override
  Future<bool> sendMessage(String endpointId, String text) async {
    if (!isSupportedPlatform) return true;

    try {
      final bytes = utf8.encode(text);
      await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      debugPrint('Error sending message to $endpointId: $e');
      return false;
    }
  }

  @override
  void dispose() {
    if (isSupportedPlatform) {
      stopAdvertising();
      stopDiscovery();
      Nearby().stopAllEndpoints();
    }
  }
}
