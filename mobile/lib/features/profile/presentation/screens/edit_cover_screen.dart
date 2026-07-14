import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/profile_repository.dart';
import '../controllers/profile_media_controller.dart';

class EditCoverScreen extends ConsumerWidget {
  const EditCoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    final media = ref.watch(
      profileMediaControllerProvider(ProfileMediaTarget.cover),
    );
    return PopScope(
      canPop: media.localPath == null && !media.isBusy,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !media.isBusy && await _confirmDiscard(context)) {
          ref
              .read(
                profileMediaControllerProvider(
                  ProfileMediaTarget.cover,
                ).notifier,
              )
              .cancel();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit cover photo')),
        body: SafeArea(
          child: profile.when(
            data: (user) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: media.localPath != null
                            ? Image.file(
                                File(media.localPath!),
                                fit: BoxFit.cover,
                              )
                            : _CoverImage(url: user.coverPhotoUrl),
                      ),
                      if (media.status == ProfileMediaStatus.selecting)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (media.status == ProfileMediaStatus.uploading)
                        ColoredBox(
                          color: const Color(0x77000000),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: media.progress == 0
                                  ? null
                                  : media.progress,
                            ),
                          ),
                        ),
                      Positioned(
                        left: 18,
                        bottom: -2,
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: user.avatarUrl == null
                                ? null
                                : CachedNetworkImageProvider(user.avatarUrl!),
                            child: user.avatarUrl == null
                                ? Text(_initials(user.displayName))
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: media.isBusy
                      ? null
                      : () =>
                            _showSourceSheet(context, ref, user.coverPhotoUrl),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    media.localPath == null
                        ? 'Choose cover photo'
                        : 'Choose another photo',
                  ),
                ),
                if (media.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    media.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (media.localPath != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: media.isBusy
                              ? null
                              : () => ref
                                    .read(
                                      profileMediaControllerProvider(
                                        ProfileMediaTarget.cover,
                                      ).notifier,
                                    )
                                    .cancel(),
                          child: const Text('Cancel selection'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: media.canUpload
                              ? () => _save(context, ref)
                              : null,
                          child: Text(
                            media.status == ProfileMediaStatus.failure
                                ? 'Retry upload'
                                : 'Save cover',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text(error.toString())),
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(profileMediaControllerProvider(ProfileMediaTarget.cover).notifier)
        .upload();
    if (success && context.mounted) context.pop();
  }

  Future<void> _showSourceSheet(
    BuildContext context,
    WidgetRef ref,
    String? currentUrl,
  ) async {
    final source = await showModalBottomSheet<_CoverAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => context.pop(_CoverAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => context.pop(_CoverAction.library),
            ),
            if (currentUrl != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View current cover'),
                onTap: () => context.pop(_CoverAction.view),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || source == null) return;
    if (source == _CoverAction.view) {
      await _viewImage(context, currentUrl!);
      return;
    }
    await ref
        .read(profileMediaControllerProvider(ProfileMediaTarget.cover).notifier)
        .select(
          source == _CoverAction.camera
              ? ImageSource.camera
              : ImageSource.gallery,
        );
  }
}

enum _CoverAction { camera, library, view }

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.panorama_outlined, size: 56),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const ColoredBox(
        color: Color(0xFFE8E2DC),
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

Future<void> _viewImage(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
          SafeArea(
            child: IconButton.filled(
              tooltip: 'Close',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> _confirmDiscard(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard cover photo?'),
          content: const Text('The selected photo has not been uploaded.'),
          actions: [
            TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => context.pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}

String _initials(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return 'K';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
