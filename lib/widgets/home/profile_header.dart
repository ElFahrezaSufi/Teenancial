import 'dart:io';
import 'package:flutter/material.dart';
import '../../screens/profile_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  final String displayName;
  final int level;
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback onProfileTap;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.level,
    this.imageFile,
    this.imageUrl,
    required this.onProfileTap,
  });

  ImageProvider? _getAvatarProvider() {
    final activeFile = imageFile ?? ProfileScreen.profileImage;
    if (activeFile != null) {
      return FileImage(activeFile);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      return NetworkImage(imageUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeProvider = _getAvatarProvider();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Halo $displayName !', style: AppTextStyles.headerName),
              Text('level $level', style: AppTextStyles.headerLevel),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: inputBg,
                shape: BoxShape.circle,
                border: Border.all(color: primaryGreen, width: 2),
                image: activeProvider != null
                    ? DecorationImage(
                        image: activeProvider,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: activeProvider == null
                  ? const Icon(Icons.person, color: primaryGreen, size: 30)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
