// lib/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../const/app_constatnts.dart';
import '../model/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return _buildDeletedBubble();
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMe ? 48 : 0,
            right: isMe ? 0 : 48,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Reply preview
              if (message.replyToId != null && message.replyToContent != null)
                _buildReplyPreview(),

              // Bubble
              Container(
                decoration: BoxDecoration(
                  color: isMe ? AppTheme.myBubble : AppTheme.otherBubble,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: message.type == MessageType.image
                    ? _buildImageContent()
                    : _buildTextContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? AppTheme.primary : AppTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          _buildTimestamp(),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          child: CachedNetworkImage(
            imageUrl: message.content,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(
              width: 220,
              height: 220,
              color: AppTheme.surfaceLight,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.secondary, strokeWidth: 2),
              ),
            ),
            errorWidget: (ctx, url, err) => const Icon(Icons.error_outline),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildTimestamp(light: true),
          ),
        ),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.myBubble.withOpacity(0.5)
            : AppTheme.otherBubble.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
        border: Border(
          left: BorderSide(
            color: isMe ? AppTheme.primary : AppTheme.secondary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        message.replyToContent!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe ? AppTheme.primary.withOpacity(0.7) : AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDeletedBubble() {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.not_interested_rounded,
                color: AppTheme.textSecondary.withOpacity(0.5), size: 14),
            const SizedBox(width: 6),
            const Text(
              'This message was deleted',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp({bool light = false}) {
    final timeText = DateFormat('hh:mm a').format(message.timestamp);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeText,
          style: TextStyle(
            color: light
                ? Colors.white.withOpacity(0.85)
                : isMe
                ? AppTheme.primary.withOpacity(0.6)
                : AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            _getStatusIcon(message.status),
            color: light
                ? Colors.white.withOpacity(0.85)
                : AppTheme.primary.withOpacity(0.6),
            size: 14,
          ),
        ],
      ],
    );
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time_rounded;
      case MessageStatus.sent:
        return Icons.check_rounded;
      case MessageStatus.delivered:
        return Icons.done_all_rounded;
      case MessageStatus.read:
        return Icons.done_all_rounded;
    }
  }
}