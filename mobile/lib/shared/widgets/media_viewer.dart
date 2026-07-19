import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class MediaViewerItem {
  const MediaViewerItem({
    required this.url,
    required this.type,
    required this.name,
  });

  final String url;
  final String type;
  final String name;
}

Future<void> showMediaViewer(
  BuildContext context, {
  required List<String> urls,
  required int initialIndex,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (context) => MediaViewer(
      items: urls
          .map((url) => MediaViewerItem(url: url, type: 'IMAGE', name: 'photo'))
          .toList(growable: false),
      initialIndex: initialIndex,
    ),
  );
}

Future<void> showAttachmentViewer(
  BuildContext context, {
  required List<MediaViewerItem> items,
  required int initialIndex,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (context) => MediaViewer(items: items, initialIndex: initialIndex),
  );
}

class MediaViewer extends StatefulWidget {
  const MediaViewer({
    required this.initialIndex,
    this.urls = const [],
    this.items = const [],
    super.key,
  });

  final List<String> urls;
  final List<MediaViewerItem> items;
  final int initialIndex;

  List<MediaViewerItem> get effectiveItems => items.isNotEmpty
      ? items
      : urls
            .map(
              (url) => MediaViewerItem(url: url, type: 'IMAGE', name: 'photo'),
            )
            .toList(growable: false);

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    assert(widget.effectiveItems.isNotEmpty);
    _index = widget.initialIndex.clamp(0, widget.effectiveItems.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.effectiveItems;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = items[index];
                return item.type == 'VIDEO'
                    ? _VideoPreview(key: ValueKey(item.url), item: item)
                    : _ZoomableImage(key: ValueKey(item.url), url: item.url);
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton.filled(
                      tooltip: 'Close viewer',
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      tooltip: 'Download ${items[_index].name}',
                      onPressed: () => openMediaUrl(context, items[_index].url),
                      icon: const Icon(Icons.download_outlined),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      liveRegion: true,
                      label: 'Attachment ${_index + 1} of ${items.length}',
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x99000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Text(
                            '${_index + 1} / ${items.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openMediaUrl(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  final opened =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this attachment.')),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.item, super.key});

  final MediaViewerItem item;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
    _initialization = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller
        ..setLooping(true)
        ..play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !_controller.value.isInitialized) {
          return const Center(
            child: Text(
              'Video unavailable',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        return Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(_controller),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _controller.value.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: const CircleAvatar(
                        radius: 28,
                        child: Icon(Icons.play_arrow, size: 34),
                      ),
                    ),
                  ),
                ),
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.only(top: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, super.key});

  final String url;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () {
        final isZoomed =
            _transformationController.value.getMaxScaleOnAxis() > 1;
        _transformationController.value = isZoomed
            ? Matrix4.identity()
            : Matrix4.diagonal3Values(2, 2, 1);
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const CircularProgressIndicator(),
            errorWidget: (context, url, error) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 12),
                Text(
                  'Photo unavailable',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
