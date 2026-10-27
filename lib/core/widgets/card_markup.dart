import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
final RegExp kSingleImageRegex = RegExp(
  r'^!\[([^\]]*)\]\(([^)]+)\)$',
);

/// True when [text] is one image attachment and nothing else.
bool isImageOnly(String text) => kSingleImageRegex.hasMatch(text.trim());

/// Extracts the image URL from an occlusion card front (`![alt](url)`).
String occlusionImageUrl(String front) {
  final RegExpMatch? match = kImageRegex.firstMatch(front.trim());
  return match?.group(2) ?? '';
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
      return Text.rich(
        TextSpan(
          children: markupSpans(
            context,
            value,
            style: style,
            revealCloze: revealCloze,
          ),
          style: style,
        ),
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      );
    }

    if (mediaFirst) {
      final List<Widget> leading = <Widget>[];
      for (final RegExpMatch match in media) {
        final String token = match.group(0)!;
        final RegExpMatch? image = kImageRegex.firstMatch(token);
        if (image != null) {
          leading.add(CardImage(url: image.group(2) ?? '', height: mediaHeight));
        } else {
          leading.add(AudioAttachment(url: kAudioRegex.firstMatch(token)?.group(2) ?? ''));
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
        blocks.add(CardImage(url: image.group(2) ?? '', height: mediaHeight));
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
    super.key,
  });

  final String url;
  final double height;
  final BoxFit fit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _image(context),
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
      return CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: fit,
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

/// Audio attachment chip. Tells the learner the card carries a recording.
class AudioAttachment extends StatelessWidget {
  const AudioAttachment({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.softAccent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.graphic_eq_rounded, size: 18, color: context.brandInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'مقطع صوتي مرفق',
              style: context.texts.bodySmall?.copyWith(
                color: context.brandInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live editor controller: keeps the stored text untouched but paints the
/// markers, so bold, italic and maths are visible while typing.
class MarkupTextController extends TextEditingController {
  MarkupTextController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle base = style ?? const TextStyle();
    final TextStyle marker = base.copyWith(
      color: base.color?.withValues(alpha: 0.35),
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch match in kInlineRegex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String token = match.group(0)!;
      if (token.startsWith('**')) {
        spans.add(TextSpan(text: '**', style: marker));
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        spans.add(TextSpan(text: '**', style: marker));
      } else if (token.startsWith('_')) {
        spans.add(TextSpan(text: '_', style: marker));
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
        spans.add(TextSpan(text: '_', style: marker));
      } else {
        spans.add(TextSpan(text: r'$', style: marker));
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

  Rect toRect(Size size) => Rect.fromLTWH(
    left * size.width,
    top * size.height,
    width * size.width,
    height * size.height,
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
class OcclusionView extends StatefulWidget {
  const OcclusionView({
    required this.imageUrl,
    required this.boxes,
    this.masked = true,
    this.height = 220,
    super.key,
  });

  final String imageUrl;
  final List<OcclusionBox> boxes;
  final bool masked;
  final double height;

  @override
  State<OcclusionView> createState() => _OcclusionViewState();
}

class _OcclusionViewState extends State<OcclusionView> {
  final Set<int> _revealed = <int>{};

  @override
  void didUpdateWidget(covariant OcclusionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.boxes.length != widget.boxes.length) {
      _revealed.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CardImage(url: widget.imageUrl, height: widget.height, radius: 0),
            if (widget.masked)
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size = Size(constraints.maxWidth, widget.height);
                  return Stack(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < widget.boxes.length;
                        index++
                      )
                        Positioned.fromRect(
                          rect: widget.boxes[index].toRect(size),
                          child: _OcclusionMask(
                            box: widget.boxes[index],
                            revealed: _revealed.contains(index),
                            onTap: () => setState(() {
                              if (!_revealed.remove(index)) {
                                _revealed.add(index);
                              }
                            }),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OcclusionMask extends StatelessWidget {
  const _OcclusionMask({
    required this.box,
    required this.revealed,
    required this.onTap,
  });

  final OcclusionBox box;
  final bool revealed;
  final VoidCallback onTap;

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent, width: 1.8),
          borderRadius: BorderRadius.circular(6),
          color: AppColors.accent.withValues(alpha: 0.12),
        ),
        padding: const EdgeInsets.all(3),
        alignment: Alignment.center,
        child: hasAnswer
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
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
