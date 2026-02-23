// lib/utils/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../const/app_constatnts.dart';
import '../model/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _buildDeletedBubble();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: EdgeInsets.only(
            top: 2, bottom: 2,
            left: isMe ? 48 : 0,
            right: isMe ? 0 : 48,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.replyToId != null) _buildReplyPreview(),
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
                child: _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent();
      case MessageType.audio:
        return _buildAudioContent();
      case MessageType.file:
        return _buildFileContent(context);
      default:
        return _buildTextContent();
    }
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
            placeholder: (_, __) => Container(
              width: 220,
              height: 220,
              color: AppTheme.surfaceLight,
              child: const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.secondary, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) =>
            const Icon(Icons.error_outline, color: AppTheme.error),
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

  // ✅ Audio bubble with play button
  Widget _buildAudioContent() {
    final duration = message.fileSize ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final durationText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(message.content)),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.secondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: isMe ? AppTheme.primary : AppTheme.secondary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform visual
              Row(
                children: List.generate(
                  12,
                      (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 3,
                    height: (i % 3 == 0 ? 18 : i % 3 == 1 ? 12 : 8)
                        .toDouble(),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppTheme.primary.withOpacity(0.5)
                          : AppTheme.secondary.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '🎵 $durationText',
                    style: TextStyle(
                      color: isMe
                          ? AppTheme.primary.withOpacity(0.7)
                          : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTimestamp(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ File bubble with download button
  Widget _buildFileContent(BuildContext context) {
    final fileName = message.fileName ?? 'File';
    final fileSize = message.fileSize ?? 0;
    final fileSizeStr = fileSize > 1024 * 1024
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : fileSize > 1024
        ? '${(fileSize / 1024).toStringAsFixed(1)} KB'
        : '$fileSize B';

    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.parse(message.content);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getFileIcon(ext),
                    color: isMe ? AppTheme.primary : AppTheme.secondary,
                    size: 22,
                  ),
                  Text(
                    ext.length > 4 ? ext.substring(0, 4) : ext,
                    style: TextStyle(
                      color: isMe ? AppTheme.primary : AppTheme.secondary,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isMe ? AppTheme.primary : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        fileSizeStr,
                        style: TextStyle(
                          color: isMe
                              ? AppTheme.primary.withOpacity(0.6)
                              : AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTimestamp(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: isMe ? AppTheme.primary : AppTheme.secondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'zip':
      case 'rar':
        return Icons.folder_zip_rounded;
      case 'mp3':
      case 'wav':
        return Icons.audio_file_rounded;
      case 'mp4':
      case 'mov':
        return Icons.video_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
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
        message.replyToContent ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe
              ? AppTheme.primary.withOpacity(0.7)
              : AppTheme.textSecondary,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('hh:mm a').format(message.timestamp),
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