import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'audio_playback.dart';

/// The card body is stored as light markdown so the same string renders in the
/// editor, the card list, the review screen and the public library without a
/// second schema:
///
/// * `**bold**`, `_italic_`, `$x^2$` — inline formatting.
/// * `{{c1::answer}}` — a cloze deletion.
/// * `![alt](url)` — an image attachment.
/// * `[صوت](url)` — an audio attachment.
final RegExp kClozeRegex = RegExp(r'\{\{c\d+::(.*?)\}\}');
final RegExp kImageRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
final RegExp kAudioRegex = RegExp(
  r'\[(?:صوت|sound|audio)([^\]]*)\]\(([^)]+)\)',
);
final RegExp kInlineRegex = RegExp(
  r'(\*\*[^*]+\*\*|(?<![A-Za-z0-9])_[^_]+_(?![A-Za-z0-9])|\$[^$]+\$)',
);
final RegExp kSingleImageRegex = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$');

/// True when [text] is one image attachment and nothing else.
bool isImageOnly(String text) => kSingleImageRegex.hasMatch(text.trim());

/// Extracts the image URL from an occlusion card front (`![alt](url)`).
String occlusionImageUrl(String front) {
  final RegExpMatch? match = kImageRegex.firstMatch(front.trim());
  return match?.group(2) ?? '';
}

/// The question an occlusion card asks, from the stored back field.
///
/// Older cards stored "the answer or a comment" there, and the editor wrote
/// a placeholder when the writer left it blank. Both would read as a question
/// at the top of the card, so the placeholder is filtered out and an empty
/// string means "this card has no prompt".
String occlusionPrompt(String back) {
  final String text = back.trim();
  if (text == 'تغطية بصرية') {
    return '';
  }
  return text;
}

/// Strips every marker so lists and search results show clean text.
String plainMarkup(String markup) {
  return markup
      .replaceAll(kImageRegex, ' ')
      .replaceAll(kAudioRegex, ' ')
      .replaceAllMapped(kClozeRegex, (Match match) => match.group(1) ?? '')
      .replaceAllMapped(
        kInlineRegex,
        (Match match) => match
            .group(0)!
            .replaceAll(RegExp(r'^\*\*|\*\*$|^_|_$|^\$|\$$'), ''),
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Number of cloze deletions in [text].
int clozeCount(String text) => kClozeRegex.allMatches(text).length;

/// Replaces every cloze answer with a blank run, for the question side.
String maskCloze(String text) {
  return text.replaceAllMapped(
    kClozeRegex,
    (Match match) =>
        '▁' * ((match.group(1)?.trim().length ?? 3).clamp(2, 12).toInt()),
  );
}

/// Builds the styled spans for [value]. Shared by the review screen, the card
/// list and the live preview so they can never drift apart.
List<InlineSpan> markupSpans(
  BuildContext context,
  String value, {
  required TextStyle? style,
  bool revealCloze = true,
  bool highlightCloze = true,
}) {
  final RegExp combined = RegExp(
    '${kClozeRegex.pattern}|${kImageRegex.pattern}'
    '|${kAudioRegex.pattern}|${kInlineRegex.pattern}',
  );
  final List<InlineSpan> spans = <InlineSpan>[];
  int cursor = 0;
  for (final RegExpMatch match in combined.allMatches(value)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: value.substring(cursor, match.start)));
    }
    final String token = match.group(0)!;
    final RegExpMatch? cloze = kClozeRegex.firstMatch(token);
    final RegExpMatch? image = kImageRegex.firstMatch(token);
    final RegExpMatch? audio = kAudioRegex.firstMatch(token);
    if (cloze != null) {
      final String answer = cloze.group(1) ?? '';
      if (!revealCloze) {
        spans.add(
          TextSpan(
            text: ' ▁▁▁ ',
            style: TextStyle(
              color: context.brandInk,
              fontWeight: FontWeight.w700,
              backgroundColor: context.softAccent,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: answer,
            style: TextStyle(
              color: highlightCloze ? context.brandInk : null,
              fontWeight: highlightCloze ? FontWeight.w700 : null,
              backgroundColor: highlightCloze ? context.softAccent : null,
            ),
          ),
        );
      }
    } else if (image != null) {
      final String label = image.group(1) ?? '';
      spans.add(
        TextSpan(
          text: label.isEmpty ? ' 🖼 صورة ' : ' 🖼 $label ',
          style: TextStyle(
            color: context.brandInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (audio != null) {
      spans.add(
        TextSpan(
          text: ' 🔊 صوت ',
          style: TextStyle(
            color: context.brandInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (token.startsWith('**')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (token.startsWith('_')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    } else if (token.startsWith(r'$')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: context.brandInk,
          ),
        ),
      );
    } else {
      spans.add(TextSpan(text: token));
    }
    cursor = match.end;
  }
  if (cursor < value.length) {
    spans.add(TextSpan(text: value.substring(cursor)));
  }
  return spans;
}

/// Renders a card body: inline formatting plus block media.
class CardMarkup extends StatelessWidget {
  const CardMarkup({
    required this.text,
    required this.style,
    this.revealCloze = true,
    this.maxLines,
    this.alignment = CrossAxisAlignment.start,
    this.mediaHeight = 180,
    this.mediaFirst = false,
    this.textHeader,
    this.textAlign,
    this.onTapImage,
    super.key,
  });

  final String text;
  final TextStyle style;
  final bool revealCloze;
  final int? maxLines;
  final CrossAxisAlignment alignment;
  final double mediaHeight;

  /// Puts every attachment above the text instead of inline. The review
  /// screen uses this so a picture is the first thing the learner sees.
  final bool mediaFirst;

  /// Rendered between the attachments and the body.
  ///
  /// The review screen needs exactly that order — picture, then the row that
  /// names the side and carries the speaker button, then the words — without
  /// the label sitting above the picture.
  final Widget? textHeader;

  /// Centres the words. The review screen centres its card, so the text has
  /// to follow or it hangs off one edge of a centred picture.
  final TextAlign? textAlign;

  /// Called with the URL when a picture in the body is tapped.
  final ValueChanged<String>? onTapImage;

  @override
  Widget build(BuildContext context) {
    final String value = text.trim();
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<RegExpMatch> media = <RegExpMatch>[
      ...kImageRegex.allMatches(value),
      ...kAudioRegex.allMatches(value),
    ]..sort((RegExpMatch a, RegExpMatch b) => a.start.compareTo(b.start));

    if (media.isEmpty) {
      final Widget body = Text.rich(
        TextSpan(
          children: markupSpans(
            context,
            value,
            style: style,
            revealCloze: revealCloze,
          ),
          style: style,
        ),
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
      final Widget? header = textHeader;
      if (header == null) {
        return body;
      }
      return Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[header, const SizedBox(height: 10), body],
      );
    }

    if (mediaFirst) {
      final List<Widget> leading = <Widget>[];
      for (final RegExpMatch match in media) {
        final String token = match.group(0)!;
        final RegExpMatch? image = kImageRegex.firstMatch(token);
        if (image != null) {
          leading.add(
            CardImage(
              url: image.group(2) ?? '',
              height: mediaHeight,
              onTap: onTapImage == null
                  ? null
                  : () => onTapImage!(image.group(2) ?? ''),
            ),
          );
        } else {
          leading.add(
            AudioAttachment(url: kAudioRegex.firstMatch(token)?.group(2) ?? ''),
          );
        }
        leading.add(const SizedBox(height: 10));
      }
      final String rest = value
          .replaceAll(kImageRegex, ' ')
          .replaceAll(kAudioRegex, ' ')
          .trim();
      return Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ...leading,
          if (textHeader != null) ...<Widget>[
            textHeader!,
            const SizedBox(height: 10),
          ],
          if (rest.isNotEmpty)
            Text.rich(
              TextSpan(
                children: markupSpans(
                  context,
                  rest,
                  style: style,
                  revealCloze: revealCloze,
                ),
                style: style,
              ),
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
            ),
        ],
      );
    }

    final List<Widget> blocks = <Widget>[];
    int cursor = 0;
    for (final RegExpMatch match in media) {
      if (match.start > cursor) {
        final String chunk = value.substring(cursor, match.start).trim();
        if (chunk.isNotEmpty) {
          blocks.add(
            Text.rich(
              TextSpan(
                children: markupSpans(
                  context,
                  chunk,
                  style: style,
                  revealCloze: revealCloze,
                ),
                style: style,
              ),
            ),
          );
          blocks.add(const SizedBox(height: 8));
        }
      }
      final String token = match.group(0)!;
      final RegExpMatch? image = kImageRegex.firstMatch(token);
      if (image != null) {
        blocks.add(
          CardImage(
            url: image.group(2) ?? '',
            height: mediaHeight,
            onTap: onTapImage == null
                ? null
                : () => onTapImage!(image.group(2) ?? ''),
          ),
        );
      } else {
        final RegExpMatch? audio = kAudioRegex.firstMatch(token);
        blocks.add(AudioAttachment(url: audio?.group(2) ?? ''));
      }
      blocks.add(const SizedBox(height: 8));
      cursor = match.end;
    }
    final String tail = value.substring(cursor).trim();
    if (tail.isNotEmpty) {
      blocks.add(
        Text.rich(
          TextSpan(
            children: markupSpans(
              context,
              tail,
              style: style,
              revealCloze: revealCloze,
            ),
            style: style,
          ),
        ),
      );
    }
    while (blocks.isNotEmpty && blocks.last is SizedBox) {
      blocks.removeLast();
    }
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }
}

/// Network or on-device image, with a quiet placeholder on failure.
class CardImage extends StatelessWidget {
  const CardImage({
    required this.url,
    this.height = 180,
    this.fit = BoxFit.cover,
    this.radius = 16,
    this.onTap,
    super.key,
  });

  final String url;
  final double height;
  final BoxFit fit;
  final double radius;

  /// Opens the picture full screen. The card crops to keep its shape, so a
  /// diagram is only readable in the viewer.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget picture = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _image(context),
      ),
    );
    final VoidCallback? tap = onTap;
    if (tap == null) {
      return picture;
    }
    return GestureDetector(
      onTap: tap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: <Widget>[
          picture,
          PositionedDirectional(
            bottom: 8,
            end: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(BuildContext context) {
    final Widget fallback = Container(
      height: height,
      alignment: Alignment.center,
      color: context.softAccent,
      child: Icon(Icons.image_outlined, size: 26, color: context.brandInk),
    );
    if (url.startsWith('http://') || url.startsWith('https://')) {
      // Cached on disk, so a card that was opened once still shows its image
      // with no connection at all.
      // Decoding at the width the card actually paints keeps a 4K photo from
      // being held in memory at full size, and the disk cache is capped so a
      // deck with hundreds of images cannot grow without bound.
      final int decodeWidth =
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round();
      return CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: fit,
        memCacheWidth: decodeWidth,
        maxWidthDiskCache: decodeWidth,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (BuildContext context, String url) => Container(
          height: height,
          alignment: Alignment.center,
          color: context.softAccent,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (BuildContext context, String url, Object error) =>
            fallback,
      );
    }
    final String path = url.startsWith('file://')
        ? Uri.parse(url).toFilePath()
        : url;
    if (path.isEmpty) {
      return fallback;
    }
    return Image.file(
      File(path),
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          fallback,
    );
  }
}

/// Live editor controller: keeps the stored text untouched but paints it the
/// way it will be read.
///
/// Bold is bold, italic is italic, maths is monospace, and a cloze deletion is
/// a highlighted box rather than a pair of braces. The markers themselves are
/// drawn at 30% opacity, so they are still selectable and editable but stop
/// competing with the words. This is what makes the editor WYSIWYG without
/// moving the card body to a rich-text document format — the stored string is
/// still the same markup every other screen already renders.
class MarkupTextController extends TextEditingController {
  MarkupTextController({super.text});

  /// Cloze, inline formatting, in one pass, left to right.
  static final RegExp _token = RegExp(
    '${kClozeRegex.pattern}|${kInlineRegex.pattern}',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle base = style ?? const TextStyle();
    final TextStyle marker = base.copyWith(
      color: base.color?.withValues(alpha: 0.3),
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      backgroundColor: null,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in _token.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String token = match.group(0)!;
      final RegExpMatch? cloze = kClozeRegex.firstMatch(token);
      if (cloze != null) {
        final int bodyAt = token.indexOf('::') + 2;
        spans.add(TextSpan(text: token.substring(0, bodyAt), style: marker));
        spans.add(
          TextSpan(
            text: cloze.group(1) ?? '',
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              color: context.brandInk,
              backgroundColor: context.softAccent,
            ),
          ),
        );
        spans.add(TextSpan(text: '}}', style: marker));
      } else if (token.startsWith('**')) {
        spans.add(TextSpan(text: '**', style: marker));
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        spans.add(TextSpan(text: '**', style: marker));
      } else if (token.startsWith('_')) {
        spans.add(TextSpan(text: '_', style: marker));
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        spans.add(TextSpan(text: '_', style: marker));
      } else {
        spans.add(TextSpan(text: r'$', style: marker));
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              color: context.brandInk,
            ),
          ),
        );
        spans.add(TextSpan(text: r'$', style: marker));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: base, children: spans);
  }
}

/// One rectangle drawn over an occlusion image, in normalised coordinates.
@immutable
class OcclusionBox {
  const OcclusionBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.answer = '',
  });

  factory OcclusionBox.fromJson(Map<String, Object?> json) {
    double read(String key) {
      final Object? value = json[key];
      if (value is num) {
        return value.toDouble();
      }
      return 0;
    }

    final Object? answer = json['a'];
    return OcclusionBox(
      left: read('l'),
      top: read('t'),
      width: read('w'),
      height: read('h'),
      answer: answer is String ? answer : '',
    );
  }

  final double left;
  final double top;
  final double width;
  final double height;

  /// What the hidden region says. Shown once the learner taps the mask.
  final String answer;

  /// Places the box inside [frame], the rectangle the picture itself covers.
  ///
  /// Taking the frame rather than the widget size is what keeps a box on the
  /// same part of the image in the editor and in the review: under
  /// BoxFit.contain the picture is letterboxed, so the widget and the picture
  /// are not the same rectangle.
  Rect toRect(Rect frame) => Rect.fromLTWH(
    frame.left + left * frame.width,
    frame.top + top * frame.height,
    width * frame.width,
    height * frame.height,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'l': double.parse(left.toStringAsFixed(4)),
    't': double.parse(top.toStringAsFixed(4)),
    'w': double.parse(width.toStringAsFixed(4)),
    'h': double.parse(height.toStringAsFixed(4)),
    if (answer.isNotEmpty) 'a': answer,
  };

  OcclusionBox copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    String? answer,
  }) {
    return OcclusionBox(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      answer: answer ?? this.answer,
    );
  }
}

/// Reads the boxes out of the `occlusion` JSON column.
List<OcclusionBox> occlusionBoxes(Map<String, Object?>? json) {
  if (json == null) {
    return const <OcclusionBox>[];
  }
  final Object? raw = json['boxes'];
  if (raw is! List<Object?>) {
    return const <OcclusionBox>[];
  }
  final List<OcclusionBox> boxes = <OcclusionBox>[];
  for (final Object? entry in raw) {
    if (entry is Map<Object?, Object?>) {
      boxes.add(
        OcclusionBox.fromJson(<String, Object?>{
          for (final MapEntry<Object?, Object?> pair in entry.entries)
            pair.key.toString(): pair.value,
        }),
      );
    }
  }
  return boxes;
}

/// Serialises boxes for the `occlusion` column.
Map<String, Object?>? occlusionPayload(List<OcclusionBox> boxes) {
  if (boxes.isEmpty) {
    return null;
  }
  return <String, Object?>{
    'boxes': <Map<String, Object?>>[
      for (final OcclusionBox box in boxes) box.toJson(),
    ],
  };
}

/// Image with occlusion masks.
///
/// Each box hides one region until the learner taps it, which reveals the
/// answer written for that box. This is what makes occlusion work as a real
/// study card instead of a picture with black squares on it.
/// The rectangle a picture of [aspect] covers inside [canvas] under
/// BoxFit.contain: full width or full height, whichever runs out first.
Rect containRect(Size canvas, double aspect) {
  if (!aspect.isFinite || aspect <= 0 || canvas.isEmpty) {
    return Offset.zero & canvas;
  }
  final double canvasAspect = canvas.width / canvas.height;
  if (aspect > canvasAspect) {
    final double height = canvas.width / aspect;
    return Rect.fromLTWH(0, (canvas.height - height) / 2, canvas.width, height);
  }
  final double width = canvas.height * aspect;
  return Rect.fromLTWH((canvas.width - width) / 2, 0, width, canvas.height);
}

/// The image provider for a stored URL, local file or remote.
ImageProvider imageProviderForUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  final String path = url.startsWith('file://')
      ? Uri.parse(url).toFilePath()
      : url;
  return FileImage(File(path));
}

/// Reports an image's width/height ratio once it decodes.
///
/// Both the editor canvas and the review need it: without it neither knows
/// where the picture sits inside its box, and the boxes drift off the image.
void resolveImageAspect(String url, ValueChanged<double> onRatio) {
  if (url.trim().isEmpty) {
    return;
  }
  final ImageStream stream = imageProviderForUrl(url)
      .resolve(const ImageConfiguration());
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      final double ratio = info.image.width / info.image.height;
      if (ratio.isFinite && ratio > 0) {
        onRatio(ratio);
      }
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stack) =>
        stream.removeListener(listener),
  );
  stream.addListener(listener);
}

class OcclusionView extends StatefulWidget {
  const OcclusionView({
    required this.imageUrl,
    required this.boxes,
    this.masked = true,
    this.height = 220,
    this.onOpenImage,
    super.key,
  });

  final String imageUrl;
  final List<OcclusionBox> boxes;
  final bool masked;
  final double height;

  /// Opens the picture full screen. Tapping the picture itself is the only
  /// gesture left that does not belong to a mask, so it is the natural place
  /// for "let me see this properly".
  final VoidCallback? onOpenImage;

  @override
  State<OcclusionView> createState() => _OcclusionViewState();
}

class _OcclusionViewState extends State<OcclusionView> {
  /// Boxes the learner has tapped open, by index.
  final Set<int> _revealed = <int>{};

  /// The box whose label is currently called out. One at a time: two pills on
  /// a small picture would cover the very region they describe.
  int? _active;

  double _aspect = 4 / 3;

  @override
  void initState() {
    super.initState();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(covariant OcclusionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.boxes.length != widget.boxes.length) {
      _revealed.clear();
      _active = null;
    }
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveAspect();
    }
  }

  void _resolveAspect() {
    resolveImageAspect(widget.imageUrl, (double ratio) {
      if (mounted && ratio != _aspect) {
        setState(() => _aspect = ratio);
      }
    });
  }

  void _tap(int index) {
    if (!widget.masked) {
      return;
    }
    setState(() {
      if (_active == index) {
        _revealed.remove(index);
        _active = null;
      } else {
        _revealed.add(index);
        _active = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // BoxFit.contain, not cover: cropping the picture hid the very regions
    // boxes were drawn on, and the crop factor differed between the editor and
    // the review, so the preview never matched the card.
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = Size(constraints.maxWidth, widget.height);
            final Rect frame = containRect(size, _aspect);
            final List<Widget> masks = <Widget>[];
            for (int index = 0; index < widget.boxes.length; index++) {
              final OcclusionBox box = widget.boxes[index];
              final Rect rect = box.toRect(frame);
              masks.add(
                Positioned.fromRect(
                  rect: rect,
                  child: _OcclusionMask(
                    box: box,
                    rect: rect,
                    frame: frame,
                    revealed: !widget.masked || _revealed.contains(index),
                    callout: widget.masked && _active == index,
                    onTap: () => _tap(index),
                  ),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CardImage(
                  url: widget.imageUrl,
                  height: widget.height,
                  radius: 0,
                  fit: BoxFit.contain,
                  onTap: widget.onOpenImage,
                ),
                ...masks,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OcclusionMask extends StatelessWidget {
  const _OcclusionMask({
    required this.box,
    required this.rect,
    required this.frame,
    required this.revealed,
    required this.callout,
    required this.onTap,
  });

  final OcclusionBox box;

  /// Where the mask sits on screen, in pixels.
  final Rect rect;

  /// The rectangle the picture itself covers. The callout flips below a box
  /// that sits too close to the top edge to hold a bubble above it.
  final Rect frame;

  final bool revealed;

  /// True for the one box whose label is being called out.
  final bool callout;

  final VoidCallback onTap;

  /// How tall the label bubble is, including its gap. Used to decide whether
  /// there is room for it above the box.
  static const double _calloutRoom = 34;

  @override
  Widget build(BuildContext context) {
    if (!revealed) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.isDark
                ? AppColors.darkSurfaceHigh
                : AppColors.primary,
            border: Border.all(
              color: context.brandInk.withValues(alpha: 0.55),
              width: 1.4,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Icon(
              Icons.question_mark_rounded,
              size: 18,
              color: context.isDark ? AppColors.darkAccent : AppColors.accent,
            ),
          ),
        ),
      );
    }

    final bool hasAnswer = box.answer.trim().isNotEmpty;
    final Widget face = Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accent, width: 1.8),
        borderRadius: BorderRadius.circular(6),
        color: AppColors.accent.withValues(alpha: 0.12),
      ),
      padding: const EdgeInsets.all(3),
      alignment: Alignment.center,
      // The bubble carries the label whenever there is one, so the box itself
      // stays a clean outline instead of squeezing text into a few pixels.
      child: hasAnswer && !callout
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: context.isDark
                      ? AppColors.darkAnswerSurface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  box.answer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.isDark
                        ? AppColors.darkInk
                        : AppColors.primary,
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );

    if (!callout || !hasAnswer) {
      return GestureDetector(onTap: onTap, child: face);
    }

    final bool above = rect.top - _calloutRoom >= frame.top;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: face),
          Positioned(
            left: -120,
            right: -120,
            top: above ? null : rect.height + 6,
            bottom: above ? rect.height + 6 : null,
            child: Center(child: _bubble(context)),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkAnswerSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        box.answer,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'ReadexPro',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: context.isDark ? AppColors.darkInk : AppColors.primary,
        ),
      ),
    );
  }
}

/// Decodes a JSON string safely; returns null when it is not valid JSON.
Map<String, Object?>? tryDecodeJson(String raw) {
  try {
    final Object? value = jsonDecode(raw);
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
  } catch (_) {
    return null;
  }
  return null;
}
