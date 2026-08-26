import 'package:flutter/foundation.dart';

enum DeviceType {
  klickTerminal,
  meshNode,
  beacon,
  smartphone,
}

enum MessageStatus {
  queued,
  sending,
  sent,
  received,
  acknowledged,
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
    );
  }

  int get signalBars {
    if (rssi >= -50) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -80) return 2;
    return 1;
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

  const KlickMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.status,
    required this.isMe,
  });

  KlickMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isMe,
  }) {
    return KlickMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isMe: isMe ?? this.isMe,
    );
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
