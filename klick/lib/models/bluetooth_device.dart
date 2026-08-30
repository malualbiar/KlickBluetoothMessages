import 'package:flutter/foundation.dart';

enum DeviceType {
  klickTerminal,
  meshNode,
  beacon,
  smartphone,
  pcTerminal,
}

enum ConnectionType {
  bluetooth,
  localP2p,
}

enum MessageStatus {
  queued,
  sending,
  sent,
  received,
  acknowledged,
}

enum MessageType {
  text,
  file,
  image,
}

class KlickDevice {
  final String id;
  final String name;
  final String macAddress;
  final int rssi; // e.g. -42 dBm
  final bool isConnected;
  final DeviceType deviceType;
  final DateTime lastSeen;
  final int unreadCount;
  final String? customStatus;
  /// True once this contact has ever accepted a Klick connection with us.
  /// Paired contacts skip the accept/reject modal on future encounters.
  final bool isPaired;
  final ConnectionType connectionType;
  final String? ipAddress;
  final int? port;

  const KlickDevice({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    this.isConnected = false,
    this.deviceType = DeviceType.klickTerminal,
    required this.lastSeen,
    this.unreadCount = 0,
    this.customStatus,
    this.isPaired = false,
    this.connectionType = ConnectionType.bluetooth,
    this.ipAddress,
    this.port,
  });

  KlickDevice copyWith({
    String? id,
    String? name,
    String? macAddress,
    int? rssi,
    bool? isConnected,
    DeviceType? deviceType,
    DateTime? lastSeen,
    int? unreadCount,
    String? customStatus,
    bool? isPaired,
    ConnectionType? connectionType,
    String? ipAddress,
    int? port,
  }) {
    return KlickDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      isConnected: isConnected ?? this.isConnected,
      deviceType: deviceType ?? this.deviceType,
      lastSeen: lastSeen ?? this.lastSeen,
      unreadCount: unreadCount ?? this.unreadCount,
      customStatus: customStatus ?? this.customStatus,
      isPaired: isPaired ?? this.isPaired,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
    );
  }

  int get signalBars {
    if (rssi >= -50) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  /// Returns true if this contact matches the peer by endpointId, macAddress, or callsign name.
  bool matchesPeer(String endpointId, [String? endpointName]) {
    if (id.isNotEmpty && id == endpointId) return true;
    if (macAddress.isNotEmpty && macAddress == endpointId) return true;
    if (endpointName != null && endpointName.trim().isNotEmpty) {
      final n1 = name.trim().toUpperCase();
      final n2 = endpointName.trim().toUpperCase();
      if (n1.isNotEmpty &&
          n2.isNotEmpty &&
          n1 != 'NEARBY CONTACT' &&
          n1 != 'NEARBY DEVICE' &&
          n1 != 'KLICK-USER' &&
          n1 == n2) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'macAddress': macAddress,
      'rssi': rssi,
      'isConnected': isConnected,
      'deviceType': deviceType.index,
      'lastSeen': lastSeen.toIso8601String(),
      'unreadCount': unreadCount,
      'customStatus': customStatus,
      'isPaired': isPaired,
      'connectionType': connectionType.index,
      'ipAddress': ipAddress,
      'port': port,
    };
  }

  factory KlickDevice.fromJson(Map<String, dynamic> json) {
    return KlickDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Nearby Contact',
      macAddress: json['macAddress'] as String? ?? '',
      rssi: json['rssi'] as int? ?? -60,
      isConnected: json['isConnected'] as bool? ?? false,
      deviceType: DeviceType.values[(json['deviceType'] as int? ?? 0).clamp(0, DeviceType.values.length - 1)],
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] as int? ?? 0,
      customStatus: json['customStatus'] as String?,
      isPaired: json['isPaired'] as bool? ?? false,
      connectionType: ConnectionType.values[(json['connectionType'] as int? ?? 0).clamp(0, ConnectionType.values.length - 1)],
      ipAddress: json['ipAddress'] as String?,
      port: json['port'] as int?,
    );
  }
}

class KlickMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isMe;
  final MessageType messageType;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final double? transferProgress; // 0.0 to 1.0
  final String? mimeType;

  const KlickMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.status,
    required this.isMe,
    this.messageType = MessageType.text,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.transferProgress,
    this.mimeType,
  });

  KlickMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isMe,
    MessageType? messageType,
    String? filePath,
    String? fileName,
    int? fileSize,
    double? transferProgress,
    String? mimeType,
  }) {
    return KlickMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isMe: isMe ?? this.isMe,
      messageType: messageType ?? this.messageType,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      transferProgress: transferProgress ?? this.transferProgress,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  bool get isImage {
    if (messageType == MessageType.image) return true;
    if (fileName != null) {
      final ext = fileName!.toLowerCase();
      return ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.gif') ||
          ext.endsWith('.webp') ||
          ext.endsWith('.bmp');
    }
    return false;
  }

  String get fileSizeFormatted {
    if (fileSize == null || fileSize! <= 0) return '';
    final bytes = fileSize!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get timeFormatted {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String get statusTag {
    if (!isMe) return '[RCVD]';
    switch (status) {
      case MessageStatus.queued:
        return '[QUEUED]';
      case MessageStatus.sending:
        return '[TX...]';
      case MessageStatus.sent:
        return '[SENT]';
      case MessageStatus.received:
        return '[RCVD]';
      case MessageStatus.acknowledged:
        return '[ACK]';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'isMe': isMe,
      'messageType': messageType.index,
      'filePath': filePath,
      'fileName': fileName,
      'fileSize': fileSize,
      'transferProgress': transferProgress,
      'mimeType': mimeType,
    };
  }

  factory KlickMessage.fromJson(Map<String, dynamic> json) {
    return KlickMessage(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: MessageStatus.values[(json['status'] as int? ?? 2).clamp(0, MessageStatus.values.length - 1)],
      isMe: json['isMe'] as bool? ?? false,
      messageType: MessageType.values[(json['messageType'] as int? ?? 0).clamp(0, MessageType.values.length - 1)],
      filePath: json['filePath'] as String?,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      transferProgress: (json['transferProgress'] as num?)?.toDouble(),
      mimeType: json['mimeType'] as String?,
    );
  }
}

class KlickConnectionRequest {
  final String endpointId;
  final String endpointName;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final DateTime timestamp;

  const KlickConnectionRequest({
    required this.endpointId,
    required this.endpointName,
    required this.onAccept,
    required this.onReject,
    required this.timestamp,
  });
}
