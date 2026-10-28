import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// The longest edge a stored card picture may have.
///
/// 1600px is the point where a photographed page is still readable when the
/// learner zooms into a line of handwriting, while the file stays a few
/// hundred kilobytes instead of several megabytes.
const int kImageMaxEdge = 1600;

/// JPEG quality used for stored pictures.
///
/// 85 keeps thin strokes and small print intact; below 75 the artefacts start
/// eating the edges of Arabic letterforms, which is exactly what a flashcard
/// cannot afford.
const int kImageQuality = 85;

/// Re-encodes [file] as a JPEG capped at [kImageMaxEdge] on its longest edge.
///
/// The aspect ratio is never touched: the picture is scaled as a whole, never
/// cropped and never stretched, so a photographed page keeps its shape.
///
/// Returns null when the platform compressor cannot read the file, which the
/// caller treats as "upload the original". Losing the picture would be worse
/// than sending it uncompressed.
Future<File?> compressImage(File file) async {
  try {
    final (int width, int height) = await _sizeOf(file);
    final int longest = math.max(width, height);
    final double scale = longest > kImageMaxEdge ? kImageMaxEdge / longest : 1;
    // The plugin scales by the smaller of (width / minWidth, height / minHeight)
    // and never enlarges. Handing it the already-computed target size is what
    // turns that ratio into an exact cap on the longest edge, instead of a
    // floor on the shortest one.
    final int targetWidth = math.max(1, (width * scale).round());
    final int targetHeight = math.max(1, (height * scale).round());
    final String target =
        '${file.parent.path}/c_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      target,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: kImageQuality,
      format: CompressFormat.jpeg,
      // Bakes EXIF rotation into the pixels before the metadata is dropped, so
      // a photo taken sideways is not stored sideways.
      autoCorrectionAngle: true,
      keepExif: false,
    );
    if (result == null) {
      return null;
    }
    return File(result.path);
  } catch (_) {
    return null;
  }
}

/// Reads the encoded width and height without decoding the pixels.
///
/// A full decode of a twelve-megapixel photo allocates tens of megabytes just
/// to answer two integers; the image header has them already.
Future<(int, int)> _sizeOf(File file) async {
  final Uint8List bytes = await file.readAsBytes();
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
    bytes,
  );
  try {
    final ui.ImageDescriptor descriptor = await ui.ImageDescriptor.encoded(
      buffer,
    );
    final (int, int) size = (descriptor.width, descriptor.height);
    descriptor.dispose();
    return size;
  } finally {
    buffer.dispose();
  }
}
