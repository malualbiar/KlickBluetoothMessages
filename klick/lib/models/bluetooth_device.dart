enum DeviceType {
  klickTerminal,
  meshNode,
  beacon,
  smartphone,
}

enum MessageStatus {
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
}

class KlickChannel {
  final String id;
  final String name;
  final String frequency; // e.g. "CH-37 (2402 MHz)"
  final String description;
  final int activeNodes;
  final int unreadCount;

  const KlickChannel({
    required this.id,
    required this.name,
    required this.frequency,
    required this.description,
    this.activeNodes = 1,
    this.unreadCount = 0,
  });
}
