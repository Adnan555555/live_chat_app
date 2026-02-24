// lib/widgets/message_bubble.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../const/app_constants.dart';
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
                child: message.type == MessageType.audio
                    ? _AudioBubble(message: message, isMe: isMe)
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
            _statusIcon(message.status),
            color: light
                ? Colors.white.withOpacity(0.85)
                : AppTheme.primary.withOpacity(0.6),
            size: 14,
          ),
        ],
      ],
    );
  }

  IconData _statusIcon(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending:
        return Icons.access_time_rounded;
      case MessageStatus.sent:
        return Icons.check_rounded;
      case MessageStatus.delivered:
      case MessageStatus.read:
        return Icons.done_all_rounded;
    }
  }
}

// ─── Audio Bubble ─────────────────────────────────────────────────────────────
class _AudioBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const _AudioBubble({required this.message, required this.isMe});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      final total = widget.message.audioDuration ?? 1;
      if (mounted) setState(() => _progress = pos.inSeconds / total);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _isPlaying = false;
        _progress = 0;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    // Decode base64 audio and play from temp file
    try {
      final bytes = base64Decode(widget.message.content);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audio_${widget.message.id}.m4a');
      await file.writeAsBytes(bytes);
      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.message.audioDuration ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final durationText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? AppTheme.primary.withOpacity(0.25)
                    : AppTheme.secondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: widget.isMe ? AppTheme.primary : AppTheme.secondary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Waveform + progress
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: (widget.isMe
                            ? AppTheme.primary
                            : AppTheme.secondary)
                        .withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(
                      widget.isMe ? AppTheme.primary : AppTheme.secondary,
                    ),
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '🎵 $durationText',
                    style: TextStyle(
                      color: widget.isMe
                          ? AppTheme.primary.withOpacity(0.7)
                          : AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('hh:mm a').format(widget.message.timestamp),
                    style: TextStyle(
                      color: widget.isMe
                          ? AppTheme.primary.withOpacity(0.6)
                          : AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
