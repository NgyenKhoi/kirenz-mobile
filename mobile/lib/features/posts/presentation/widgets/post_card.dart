import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/media_viewer.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_draft.dart';
import '../../../comments/presentation/widgets/discussion_section.dart';

typedef PostImageUploader =
    Future<PostMedia> Function(
      PostDraftImage image,
      void Function(double progress) onProgress,
    );

class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.currentUserId,
    required this.pending,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onUploadImage,
    required this.onReact,
    this.isDetail = false,
    super.key,
  });

  final Post post;
  final String? currentUserId;
  final bool pending;
  final Future<bool> Function(
    String content,
    PostPrivacy privacy,
    List<PostMedia> media,
  )
  onEdit;
  final Future<void> Function() onDelete;
  final Future<bool> Function(String caption) onShare;
  final PostImageUploader onUploadImage;
  final Future<bool> Function(ReactionType reaction) onReact;
  final bool isDetail;

  bool get _owned => post.author.id == currentUserId;

  void _openAuthor(BuildContext context) {
    context.push(
      post.author.id == currentUserId
          ? '/profile/me'
          : '/profile/${post.author.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDetail ? null : () => context.push('/post/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openAuthor(context),
                    child: CircleAvatar(
                      backgroundImage: post.author.avatarUrl?.isNotEmpty == true
                          ? CachedNetworkImageProvider(post.author.avatarUrl!)
                          : null,
                      child: post.author.avatarUrl?.isNotEmpty == true
                          ? null
                          : Text(_initials(post.author.resolvedName)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _openAuthor(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.author.resolvedName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_relativeTime(post.createdAt)} · ${_privacyLabel(post.privacy)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_owned)
                    PopupMenuButton<String>(
                      enabled: !pending,
                      tooltip: 'Post actions',
                      onSelected: (value) {
                        if (value == 'edit') _showEdit(context);
                        if (value == 'delete') _confirmDelete(context);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit post')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete post'),
                        ),
                      ],
                    ),
                ],
              ),
              if (post.content.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                _InteractivePostText(content: post.content),
              ],
              if (post.sharedPost != null) ...[
                const SizedBox(height: 14),
                _SharedPostBlock(post: post.sharedPost!),
              ],
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 14),
                _PostGallery(media: post.media),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (post.reactionsCount > 0)
                    TextButton.icon(
                      onPressed: () => showReactionUsersSheet(
                        context,
                        targetId: post.id,
                        comment: false,
                        summary: post.reactionSummary,
                      ),
                      icon: const Icon(Icons.favorite_outline, size: 18),
                      label: Text('${post.reactionsCount}'),
                    )
                  else ...[
                    const Icon(Icons.favorite_outline, size: 18),
                    const SizedBox(width: 5),
                    const Text('0'),
                  ],
                  const Spacer(),
                  Text('${post.commentsCount} comments'),
                ],
              ),
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onLongPress: pending
                          ? null
                          : () => _pickReaction(context),
                      child: TextButton.icon(
                        onPressed: pending
                            ? null
                            : () => onReact(
                                post.reactionSummary.currentUserReaction ??
                                    ReactionType.like,
                              ),
                        icon: Text(
                          post.reactionSummary.currentUserReaction == null
                              ? '♡'
                              : reactionEmoji(
                                  post.reactionSummary.currentUserReaction!,
                                ),
                        ),
                        label: Text(
                          post.reactionSummary.currentUserReaction == null
                              ? 'React'
                              : reactionLabel(
                                  post.reactionSummary.currentUserReaction!,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: isDetail
                          ? null
                          : () => context.push('/post/${post.id}'),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Comment'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: pending ? null : () => _showShare(context),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              if (pending) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEdit(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _EditPostDialog(
        post: post,
        onEdit: onEdit,
        onUploadImage: onUploadImage,
      ),
    );
  }

  Future<void> _pickReaction(BuildContext context) async {
    final selected = await showReactionPicker(context);
    if (selected != null) await onReact(selected);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete();
  }

  Future<void> _showShare(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SharePostDialog(onShare: onShare),
    );
  }
}

class _EditPostDialog extends StatefulWidget {
  const _EditPostDialog({
    required this.post,
    required this.onEdit,
    required this.onUploadImage,
  });

  final Post post;
  final Future<bool> Function(
    String content,
    PostPrivacy privacy,
    List<PostMedia> media,
  )
  onEdit;
  final PostImageUploader onUploadImage;

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final TextEditingController _content;
  late PostPrivacy _privacy;
  late List<PostMedia> _existing;
  final List<PostDraftImage> _newImages = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.post.content)
      ..addListener(_contentChanged);
    _privacy = widget.post.privacy;
    _existing = [...widget.post.media];
  }

  @override
  void dispose() {
    _content
      ..removeListener(_contentChanged)
      ..dispose();
    super.dispose();
  }

  void _contentChanged() => setState(() => _error = null);

  bool get _canSave =>
      !_saving &&
      (_content.text.trim().isNotEmpty ||
          _existing.isNotEmpty ||
          _newImages.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit post'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _content,
                enabled: !_saving,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Content'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PostPrivacy>(
                initialValue: _privacy,
                decoration: const InputDecoration(labelText: 'Privacy'),
                items: PostPrivacy.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_privacyLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _privacy = value;
                            _error = null;
                          });
                        }
                      },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  '${_existing.length + _newImages.length}/10 images',
                ),
              ),
              if (_existing.isNotEmpty || _newImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  children: [
                    for (final image in _existing)
                      _ExistingEditImage(
                        image: image,
                        onRemove: _saving
                            ? null
                            : () => setState(() => _existing.remove(image)),
                      ),
                    for (final image in _newImages)
                      _LocalEditImage(
                        image: image,
                        onRemove: _saving
                            ? null
                            : () => setState(() => _newImages.remove(image)),
                        onRetry: _saving ? null : () => _upload(image.path),
                      ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => context.pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 92);
    if (!mounted || picked.isEmpty) return;
    final errors = <String>[];
    for (final file in picked) {
      if (_existing.length + _newImages.length >= 10) {
        errors.add('You can keep up to 10 images on a post.');
        break;
      }
      if (_newImages.any((item) => item.path == file.path)) continue;
      final bytes = await file.length();
      final contentType = _imageContentType(file.name);
      if (bytes <= 0 || bytes > 10 * 1024 * 1024) {
        errors.add('${file.name} exceeds the 10 MB image limit.');
        continue;
      }
      if (contentType == null) {
        errors.add('${file.name} is not a supported image.');
        continue;
      }
      _newImages.add(
        PostDraftImage(
          path: file.path,
          name: file.name,
          bytes: bytes,
          contentType: contentType,
        ),
      );
    }
    if (mounted) {
      setState(() => _error = errors.isEmpty ? null : errors.join('\n'));
    }
  }

  Future<bool> _upload(String path) async {
    final index = _newImages.indexWhere((item) => item.path == path);
    if (index < 0) return false;
    final source = _newImages[index];
    setState(() {
      _newImages[index] = source.copyWith(
        status: PostImageStatus.uploading,
        progress: 0,
        clearError: true,
      );
    });
    try {
      final uploaded = await widget.onUploadImage(source, (progress) {
        if (!mounted) return;
        final current = _newImages.indexWhere((item) => item.path == path);
        if (current >= 0) {
          setState(() {
            _newImages[current] = _newImages[current].copyWith(
              progress: progress,
            );
          });
        }
      });
      if (!mounted) return false;
      final current = _newImages.indexWhere((item) => item.path == path);
      if (current >= 0) {
        setState(() {
          _newImages[current] = _newImages[current].copyWith(
            status: PostImageStatus.uploaded,
            progress: 1,
            uploaded: uploaded,
          );
        });
      }
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      final current = _newImages.indexWhere((item) => item.path == path);
      if (current >= 0) {
        setState(() {
          _newImages[current] = _newImages[current].copyWith(
            status: PostImageStatus.failed,
            error: error.toString(),
          );
          _error = error.toString();
        });
      }
      return false;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    for (final image in [..._newImages]) {
      if (image.status == PostImageStatus.uploaded) continue;
      if (!await _upload(image.path)) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }
    final media = [..._existing, ..._newImages.map((image) => image.uploaded!)];
    final saved = await widget.onEdit(_content.text, _privacy, media);
    if (!mounted) return;
    if (saved) {
      context.pop();
    } else {
      setState(() {
        _saving = false;
        _error = 'Could not save this post. Your changes are still here.';
      });
    }
  }
}

class _ExistingEditImage extends StatelessWidget {
  const _ExistingEditImage({required this.image, required this.onRemove});

  final PostMedia image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CachedNetworkImage(imageUrl: image.url, fit: BoxFit.cover),
      Positioned(
        right: 0,
        top: 0,
        child: IconButton.filled(
          tooltip: 'Remove image',
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ),
    ],
  );
}

class _LocalEditImage extends StatelessWidget {
  const _LocalEditImage({
    required this.image,
    required this.onRemove,
    required this.onRetry,
  });

  final PostDraftImage image;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.file(File(image.path), fit: BoxFit.cover),
      if (image.status == PostImageStatus.uploading)
        ColoredBox(
          color: Colors.black45,
          child: Center(
            child: CircularProgressIndicator(value: image.progress),
          ),
        ),
      if (image.status == PostImageStatus.failed)
        Material(
          color: Theme.of(context).colorScheme.errorContainer,
          child: InkWell(
            onTap: onRetry,
            child: const Center(child: Text('Retry')),
          ),
        ),
      Positioned(
        right: 0,
        top: 0,
        child: IconButton.filled(
          tooltip: 'Remove image',
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
        ),
      ),
    ],
  );
}

class _SharePostDialog extends StatefulWidget {
  const _SharePostDialog({required this.onShare});

  final Future<bool> Function(String caption) onShare;

  @override
  State<_SharePostDialog> createState() => _SharePostDialogState();
}

class _SharePostDialogState extends State<_SharePostDialog> {
  final _caption = TextEditingController();
  bool _sharing = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Share post'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _caption,
          enabled: !_sharing,
          minLines: 2,
          maxLines: 6,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Caption',
            helperText: 'Shared posts are public.',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _sharing ? null : () => context.pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _sharing ? null : _share,
        child: _sharing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Share'),
      ),
    ],
  );

  Future<void> _share() async {
    setState(() {
      _sharing = true;
      _error = null;
    });
    final shared = await widget.onShare(_caption.text);
    if (!mounted) return;
    if (shared) {
      context.pop();
    } else {
      setState(() {
        _sharing = false;
        _error = 'Could not share this post. Your caption is still here.';
      });
    }
  }
}

class _PostGallery extends StatelessWidget {
  const _PostGallery({required this.media});

  final List<PostMedia> media;

  @override
  Widget build(BuildContext context) {
    final previewable = media
        .where(
          (item) =>
              item.type == PostMediaType.image ||
              item.type == PostMediaType.video,
        )
        .toList(growable: false);
    final visible = previewable.take(4).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final viewerItems = previewable
        .map(
          (item) => MediaViewerItem(
            url: item.url,
            type: item.type == PostMediaType.video ? 'VIDEO' : 'IMAGE',
            name: 'post media',
          ),
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        Widget tile(int index, double tileWidth, double height) =>
            _PostGalleryTile(
              item: visible[index],
              width: tileWidth,
              height: height,
              overflowCount: index == 3 && previewable.length > 4
                  ? previewable.length - 4
                  : 0,
              onTap: () => showAttachmentViewer(
                context,
                items: viewerItems,
                initialIndex: index,
              ),
            );
        if (visible.length == 1) return tile(0, width, 260);
        if (visible.length == 2) {
          final half = (width - 4) / 2;
          return Row(
            children: [
              tile(0, half, 220),
              const SizedBox(width: 4),
              tile(1, half, 220),
            ],
          );
        }
        if (visible.length == 3) {
          final large = (width - 4) * .62;
          final small = width - large - 4;
          return Row(
            children: [
              tile(0, large, 260),
              const SizedBox(width: 4),
              Column(
                children: [
                  tile(1, small, 128),
                  const SizedBox(height: 4),
                  tile(2, small, 128),
                ],
              ),
            ],
          );
        }
        final half = (width - 4) / 2;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(
            visible.length,
            (index) => tile(index, half, half),
          ),
        );
      },
    );
  }
}

class _PostGalleryTile extends StatelessWidget {
  const _PostGalleryTile({
    required this.item,
    required this.width,
    required this.height,
    required this.overflowCount,
    required this.onTap,
  });

  final PostMedia item;
  final double width;
  final double height;
  final int overflowCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.type == PostMediaType.image)
            CachedNetworkImage(
              imageUrl: item.url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined),
              ),
            )
          else
            const ColoredBox(
              color: Colors.black87,
              child: Center(child: CircleAvatar(child: Icon(Icons.play_arrow))),
            ),
          if (overflowCount > 0)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '+$overflowCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SharedPostBlock extends StatelessWidget {
  const _SharedPostBlock({required this.post});

  final SharedPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: post.available
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.author?.resolvedName ?? 'Kirenz user',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (post.content?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(post.content!),
                ],
              ],
            )
          : const Row(
              children: [
                Icon(Icons.visibility_off_outlined),
                SizedBox(width: 10),
                Text('Shared post unavailable'),
              ],
            ),
    );
  }
}

class _InteractivePostText extends StatelessWidget {
  const _InteractivePostText({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(r'([#@][^\s#@.,!?;:()\[\]{}]+)', unicode: true);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in pattern.allMatches(content)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => context.push(
              '/explore?query=${Uri.encodeQueryComponent(token)}',
            ),
            child: Text(
              token,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }
    return Text.rich(
      TextSpan(style: DefaultTextStyle.of(context).style, children: spans),
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String _privacyLabel(PostPrivacy value) => switch (value) {
  PostPrivacy.public => 'Public',
  PostPrivacy.friends => 'Friends',
  PostPrivacy.onlyMe => 'Only me',
};

String _relativeTime(DateTime? value) {
  if (value == null) return 'Recently';
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  return '${difference.inDays}d';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String? _imageContentType(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => null,
  };
}
