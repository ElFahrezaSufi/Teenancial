import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/app_routes.dart';
import '../../data/feen_catalog.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/custom_card.dart';
import '../common/user_avatar_with_frame.dart';
import 'feen_avatar.dart';

Future<void> showFeenUnlockDialog(
  BuildContext context, {
  required int level,
  required List<FeenAccessory> unlocked,
}) {
  final frameItems = unlocked.where((a) => a.slot == FeenSlot.frame).toList();
  final bool onlyFrames =
      unlocked.isNotEmpty && frameItems.length == unlocked.length;
  final bool hasFrame = frameItems.isNotEmpty;

  final String headerLabel = unlocked.length == 1
      ? (onlyFrames ? 'Bingkai profil baru terbuka:' : 'Aksesoris baru terbuka:')
      : '${unlocked.length} hadiah baru terbuka:';

  final String ctaLabel = onlyFrames
      ? 'Pasang Bingkai'
      : (hasFrame ? 'Lihat Lemari Feen' : 'Dandani Feen');

  final userProvider = Provider.of<UserProvider?>(context, listen: false);
  final imageUrl = userProvider?.profileImageUrl;
  final ImageProvider? avatarImage =
      (imageUrl != null && imageUrl.isNotEmpty)
          ? CachedNetworkImageProvider(imageUrl)
          : null;

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: CustomCard(
        borderRadius: 24,
        backgroundColor: cardBg,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Naik ke level $level!',
              style: AppTextStyles.balanceText.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (onlyFrames)
              UserAvatarWithFrame(
                avatarImage: avatarImage,
                frameId: frameItems.first.id,
                size: 132,
                placeholderIconSize: 48,
              )
            else
              FeenAvatar(level: level, pose: FeenPose.levelup, size: 150),
            const SizedBox(height: 8),
            Text(
              headerLabel,
              style: AppTextStyles.captionGreen,
            ),
            const SizedBox(height: 8),
            for (final a in unlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${a.name} (${a.slot.label})',
                  style: const TextStyle(
                    color: orangeText,
                    fontSize: 15,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Nanti',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.push(AppRoutes.feenWardrobe);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
