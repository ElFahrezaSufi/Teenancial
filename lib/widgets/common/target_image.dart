import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class TargetImage extends StatelessWidget {
  final String imageUrl;
  final double height;

  const TargetImage({
    super.key,
    required this.imageUrl,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );

    if (imageUrl.isEmpty || !imageUrl.startsWith('http')) {
      return fallback;
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(
        height: height,
        color: lightGreen.withValues(alpha: 0.35),
      ),
      errorWidget: (context, url, error) => fallback,
    );
  }
}
