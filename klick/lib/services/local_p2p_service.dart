import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/bluetooth_device.dart';
import 'bluetooth_service.dart';

typedef FileTransferProgressCallback = void Function(
  String endpointId,
  String fileId,
  double progress,
  int bytesTransferred,
  int totalBytes,
);

typedef FileReceivedCallback = void Function(
  String endpointId,
  String fileId,
  String fileName,
  String localFilePath,
  int fileSize,
);

class LocalP2pService {
  static const int udpDiscoveryPort = 9648;
  static const int defaultTcpPort = 9649;
  static const int chunkSizeBytes = 64 * 1024; // 64 KB per chunk

  // Callbacks matching BluetoothService signature
  DeviceFoundCallback? onDeviceFound;
  DeviceLostCallback? onDeviceLost;
  ConnectionCallback? onConnected;
  DisconnectCallback? onDisconnected;
  MessageReceivedCallback? onMessageReceived;
  ConnectionRequestCallback? onConnectionRequest;
  FileTransferProgressCallback? onFileProgress;
  FileReceivedCallback? onFileReceived;

  // Local identity
  late final String localNodeId;
  String _localCallsign = 'KLICK-NODE';
  int _tcpPort = defaultTcpPort;

  // Sockets & Network State
  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Timer? _beaconTimer;
  bool _isDiscovering = false;

  // Active Peer Sockets: endpointId -> Socket
  final Map<String, Socket> _activeSockets = {};
  final Map<String, KlickDevice> _knownPeers = {}; // endpointId -> KlickDevice

  // Inbound File Assembly: fileId -> InboundFileState
  final Map<String, _InboundFileState> _inboundFiles = {};

  LocalP2pService() {
    localNodeId = 'node_${DateTime.now().millisecondsSinceEpoch % 1000000}';
  }

  /// Initialize TCP server and start accepting connections
  Future<void> initServer({int port = defaultTcpPort}) async {
    if (_tcpServer != null) return;
    _tcpPort = port;

    try {
      _tcpServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        _tcpPort,
        shared: true,
      );
      debugPrint('[LocalP2P] TCP Server listening on port $_tcpPort');

      _tcpServer!.listen(
        _handleIncomingSocket,
        onError: (err) => debugPrint('[LocalP2P] Server socket error: $err'),
        onDone: () => debugPrint('[LocalP2P] Server socket closed'),
      );
    } catch (e) {
      debugPrint('[LocalP2P] Failed to bind TCP server on port $_tcpPort: $e');
    }
  }

  bool _isDisposed = false;

  /// Start UDP discovery beacon broadcasting & listening on local subnet
  Future<void> startDiscovery(String localCallsign) async {
    _localCallsign = localCallsign;
    if (_isDisposed || _isDiscovering) return;
    _isDiscovering = true;

    await initServer(port: _tcpPort);
    if (_isDisposed || !_isDiscovering) return;

    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpDiscoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
      if (_isDisposed || !_isDiscovering) {
        _udpSocket?.close();
        _udpSocket = null;
        return;
      }
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.multicastLoopback = false;

      debugPrint('[LocalP2P] UDP Discovery bound to port $udpDiscoveryPort');

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            _handleIncomingBeacon(datagram);
          }
        }
      });

      // Broadcast beacon immediately and every 2.5 seconds
      _broadcastBeacon();
      _beaconTimer?.cancel();
      _beaconTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        _broadcastBeacon();
      });
    } catch (e) {
      debugPrint('[LocalP2P] UDP bind error: $e');
    }
  }

  /// Stop discovery beaconing
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
  }

  /// Broadcast presence beacon over local subnet
  void _broadcastBeacon() {
    if (_udpSocket == null) return;

    final beaconData = jsonEncode({
      'proto': 'KLICK_P2P_V1',
      'nodeId': localNodeId,
      'callsign': _localCallsign,
      'port': _tcpPort,
      'deviceType': Platform.isWindows ? 'pcTerminal' : 'smartphone',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final bytes = utf8.encode(beaconData);

    try {
      _udpSocket!.send(
        bytes,
        InternetAddress('255.255.255.255'),
        udpDiscoveryPort,
      );
    } catch (e) {
      // Subnet broadcast fallback
    }
  }

  /// Process incoming UDP beacon from a nearby peer
  void _handleIncomingBeacon(Datagram datagram) {
    try {
      final msg = utf8.decode(datagram.data);
      final json = jsonDecode(msg) as Map<String, dynamic>;

      if (json['proto'] != 'KLICK_P2P_V1') return;

      final senderNodeId = json['nodeId'] as String? ?? '';
      if (senderNodeId == localNodeId) return; // Skip own beacon

      final senderCallsign = json['callsign'] as String? ?? 'Nearby Contact';
      final senderPort = json['port'] as int? ?? defaultTcpPort;
      final senderIp = datagram.address.address;
      final rawDevType = json['deviceType'] as String? ?? 'smartphone';

      final endpointId = 'p2p_${senderIp}_$senderPort';

      final devType = rawDevType == 'pcTerminal'
          ? DeviceType.pcTerminal
          : DeviceType.smartphone;

      final peerDevice = KlickDevice(
        id: endpointId,
        name: senderCallsign,
        macAddress: senderNodeId,
        rssi: -45, // Strong local LAN signal
        isConnected: _activeSockets.containsKey(endpointId),
        deviceType: devType,
        lastSeen: DateTime.now(),
        connectionType: ConnectionType.localP2p,
        ipAddress: senderIp,
        port: senderPort,
      );

      _knownPeers[endpointId] = peerDevice;
      onDeviceFound?.call(peerDevice);
    } catch (e) {
      // Ignored malformed beacon
    }
  }

  /// Connect to a discovered peer via direct TCP socket
  Future<bool> connect(String endpointId, String localCallsign) async {
    _localCallsign = localCallsign;
    final peer = _knownPeers[endpointId];
    if (peer == null || peer.ipAddress == null || peer.port == null) {
      debugPrint('[LocalP2P] Cannot connect: unknown peer $endpointId');
      return false;
    }

    try {
      debugPrint('[LocalP2P] Connecting TCP to ${peer.ipAddress}:${peer.port} ($endpointId)...');
      final socket = await Socket.connect(
        peer.ipAddress!,
        peer.port!,
        timeout: const Duration(seconds: 5),
      );

      _setupSocket(endpointId, socket, isClient: true);

      // Send handshake
      _sendFrame(socket, {
        'type': 'HANDSHAKE',
        'nodeId': localNodeId,
        'callsign': localCallsign,
        'endpointId': endpointId,
      });

      return true;
    } catch (e) {
      debugPrint('[LocalP2P] Connection failed to $endpointId: $e');
      return false;
    }
  }

  /// Disconnect socket from peer
  Future<void> disconnect(String endpointId) async {
    final socket = _activeSockets.remove(endpointId);
    if (socket != null) {
      try {
        await socket.flush();
        await socket.close();
      } catch (_) {}
      onDisconnected?.call(endpointId);
    }
  }

  /// Handle incoming TCP connection from a peer
  void _handleIncomingSocket(Socket socket) {
    final remoteIp = socket.remoteAddress.address;
    final tempId = 'p2p_${remoteIp}_${socket.remotePort}';
    debugPrint('[LocalP2P] Incoming connection from $remoteIp:${socket.remotePort}');

    _setupSocket(tempId, socket, isClient: false);
  }

  /// Wire up packet parser and listeners on a Socket
  void _setupSocket(String initialEndpointId, Socket socket, {required bool isClient}) {
    String currentEndpointId = initialEndpointId;
    _activeSockets[currentEndpointId] = socket;

    final buffer = BytesBuilder(copy: false);

    socket.listen(
      (Uint8List chunk) async {
        buffer.add(chunk);
        await _processFrameBuffer(currentEndpointId, socket, buffer, (newId) {
          if (newId != currentEndpointId) {
            _activeSockets.remove(currentEndpointId);
            currentEndpointId = newId;
            _activeSockets[currentEndpointId] = socket;
          }
        });
      },
      onError: (err) {
        debugPrint('[LocalP2P] Socket error on $currentEndpointId: $err');
        _activeSockets.remove(currentEndpointId);
        onDisconnected?.call(currentEndpointId);
      },
      onDone: () {
        debugPrint('[LocalP2P] Socket closed for $currentEndpointId');
        _activeSockets.remove(currentEndpointId);
        onDisconnected?.call(currentEndpointId);
      },
      cancelOnError: true,
    );
  }

  /// Parse framed length-prefixed binary packets
  Future<void> _processFrameBuffer(
    String endpointId,
    Socket socket,
    BytesBuilder buffer,
    void Function(String newId) onIdResolved,
  ) async {
    final rawBytes = buffer.toBytes();
    int offset = 0;

    while (offset + 4 <= rawBytes.length) {
      final frameLength = ByteData.sublistView(rawBytes, offset, offset + 4).getUint32(0);
      if (offset + 4 + frameLength > rawBytes.length) {
        break; // Wait for complete frame
      }

      final frameData = Uint8List.sublistView(rawBytes, offset + 4, offset + 4 + frameLength);
      offset += 4 + frameLength;

      await _handleFrame(endpointId, socket, frameData, onIdResolved);
    }

    buffer.clear();
    if (offset < rawBytes.length) {
      buffer.add(Uint8List.sublistView(rawBytes, offset));
    }
  }

  /// Handle an extracted frame payload
  Future<void> _handleFrame(
    String endpointId,
    Socket socket,
    Uint8List data,
    void Function(String newId) onIdResolved,
  ) async {
    if (data.isEmpty) return;

    final magic = data[0];

    // Magic 0x01: JSON Control / Text Packet
    if (magic == 0x01) {
      try {
        final jsonString = utf8.decode(data.sublist(1));
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        final type = map['type'] as String? ?? '';

        switch (type) {
          case 'HANDSHAKE':
            final senderCallsign = map['callsign'] as String? ?? 'Contact';
            final senderNode = map['nodeId'] as String? ?? '';
            final resolvedId = 'p2p_${socket.remoteAddress.address}_$_tcpPort';
            debugPrint('[LocalP2P] Handshake received from $senderCallsign ($senderNode)');
            onIdResolved(resolvedId);

            // Notify connected
            onConnected?.call(resolvedId, senderCallsign);
            break;

          case 'MSG':
            final text = map['text'] as String? ?? '';
            onMessageReceived?.call(endpointId, text);
            break;

          case 'FILE_META':
            final fileId = map['fileId'] as String;
            final fileName = map['fileName'] as String;
            final fileSize = map['fileSize'] as int;
            await _initInboundFile(endpointId, fileId, fileName, fileSize);
            break;

          case 'FILE_ACK':
            final fileId = map['fileId'] as String;
            debugPrint('[LocalP2P] Peer acknowledged file transfer: $fileId');
            break;
        }
      } catch (e) {
        debugPrint('[LocalP2P] JSON frame decode error: $e');
      }
      return;
    }

    // Magic 0x02: Binary File Chunk
    // Format: [1 byte magic=0x02][36 bytes fileId][8 bytes offset][raw chunk bytes]
    if (magic == 0x02 && data.length > 45) {
      final fileId = utf8.decode(data.sublist(1, 37)).trim();
      final chunkOffset = ByteData.sublistView(data, 37, 45).getUint64(0);
      final chunkBytes = data.sublist(45);

      await _writeInboundChunk(endpointId, fileId, chunkOffset, chunkBytes);
    }
  }

  /// Send a text message over TCP socket
  Future<bool> sendMessage(String endpointId, String text) async {
    final socket = _activeSockets[endpointId];
    if (socket == null) {
      debugPrint('[LocalP2P] Cannot send message: socket not connected for $endpointId');
      return false;
    }

    try {
      _sendFrame(socket, {
        'type': 'MSG',
        'id': 'p2p_msg_${DateTime.now().millisecondsSinceEpoch}',
        'text': text,
        'senderName': _localCallsign,
      });
      return true;
    } catch (e) {
      debugPrint('[LocalP2P] Send message failed: $e');
      return false;
    }
  }

  /// High-speed chunked file streaming over TCP socket
  Future<bool> sendFile({
    required String endpointId,
    required File file,
    required String fileId,
  }) async {
    final socket = _activeSockets[endpointId];
    if (socket == null) {
      debugPrint('[LocalP2P] Cannot send file: socket not connected for $endpointId');
      return false;
    }

    final fileSize = await file.length();
    final fileName = p.basename(file.path);

    debugPrint('[LocalP2P] Starting file stream: $fileName ($fileSize bytes) to $endpointId');

    // 1. Send FILE_META header
    _sendFrame(socket, {
      'type': 'FILE_META',
      'fileId': fileId,
      'fileName': fileName,
      'fileSize': fileSize,
    });

    // 2. Stream 64 KB binary chunks
    final stream = file.openRead();
    int bytesSent = 0;

    try {
      final fileIdPadded = fileId.padRight(36).substring(0, 36);
      final fileIdBytes = utf8.encode(fileIdPadded);

      await for (final chunk in stream) {
        final chunkLen = chunk.length;
        final packet = BytesBuilder(copy: false);

        // Magic 0x02 (Binary Chunk)
        packet.addByte(0x02);
        packet.add(fileIdBytes);

        // 8-byte uint64 chunk offset
        final offsetHeader = ByteData(8)..setUint64(0, bytesSent);
        packet.add(offsetHeader.buffer.asUint8List());

        // Chunk binary payload
        packet.add(chunk);

        final frameBytes = packet.toBytes();

        // 4-byte length prefix header
        final lengthHeader = ByteData(4)..setUint32(0, frameBytes.length);
        socket.add(lengthHeader.buffer.asUint8List());
        socket.add(frameBytes);

        bytesSent += chunkLen;
        final progress = (bytesSent / fileSize).clamp(0.0, 1.0);

        onFileProgress?.call(endpointId, fileId, progress, bytesSent, fileSize);

        // Yield to event loop to avoid socket buffer choking
        if (bytesSent % (256 * 1024) == 0) {
          await socket.flush();
        }
      }

      await socket.flush();
      debugPrint('[LocalP2P] Completed file stream: $fileName to $endpointId');
      return true;
    } catch (e) {
      debugPrint('[LocalP2P] File stream error: $e');
      return false;
    }
  }

  /// Prepare target file on disk for inbound chunk assembly
  Future<void> _initInboundFile(
    String endpointId,
    String fileId,
    String fileName,
    int fileSize,
  ) async {
    Directory saveDir;
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      saveDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      saveDir = await getApplicationDocumentsDirectory();
    }

    final klickDir = Directory(p.join(saveDir.path, 'Klick'));
    if (!klickDir.existsSync()) {
      klickDir.createSync(recursive: true);
    }

    final targetPath = p.join(klickDir.path, fileName);
    final tempPath = p.join(klickDir.path, '$fileId.klick_tmp');
    final tempFile = File(tempPath);
    if (tempFile.existsSync()) tempFile.deleteSync();

    final sink = tempFile.openWrite(mode: FileMode.writeOnly);

    _inboundFiles[fileId] = _InboundFileState(
      fileId: fileId,
      fileName: fileName,
      fileSize: fileSize,
      targetPath: targetPath,
      tempPath: tempPath,
      sink: sink,
      bytesReceived: 0,
    );

    debugPrint('[LocalP2P] Receiving file: $fileName ($fileSize bytes) -> $tempPath');
  }

  /// Write an incoming binary chunk to disk
  Future<void> _writeInboundChunk(
    String endpointId,
    String fileId,
    int offset,
    List<int> chunkBytes,
  ) async {
    final state = _inboundFiles[fileId];
    if (state == null) return;

    state.sink.add(chunkBytes);
    state.bytesReceived += chunkBytes.length;

    final progress = (state.bytesReceived / state.fileSize).clamp(0.0, 1.0);
    onFileProgress?.call(endpointId, fileId, progress, state.bytesReceived, state.fileSize);

    if (state.bytesReceived >= state.fileSize) {
      await state.sink.flush();
      await state.sink.close();

      final tempFile = File(state.tempPath);
      final finalFile = File(state.targetPath);
      if (finalFile.existsSync()) finalFile.deleteSync();
      await tempFile.rename(state.targetPath);

      _inboundFiles.remove(fileId);
      debugPrint('[LocalP2P] File saved successfully: ${state.targetPath}');

      onFileReceived?.call(
        endpointId,
        fileId,
        state.fileName,
        state.targetPath,
        state.fileSize,
      );

      // Send ACK back to sender
      final socket = _activeSockets[endpointId];
      if (socket != null) {
        _sendFrame(socket, {
          'type': 'FILE_ACK',
          'fileId': fileId,
          'status': 'OK',
        });
      }
    }
  }

  /// Send a 4-byte length-prefixed JSON frame
  void _sendFrame(Socket socket, Map<String, dynamic> jsonMap) {
    final jsonBytes = utf8.encode(jsonEncode(jsonMap));
    final packet = Uint8List(1 + jsonBytes.length);
    packet[0] = 0x01; // Magic 0x01 (JSON Control)
    packet.setRange(1, packet.length, jsonBytes);

    final lengthHeader = ByteData(4)..setUint32(0, packet.length);
    socket.add(lengthHeader.buffer.asUint8List());
    socket.add(packet);
  }

  void dispose() {
    _isDisposed = true;
    _isDiscovering = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
    for (final socket in _activeSockets.values) {
      socket.destroy();
    }
    _activeSockets.clear();
    _tcpServer?.close();
    _tcpServer = null;
  }
}

class _InboundFileState {
  final String fileId;
  final String fileName;
  final int fileSize;
  final String targetPath;
  final String tempPath;
  final IOSink sink;
  int bytesReceived;

  _InboundFileState({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
    required this.targetPath,
    required this.tempPath,
    required this.sink,
    required this.bytesReceived,
  });
}
