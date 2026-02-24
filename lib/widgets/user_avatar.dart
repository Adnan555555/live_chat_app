// lib/widgets/user_avatar.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../const/app_constants.dart';
import '../model/user_model.dart';

class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double size;
  final bool showOnlineIndicator;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 48,
    this.showOnlineIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: user.photoUrl.isEmpty
                ? LinearGradient(
                    colors: _getAvatarColors(user.name),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: Border.all(color: AppTheme.divider, width: 1.5),
          ),
          child: ClipOval(
            child: user.photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: user.photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildInitials(),
                    errorWidget: (_, __, ___) => _buildInitials(),
                  )
                : _buildInitials(),
          ),
        ),
        if (showOnlineIndicator && user.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.27,
              height: size * 0.27,
              decoration: BoxDecoration(
                color: AppTheme.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials() {
    final initials = user.name.isNotEmpty
        ? user.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : '?';
    return Container(
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<Color> _getAvatarColors(String name) {
    final sets = [
      [const Color(0xFF00D4B4), const Color(0xFF007B6E)],
      [const Color(0xFF7B2FBE), const Color(0xFF4A1080)],
      [const Color(0xFFFF6B6B), const Color(0xFFCC4444)],
      [const Color(0xFF4ECDC4), const Color(0xFF2A8E87)],
      [const Color(0xFFFFBE0B), const Color(0xFFC48A00)],
      [const Color(0xFF3A86FF), const Color(0xFF1A5FBF)],
    ];
    final index = name.isNotEmpty ? name.codeUnitAt(0) % sets.length : 0;
    return sets[index];
  }
}
