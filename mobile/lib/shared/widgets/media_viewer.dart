import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showMediaViewer(
  BuildContext context, {
  required List<String> urls,
  required int initialIndex,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (context) => MediaViewer(urls: urls, initialIndex: initialIndex),
  );
}

class MediaViewer extends StatefulWidget {
  const MediaViewer({
    required this.urls,
    required this.initialIndex,
    super.key,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    assert(widget.urls.isNotEmpty);
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => _ZoomableImage(
              key: ValueKey(widget.urls[index]),
              url: widget.urls[index],
            ),
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
                  Semantics(
                    liveRegion: true,
                    label: 'Photo ${_index + 1} of ${widget.urls.length}',
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
                          '${_index + 1} / ${widget.urls.length}',
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
