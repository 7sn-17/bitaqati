import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_markup.dart';
import '../../core/widgets/image_viewer.dart';

/// Resolves a stored URL to an image provider (network or on-device file).
ImageProvider imageProviderFor(String url) => imageProviderForUrl(url);

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

  Offset _clamp(Offset position, Rect frame) {
    return Offset(
      position.dx.clamp(frame.left, frame.right),
      position.dy.clamp(frame.top, frame.bottom),
    );
  }

  void _finish(Rect frame) {
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
    if (rect.width / frame.width < 0.04 || rect.height / frame.height < 0.04) {
      return;
    }
    // Normalised against the picture, not the widget: the review draws the
    // same picture letterboxed inside a box of a different size, and only the
    // picture's own rectangle is common to both.
    widget.onChanged(<OcclusionBox>[
      ...widget.boxes,
      OcclusionBox(
        left: (rect.left - frame.left) / frame.width,
        top: (rect.top - frame.top) / frame.height,
        width: rect.width / frame.width,
        height: rect.height / frame.height,
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
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size size = Size(constraints.maxWidth, widget.height);
                // The picture sits inside this frame, not across the whole
                // box. Drawing against the frame is what makes the editor and
                // the review agree.
                final Rect frame = containRect(size, _aspect);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (DragStartDetails details) => setState(() {
                    _start = _clamp(details.localPosition, frame);
                    _current = _start;
                  }),
                  onPanUpdate: (DragUpdateDetails details) => setState(() {
                    _current = _clamp(details.localPosition, frame);
                  }),
                  onPanEnd: (DragEndDetails details) => _finish(frame),
                  onPanCancel: () => setState(() {
                    _start = null;
                    _current = null;
                  }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image(
                        image: imageProviderFor(widget.imageUrl),
                        fit: BoxFit.contain,
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
                          rect: widget.boxes[index].toRect(frame),
                          canvas: frame.size,
                          box: widget.boxes[index],
                          index: index,
                          onChanged: (OcclusionBox box) => _replace(index, box),
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
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.42),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                showImageViewer(context, widget.imageUrl),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.open_in_full_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
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

/// Which corner a drag grabbed, or [move] for the body.
enum _Grip { move, topLeft, topRight, bottomLeft, bottomRight }

class _BoxOverlayState extends State<_BoxOverlay> {
  /// How close to a corner a touch has to start to resize from it.
  static const double _touch = 32;

  /// The smallest a box may be dragged down to, in normalised units.
  static const double _min = 0.04;

  _Grip _grip = _Grip.move;

  _Grip _gripAt(Offset position) {
    final Size size = widget.rect.size;
    final bool left = position.dx <= _touch;
    final bool right = position.dx >= size.width - _touch;
    final bool top = position.dy <= _touch;
    final bool bottom = position.dy >= size.height - _touch;
    if (top && left) {
      return _Grip.topLeft;
    }
    if (top && right) {
      return _Grip.topRight;
    }
    if (bottom && left) {
      return _Grip.bottomLeft;
    }
    if (bottom && right) {
      return _Grip.bottomRight;
    }
    return _Grip.move;
  }

  void _drag(DragUpdateDetails details) {
    final OcclusionBox box = widget.box;
    final double dx = details.delta.dx / widget.canvas.width;
    final double dy = details.delta.dy / widget.canvas.height;
    if (_grip == _Grip.move) {
      widget.onChanged(
        box.copyWith(
          left: (box.left + dx).clamp(0.0, 1 - box.width),
          top: (box.top + dy).clamp(0.0, 1 - box.height),
        ),
      );
      return;
    }

    double left = box.left;
    double top = box.top;
    double right = box.left + box.width;
    double bottom = box.top + box.height;

    // Each corner moves its own two edges, and never past the opposite edge:
    // the clamp is against the far side of the box, not against the image, so
    // a box can never invert or collapse.
    switch (_grip) {
      case _Grip.move:
        break;
      case _Grip.topLeft:
        left = (left + dx).clamp(0.0, right - _min);
        top = (top + dy).clamp(0.0, bottom - _min);
      case _Grip.topRight:
        right = (right + dx).clamp(left + _min, 1.0);
        top = (top + dy).clamp(0.0, bottom - _min);
      case _Grip.bottomLeft:
        left = (left + dx).clamp(0.0, right - _min);
        bottom = (bottom + dy).clamp(top + _min, 1.0);
      case _Grip.bottomRight:
        right = (right + dx).clamp(left + _min, 1.0);
        bottom = (bottom + dy).clamp(top + _min, 1.0);
    }

    widget.onChanged(
      box.copyWith(
        left: left,
        top: top,
        width: right - left,
        height: bottom - top,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _grip != _Grip.move;
    return Positioned.fromRect(
      rect: widget.rect,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (DragStartDetails details) =>
                  setState(() => _grip = _gripAt(details.localPosition)),
              onPanUpdate: _drag,
              onPanEnd: (DragEndDetails details) =>
                  setState(() => _grip = _Grip.move),
              onPanCancel: () => setState(() => _grip = _Grip.move),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.78),
                  border: Border.all(
                    color: active
                        ? AppColors.accent
                        : AppColors.accent.withValues(alpha: 0.7),
                    width: active ? 2.2 : 1.6,
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
          ),
          // Four visible grips: a single corner was easy to miss and made
          // resizing a guess.
          for (final _Grip grip in <_Grip>[
            _Grip.topLeft,
            _Grip.topRight,
            _Grip.bottomLeft,
            _Grip.bottomRight,
          ])
            Positioned(
              left: grip == _Grip.topLeft || grip == _Grip.bottomLeft
                  ? 0
                  : null,
              right: grip == _Grip.topRight || grip == _Grip.bottomRight
                  ? 0
                  : null,
              top: grip == _Grip.topLeft || grip == _Grip.topRight ? 0 : null,
              bottom: grip == _Grip.bottomLeft || grip == _Grip.bottomRight
                  ? 0
                  : null,
              child: IgnorePointer(
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),
            ),
          // Floating outside the box so it never covers the region it deletes.
          Positioned(
            right: -10,
            top: -10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onRemove,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
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
