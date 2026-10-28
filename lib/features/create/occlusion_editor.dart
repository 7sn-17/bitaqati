import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/card_markup.dart';
import '../../core/widgets/image_viewer.dart';

/// Resolves a stored URL to an image provider (network or on-device file).
ImageProvider imageProviderFor(String url) => imageProviderForUrl(url);

/// Interactive canvas for image occlusion.
///
/// Drag on empty image space to draw a box, drag a box to move it, and drag a
/// corner grip to resize it. Geometry is stored normalised (0..1) so the same
/// card renders correctly at any size.
///
/// Moving and resizing are separate gestures on separate widgets. The old
/// version guessed which one you meant from how close to a corner the touch
/// started, which meant a box smaller than twice the touch radius could never
/// be moved at all — the single most common complaint about this screen.
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

  /// True when [position] lands on a box, so the drag belongs to that box and
  /// must not also start drawing a new one underneath it.
  bool _onBox(Offset position, Rect frame) {
    for (final OcclusionBox box in widget.boxes) {
      if (box.toRect(frame).inflate(4).contains(position)) {
        return true;
      }
    }
    return false;
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

  void _remove(int index) {
    final List<OcclusionBox> next = <OcclusionBox>[...widget.boxes]
      ..removeAt(index);
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
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: (DragStartDetails details) {
                    // A drag that starts on a box is that box's move or
                    // resize, never a new rectangle.
                    if (_onBox(details.localPosition, frame)) {
                      return;
                    }
                    setState(() {
                      _start = _clamp(details.localPosition, frame);
                      _current = _start;
                    });
                  },
                  onPanUpdate: (DragUpdateDetails details) {
                    if (_start == null) {
                      return;
                    }
                    setState(() {
                      _current = _clamp(details.localPosition, frame);
                    });
                  },
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
                          key: ValueKey<int>(index),
                          rect: widget.boxes[index].toRect(frame),
                          canvas: frame.size,
                          box: widget.boxes[index],
                          index: index,
                          onChanged: (OcclusionBox box) => _replace(index, box),
                          onDelete: () => _remove(index),
                        ),
                      if (_start != null && _current != null)
                        Positioned.fromRect(
                          rect: Rect.fromPoints(_start!, _current!),
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                color: context.accent.withValues(alpha: 0.28),
                                border: Border.all(
                                  color: context.accent,
                                  width: 1.4,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
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
                    : 'اسحب المربّع لتحريكه، ومن مقابضه لتكبير‌ه.',
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
    required this.onDelete,
    super.key,
  });

  final Rect rect;
  final Size canvas;
  final OcclusionBox box;
  final int index;
  final ValueChanged<OcclusionBox> onChanged;

  /// Removes this box. Wired to the corner badge and to a long press.
  final VoidCallback onDelete;

  @override
  State<_BoxOverlay> createState() => _BoxOverlayState();
}

/// Which corner a drag grabbed, or [move] for the body.
enum _Grip { move, topLeft, topRight, bottomLeft, bottomRight }

class _BoxOverlayState extends State<_BoxOverlay> {
  /// The smallest a box may be dragged down to, in normalised units.
  static const double _min = 0.04;

  /// A fingertip is about this wide. A plate smaller than it gets an invisible
  /// margin, so a 20 pixel box can still be grabbed and moved.
  static const double _touchSize = 44;

  _Grip? _grip;

  /// Extra room around the plate, in pixels, so the touch area is never
  /// smaller than a finger. The plate itself keeps its exact geometry.
  double get _pad {
    final double smallest = math.min(widget.rect.width, widget.rect.height);
    return smallest >= _touchSize ? 0 : (_touchSize - smallest) / 2;
  }

  /// Small plates get one grip instead of four: four handles on a 20 pixel box
  /// would cover it completely and leave nowhere to drag it from.
  bool get _compact => math.min(widget.rect.width, widget.rect.height) < 48;

  void _drag(DragUpdateDetails details) {
    final _Grip? grip = _grip;
    if (grip == null) {
      return;
    }
    final OcclusionBox box = widget.box;
    final double dx = details.delta.dx / widget.canvas.width;
    final double dy = details.delta.dy / widget.canvas.height;

    if (grip == _Grip.move) {
      widget.onChanged(
        box.copyWith(
          left: (box.left + dx).clamp(0.0, 1.0 - box.width),
          top: (box.top + dy).clamp(0.0, 1.0 - box.height),
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
    switch (grip) {
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

  Alignment _corner(_Grip grip) {
    switch (grip) {
      case _Grip.move:
      case _Grip.topLeft:
        return Alignment.topLeft;
      case _Grip.topRight:
        return Alignment.topRight;
      case _Grip.bottomLeft:
        return Alignment.bottomLeft;
      case _Grip.bottomRight:
        return Alignment.bottomRight;
    }
  }

  Widget _handle(_Grip grip, double pad) {
    // The 26 pixel target is centred on the plate's corner: half of it sits
    // outside the box, which is what makes a corner reachable on a plate too
    // small to hold it.
    return Positioned(
      left: grip == _Grip.topLeft || grip == _Grip.bottomLeft ? pad - 13 : null,
      right: grip == _Grip.topRight || grip == _Grip.bottomRight
          ? pad - 13
          : null,
      top: grip == _Grip.topLeft || grip == _Grip.topRight ? pad - 13 : null,
      bottom: grip == _Grip.bottomLeft || grip == _Grip.bottomRight
          ? pad - 13
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (DragStartDetails details) => setState(() => _grip = grip),
        onPanUpdate: _drag,
        onPanEnd: (DragEndDetails details) => setState(() => _grip = null),
        onPanCancel: () => setState(() => _grip = null),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Align(
            alignment: _corner(grip),
            child: Container(
              width: 13,
              height: 13,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: context.accent,
                shape: BoxShape.circle,
                border: Border.all(color: context.primary, width: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _grip != null;
    final double pad = _pad;
    return Positioned.fromRect(
      rect: widget.rect.inflate(pad),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // The gesture surface is the inflated rect; the plate is drawn at
          // its true size by the margin, so nothing moves when the touch area
          // grows.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: (DragStartDetails details) =>
                  setState(() => _grip = _Grip.move),
              onPanUpdate: _drag,
              onPanEnd: (DragEndDetails details) =>
                  setState(() => _grip = null),
              onPanCancel: () => setState(() => _grip = null),
              // A long press is the second way out of a box that is too small
              // to aim at its corner badge.
              onLongPress: widget.onDelete,
              child: Container(
                margin: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.72),
                  border: Border.all(
                    color: active
                        ? context.accent
                        : context.accent.withValues(alpha: 0.7),
                    width: active ? 2.4 : 1.6,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Text(
                      (widget.index + 1).toString(),
                      style: TextStyle(
                        color: context.accent,
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_compact)
            _handle(_Grip.bottomRight, pad)
          else ...<Widget>[
            _handle(_Grip.topLeft, pad),
            _handle(_Grip.topRight, pad),
            _handle(_Grip.bottomLeft, pad),
            _handle(_Grip.bottomRight, pad),
          ],
          // The delete badge sits on the plate's top-right corner, outside it,
          // so it never covers the number or the image the box is marking.
          Positioned(
            right: pad - 9,
            top: pad - 9,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
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
