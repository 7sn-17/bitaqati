import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_markup.dart';

/// Resolves a stored URL to an image provider (network or on-device file).
ImageProvider imageProviderFor(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  final String path = url.startsWith('file://')
      ? Uri.parse(url).toFilePath()
      : url;
  return FileImage(File(path));
}

/// Interactive canvas for image occlusion.
///
/// Drag anywhere on the image to draw a box; tap a box to remove it. Geometry
/// is stored normalised (0..1) so the same card renders correctly at any size.
class OcclusionCanvas extends StatefulWidget {
  const OcclusionCanvas({
    required this.imageUrl,
    required this.boxes,
    required this.onChanged,
    this.height = 300,
    super.key,
  });

  final String imageUrl;
  final List<OcclusionBox> boxes;
  final ValueChanged<List<OcclusionBox>> onChanged;
  final double height;

  @override
  State<OcclusionCanvas> createState() => _OcclusionCanvasState();
}

class _OcclusionCanvasState extends State<OcclusionCanvas> {
  Offset? _start;
  Offset? _current;
  double _aspect = 4 / 3;

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant OcclusionCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveAspect();
    }
  }

  /// Reads the real image ratio so boxes drawn here line up with the review
  /// screen, whatever the source resolution is.
  void _resolveAspect() {
    final ImageProvider provider = imageProviderFor(widget.imageUrl);
    final ImageStream stream = provider.resolve(
      const ImageConfiguration(),
    );
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        final double ratio = info.image.width / info.image.height;
        if (mounted && ratio.isFinite && ratio > 0) {
          setState(() => _aspect = ratio);
        }
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stack) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  Offset _clamp(Offset position, Size size) {
    return Offset(
      position.dx.clamp(0.0, size.width),
      position.dy.clamp(0.0, size.height),
    );
  }

  void _finish(Size size) {
    final Offset? start = _start;
    final Offset? end = _current;
    setState(() {
      _start = null;
      _current = null;
    });
    if (start == null || end == null) {
      return;
    }
    final Rect rect = Rect.fromPoints(start, end);
    if (rect.width / size.width < 0.04 || rect.height / size.height < 0.04) {
      return;
    }
    widget.onChanged(<OcclusionBox>[
      ...widget.boxes,
      OcclusionBox(
        left: rect.left / size.width,
        top: rect.top / size.height,
        width: rect.width / size.width,
        height: rect.height / size.height,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (DragStartDetails details) => setState(() {
                    _start = _clamp(details.localPosition, size);
                    _current = _start;
                  }),
                  onPanUpdate: (DragUpdateDetails details) => setState(() {
                    _current = _clamp(details.localPosition, size);
                  }),
                  onPanEnd: (DragEndDetails details) => _finish(size),
                  onPanCancel: () => setState(() {
                    _start = null;
                    _current = null;
                  }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image(
                        image: imageProviderFor(widget.imageUrl),
                        fit: BoxFit.fill,
                        errorBuilder:
                            (
                              BuildContext context,
                              Object error,
                              StackTrace? stack,
                            ) => Container(
                              color: context.softAccent,
                              alignment: Alignment.center,
                              child: Text(
                                'تعذّر تحميل الصورة',
                                style: context.texts.bodySmall,
                              ),
                            ),
                      ),
                      for (int index = 0; index < widget.boxes.length; index++)
                        _BoxOverlay(
                          rect: widget.boxes[index].toRect(size),
                          index: index,
                          onRemove: () {
                            final List<OcclusionBox> next = <OcclusionBox>[
                              ...widget.boxes,
                            ]..removeAt(index);
                            widget.onChanged(next);
                          },
                        ),
                      if (_start != null && _current != null)
                        Positioned.fromRect(
                          rect: Rect.fromPoints(_start!, _current!),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.28),
                              border: Border.all(
                                color: AppColors.accent,
                                width: 1.4,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Icon(
              Icons.gesture_rounded,
              size: 15,
              color: context.texts.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.boxes.isEmpty
                    ? 'اسحب إصبعك فوق الصورة لرسم مستطيل التغطية.'
                    : 'اسحب لإضافة تغطية، واضغط × لحذف واحدة.',
                style: context.texts.bodySmall,
              ),
            ),
            Text(
              '\u200E${widget.boxes.length} تغطية',
              style: context.texts.labelSmall?.copyWith(
                color: context.brandInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BoxOverlay extends StatelessWidget {
  const _BoxOverlay({
    required this.rect,
    required this.index,
    required this.onRemove,
  });

  final Rect rect;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.82),
              border: Border.all(color: AppColors.accent, width: 1.6),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              (index + 1).toString(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            top: -8,
            left: -8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
