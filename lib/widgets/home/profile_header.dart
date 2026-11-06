import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  final String displayName;
  final int level;
  final String? imageUrl;
  final VoidCallback onProfileTap;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.level,
    this.imageUrl,
    required this.onProfileTap,
  });

  ImageProvider? _getAvatarProvider() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImageProvider(imageUrl!);
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
