import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Opens a card attachment full screen on a black backdrop, with pinch zoom.
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: _picture(context)),
              ),
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
                'اسحب للتكبير',
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

  Widget _picture(BuildContext context) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final int decodeWidth =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round();
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        memCacheWidth: decodeWidth * 2,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (BuildContext context, String url) => const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (BuildContext context, String url, Object error) =>
            _failed(context),
      );
    }
    final String path = url.startsWith('file://')
        ? Uri.parse(url).toFilePath()
        : url;
    if (path.isEmpty) {
      return _failed(context);
    }
    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _failed(context),
    );
  }

  Widget _failed(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
