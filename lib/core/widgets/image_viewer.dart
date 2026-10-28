import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Opens a card attachment full screen on a black backdrop, with pinch zoom
/// and panning.
///
/// A review card crops pictures to keep the card a card, which is the right
/// call for a photo and the wrong one for a diagram with a caption in the
/// corner. Every attachment the learner can see is therefore also one they can
/// open, from the review screen, the card editor and the occlusion editor.
Future<void> showImageViewer(BuildContext context, String url) {
  final String value = url.trim();
  if (value.isEmpty) {
    return Future<void>.value();
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'صورة',
    barrierColor: Colors.black.withValues(alpha: 0.94),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) => _ImageViewer(url: value),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            // PhotoView, not InteractiveViewer: it keeps the picture inside
            // its own bounds while zooming, snaps back when it is dragged past
            // the edge, and gives a double tap a real meaning.
            child: PhotoView(
              imageProvider: _provider(),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              basePosition: Alignment.center,
              filterQuality: FilterQuality.medium,
              gestureDetectorBehavior: HitTestBehavior.opaque,
              onTapUp:
                  (
                    BuildContext context,
                    TapUpDetails details,
                    PhotoViewControllerValue value,
                  ) {
                    Navigator.of(context).pop();
                  },
              loadingBuilder: (context, progress) => const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
              errorBuilder: (context, error, stack) => _failed(context),
            ),
          ),
          PositionedDirectional(
            top: 6,
            end: 6,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'إغلاق',
                icon: const Icon(Icons.close_rounded),
                color: Colors.white,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 12,
            child: SafeArea(
              child: Text(
                'اقرص للتكبير · اسحب للتحريك · اضغط للإغلاق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider _provider() {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // The grid, the card and this viewer all decode the same URL; sharing
      // one cache entry is what makes opening it feel instant.
      return CachedNetworkImageProvider(url);
    }
    final String path = url.startsWith('file://')
        ? Uri.parse(url).toFilePath()
        : url;
    return FileImage(File(path));
  }

  Widget _failed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(
          Icons.broken_image_outlined,
          size: 42,
          color: Colors.white54,
        ),
        const SizedBox(height: 10),
        Text(
          'تعذّر عرض الصورة.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
