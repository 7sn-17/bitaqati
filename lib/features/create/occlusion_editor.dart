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
/// Drag on empty image space to draw a box. Drag a box to move it, drag its
/// corner handle to resize it, and tap the × to delete it. Geometry is stored
/// normalised (0..1) so the same card renders correctly at any size.
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
    final ImageStream stream = provider.resolve(const ImageConfiguration());
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

  void _replace(int index, OcclusionBox box) {
    final List<OcclusionBox> next = <OcclusionBox>[...widget.boxes];
    next[index] = box;
    widget.onChanged(next);
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
                          canvas: size,
                          box: widget.boxes[index],
                          index: index,
                          onChanged: (OcclusionBox box) =>
                              _replace(index, box),
                          onRemove: () {
                            final List<OcclusionBox> next =
                                <OcclusionBox>[...widget.boxes]
                                  ..removeAt(index);
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
                    : 'اسحب داخل المربّع لتحريكه، ومن زاويته لتكبير‌ه.',
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

class _BoxOverlay extends StatefulWidget {
  const _BoxOverlay({
    required this.rect,
    required this.canvas,
    required this.box,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final Rect rect;
  final Size canvas;
  final OcclusionBox box;
  final int index;
  final ValueChanged<OcclusionBox> onChanged;
  final VoidCallback onRemove;

  @override
  State<_BoxOverlay> createState() => _BoxOverlayState();
}

class _BoxOverlayState extends State<_BoxOverlay> {
  /// Half the corner handle, in logical pixels. A drag that starts inside this
  /// square resizes; anywhere else moves the whole box.
  static const double _handle = 24;

  bool _resizing = false;
  bool _moving = false;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: widget.rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails details) {
          final Offset corner = Offset(
            widget.rect.width - details.localPosition.dx,
            widget.rect.height - details.localPosition.dy,
          );
          setState(() {
            _resizing = corner.dx < _handle && corner.dy < _handle;
            _moving = !_resizing;
          });
        },
        onPanUpdate: (DragUpdateDetails details) {
          final Size canvas = widget.canvas;
          final OcclusionBox box = widget.box;
          if (_resizing) {
            final double width =
                (box.width + details.delta.dx / canvas.width).clamp(
                  0.04,
                  1 - box.left,
                );
            final double height =
                (box.height + details.delta.dy / canvas.height).clamp(
                  0.04,
                  1 - box.top,
                );
            widget.onChanged(box.copyWith(width: width, height: height));
            return;
          }
          if (!_moving) {
            return;
          }
          final double left = (box.left + details.delta.dx / canvas.width)
              .clamp(0.0, 1 - box.width);
          final double top = (box.top + details.delta.dy / canvas.height)
              .clamp(0.0, 1 - box.height);
          widget.onChanged(box.copyWith(left: left, top: top));
        },
        onPanEnd: (DragEndDetails details) => setState(() {
          _resizing = false;
          _moving = false;
        }),
        onPanCancel: () => setState(() {
          _resizing = false;
          _moving = false;
        }),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.78),
                  border: Border.all(
                    color: _moving || _resizing
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.7),
                    width: _moving || _resizing ? 2.2 : 1.6,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  (widget.index + 1).toString(),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 2,
              left: 2,
              child: GestureDetector(
                onTap: widget.onRemove,
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
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: const Icon(
                    Icons.open_in_full_rounded,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
