import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class KirenzUserAvatar extends StatelessWidget {
  const KirenzUserAvatar({
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.icon,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final initials = _initials(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      backgroundImage: url == null || url.isEmpty
          ? null
          : CachedNetworkImageProvider(url),
      child: url == null || url.isEmpty
          ? IconTheme(
              data: IconThemeData(size: radius),
              child: icon == null ? Text(initials) : Icon(icon),
            )
          : null,
    );
  }
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  final initials = words
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();
  return initials.isEmpty ? 'K' : initials;
}
