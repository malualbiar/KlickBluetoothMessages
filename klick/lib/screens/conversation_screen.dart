import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../controllers/klick_controller.dart';
import '../models/bluetooth_device.dart';
import '../theme/bit_mechanical_theme.dart';

class ConversationScreen extends StatefulWidget {
  final KlickController controller;
  final KlickDevice device;

  const ConversationScreen({
    super.key,
    required this.controller,
    required this.device,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _cursorVisible = true;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() => _cursorVisible = !_cursorVisible);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(covariant ConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentDevice = widget.controller.devices.firstWhere(
      (d) => d.matchesPeer(widget.device.id, widget.device.name),
      orElse: () => widget.device,
    );
    final bgColor = BitMechanicalTheme.getLcdBackground(widget.controller.lcdTheme);
    final inkColor = BitMechanicalTheme.getLcdInk(widget.controller.lcdTheme);
    final messages = widget.controller.conversationMessages[currentDevice.id] ??
        widget.controller.conversationMessages[widget.device.id] ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: inkColor.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.controller.goBack,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        color: inkColor,
                        child: Text(
                          '◄',
                          style: BitMechanicalTheme.statusPixel(
                            color: bgColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        currentDevice.name,
                        overflow: TextOverflow.ellipsis,
                        style: BitMechanicalTheme.bodyLg(
                          color: inkColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (currentDevice.connectionType == ConnectionType.localP2p) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: inkColor.withValues(alpha: 0.15),
                          border: Border.all(color: inkColor, width: 0.8),
                        ),
                        child: Text(
                          'P2P',
                          style: BitMechanicalTheme.statusPixel(
                            color: inkColor,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bluetooth / Network Status
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: currentDevice.isConnected ? inkColor : Colors.transparent,
                      border: Border.all(color: inkColor, width: 1.2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    currentDevice.isConnected ? 'ONLINE' : 'OFFLINE',
                    style: BitMechanicalTheme.statusPixel(
                      color: currentDevice.isConnected
                          ? inkColor
                          : inkColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Message Thread
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet.\nType or tap [+ FILE] to send.',
                    textAlign: TextAlign.center,
                    style: BitMechanicalTheme.bodyMd(
                      color: inkColor.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _buildMessageBubble(msg, inkColor, bgColor);
                  },
                ),
        ),

        // Message Input Box or Locked Notice
        if (!currentDevice.isPaired && !currentDevice.isConnected)
          Container(
            decoration: BoxDecoration(
              color: inkColor.withValues(alpha: 0.08),
              border: Border.all(
                  color: inkColor.withValues(alpha: 0.4), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 13,
                  color: inkColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'WAITING FOR ${currentDevice.name.toUpperCase()} TO ACCEPT KLICK',
                    overflow: TextOverflow.ellipsis,
                    style: BitMechanicalTheme.statusPixel(
                      color: inkColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: inkColor.withValues(alpha: 0.08),
              border: Border.all(color: inkColor, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                // Attach File Button
                GestureDetector(
                  onTap: widget.controller.pickAndSendFile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: inkColor.withValues(alpha: 0.15),
                      border: Border.all(color: inkColor, width: 1),
                    ),
                    child: Text(
                      '+ FILE',
                      style: BitMechanicalTheme.statusPixel(
                        color: inkColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller.textInputController,
                    autofocus: true,
                    style: BitMechanicalTheme.bodyMd(
                      color: inkColor,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: currentDevice.isConnected
                          ? 'Type message...'
                          : 'Type message (queued offline)...',
                      hintStyle: BitMechanicalTheme.bodyMd(
                        color: inkColor.withValues(alpha: 0.4),
                      ),
                    ),
                    onSubmitted: (_) {
                      widget.controller.sendMessageFromInput();
                    },
                  ),
                ),
                if (_cursorVisible)
                  Text(
                    '█',
                    style: TextStyle(
                      color: inkColor,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    widget.controller.sendMessageFromInput();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    color: inkColor,
                    child: Text(
                      'SEND',
                      style: BitMechanicalTheme.statusPixel(
                        color: bgColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(KlickMessage msg, Color inkColor, Color bgColor) {
    if (msg.messageType == MessageType.file || msg.messageType == MessageType.image) {
      return _buildFileBubble(msg, inkColor, bgColor);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.5),
      child: Column(
        crossAxisAlignment:
            msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message Content
          Container(
            constraints: const BoxConstraints(maxWidth: 210),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: msg.isMe ? inkColor : Colors.transparent,
              border: Border.all(color: inkColor, width: 1),
            ),
            child: Text(
              msg.text,
              style: BitMechanicalTheme.bodyMd(
                color: msg.isMe ? bgColor : inkColor,
                fontWeight: msg.isMe ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 1),

          // Timestamp
          Text(
            msg.timeFormatted,
            style: BitMechanicalTheme.statusPixel(
              color: inkColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileBubble(KlickMessage msg, Color inkColor, Color bgColor) {
    final isSendingOrReceiving = msg.status == MessageStatus.sending ||
        (msg.transferProgress != null && msg.transferProgress! < 1.0);
    final progressPct = ((msg.transferProgress ??
            (msg.status == MessageStatus.sent || msg.status == MessageStatus.received ? 1.0 : 0.0)) *
            100)
        .toInt();

    final hasFile = msg.filePath != null && File(msg.filePath!).existsSync();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (msg.filePath != null) {
                widget.controller.openLocalFile(msg.filePath!);
              }
            },
            child: Container(
              constraints: const BoxConstraints(maxWidth: 230),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: msg.isMe ? inkColor.withValues(alpha: 0.88) : inkColor.withValues(alpha: 0.08),
                border: Border.all(color: inkColor, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File Title Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        msg.isImage ? Icons.image : Icons.insert_drive_file,
                        size: 14,
                        color: msg.isMe ? bgColor : inkColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          msg.fileName ?? msg.text,
                          overflow: TextOverflow.ellipsis,
                          style: BitMechanicalTheme.headlineMono(
                            color: msg.isMe ? bgColor : inkColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Image preview thumbnail if available
                  if (msg.isImage && hasFile) ...[
                    Container(
                      height: 90,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: msg.isMe ? bgColor.withValues(alpha: 0.4) : inkColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Image.file(
                        File(msg.filePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(Icons.broken_image, size: 20, color: msg.isMe ? bgColor : inkColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // Size & Action Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        msg.fileSizeFormatted,
                        style: BitMechanicalTheme.statusPixel(
                          color: msg.isMe ? bgColor.withValues(alpha: 0.8) : inkColor.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        isSendingOrReceiving
                            ? 'TX: $progressPct%'
                            : (msg.isMe ? 'SENT' : (hasFile ? 'OPEN ↗' : 'SAVED')),
                        style: BitMechanicalTheme.statusPixel(
                          color: msg.isMe ? bgColor : inkColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  // Progress Bar if in-flight
                  if (isSendingOrReceiving) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: msg.transferProgress ?? 0.0,
                        backgroundColor: (msg.isMe ? bgColor : inkColor).withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(msg.isMe ? bgColor : inkColor),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 1),

          // Timestamp
          Text(
            msg.timeFormatted,
            style: BitMechanicalTheme.statusPixel(
              color: inkColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
