import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/app_text_styles.dart';
import '../common/user_avatar_with_frame.dart';

class ProfileHeader extends StatelessWidget {
  final String displayName;
  final int level;
  final String? imageUrl;
  final String? frameId;
  final VoidCallback onProfileTap;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.level,
    this.imageUrl,
    this.frameId,
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
    final hasFrame = frameId != null && frameId!.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo $displayName !',
                  style: AppTextStyles.headerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('level $level', style: AppTextStyles.headerLevel),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: hasFrame ? 14 : 24),
          child: GestureDetector(
            onTap: onProfileTap,
            child: UserAvatarWithFrame(
              avatarImage: activeProvider,
              frameId: frameId,
              size: hasFrame ? 68 : 50,
              placeholderIconSize: 30,
            ),
          ),
        ),
      ],
    );
  }
}
