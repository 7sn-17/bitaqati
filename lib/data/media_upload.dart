import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/config/imagekit_config.dart';
import '../core/media/image_compress.dart';
import '../core/media/image_crop.dart';

/// Largest voice note the upload-media function will accept.
///
/// The recorder stops itself at five minutes, which is roughly 2.4 MB, so this
/// only catches a picked file far longer than a card can use.
const int kMaxAudioBytes = 24 * 1024 * 1024;

/// One attachment the user picked, already uploaded when possible.
@immutable
class PickedMedia {
  const PickedMedia({
    required this.url,
    required this.name,
    required this.isImage,
    required this.uploaded,
    this.localPath,
  });

  /// Public URL when [uploaded] is true, otherwise a local 'file://' path.
  final String url;
  final String name;
  final bool isImage;
  final bool uploaded;
  final String? localPath;

  String get markup => isImage ? '![$name]($url)' : '[صوت]($url)';
}

/// Picks, records and uploads card media.
///
/// A picture goes crop, then compress, then upload-media. A voice note is
/// either recorded in the app or picked from the device and takes the same
/// route. Both land in ImageKit through the Edge Function that holds the
/// private key, so no card-sized file touches Supabase Storage any more.
///
/// When the upload is not possible (guest build, no network, no session) the
/// local file path is returned instead, so the card still works on this device
/// and the learner is never blocked mid-edit.
class MediaUploadService {
  MediaUploadService();

  final ImagePicker _picker = ImagePicker();

  /// Picks a picture, lets the learner crop it, compresses it, then uploads.
  ///
  /// The order is the whole point: the crop decides what the card shows, the
  /// compression decides how many bytes travel, and both have to happen before
  /// anything is sent. Uploading first would leave the full frame at full
  /// resolution in storage forever.
  Future<PickedMedia?> pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      // No maxWidth here: the picker would downscale before the crop, and the
      // crop is exactly the step that decides the final size.
      imageQuality: 100,
    );
    if (picked == null) {
      return null;
    }
    final File? cropped = await cropImage(File(picked.path));
    if (cropped == null) {
      // Backed out of the cropper: nothing is attached.
      return null;
    }
    final File source = await compressImage(cropped) ?? cropped;
    final Uint8List bytes = await source.readAsBytes();
    final String name = _shortName(_stemOf(picked.name), 'صورة');
    final String stem = _asciiName(name, fallback: 'image');
    final String extension = _extensionOf(source.path, fallback: 'jpg');
    final String? url = await _uploadToImageKit(
      bytes: bytes,
      fileName: '$stem.$extension',
    );
    return PickedMedia(
      url: url ?? 'file://${source.path}',
      name: name,
      isImage: true,
      uploaded: url != null,
      localPath: source.path,
    );
  }

  /// Picks a sound file from the device and uploads it.
  Future<PickedMedia?> pickAudioFile() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.audio,
      dialogTitle: 'اختر ملفاً صوتياً',
    );
    if (files.isEmpty) {
      return null;
    }
    final PlatformFile file = files.first;
    final Uint8List bytes = await file.readAsBytes();
    return _finishAudio(
      bytes: bytes,
      name: _shortName(_stemOf(file.name), 'صوت'),
      extension: _extensionOf(file.name, fallback: 'mp3'),
      localPath: file.path,
    );
  }

  /// Uploads a voice note the in-app recorder just wrote.
  ///
  /// Returns null when the file cannot be read or is too large to be a card
  /// attachment, which the recorder flow turns into a message instead of a
  /// silent no-op.
  Future<PickedMedia?> uploadRecording(String path) async {
    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
    if (bytes.isEmpty || bytes.length > kMaxAudioBytes) {
      return null;
    }
    return _finishAudio(
      bytes: bytes,
      name: 'تسجيل صوتي',
      extension: _extensionOf(path, fallback: 'm4a'),
      localPath: path,
    );
  }

  Future<PickedMedia?> _finishAudio({
    required Uint8List bytes,
    required String name,
    required String extension,
    String? localPath,
  }) async {
    if (bytes.isEmpty || bytes.length > kMaxAudioBytes) {
      return null;
    }
    final String stem = _asciiName(name, fallback: 'audio');
    final String? url = await _uploadToImageKit(
      bytes: bytes,
      fileName: '$stem.$extension',
    );
    final String fallback = localPath == null || localPath.isEmpty
        ? ''
        : 'file://$localPath';
    return PickedMedia(
      url: url ?? fallback,
      name: name,
      isImage: false,
      uploaded: url != null,
      localPath: localPath,
    );
  }

  /// Pushes [bytes] through the upload-media Edge Function, which is the only
  /// holder of the ImageKit private key.
  ///
  /// Returns null when the function is missing, the session expired, the device
  /// is offline, or ImageKit refused the file. The caller then keeps the file
  /// on the device rather than losing it.
  Future<String?> _uploadToImageKit({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!AppConfig.hasSupabase) {
      return null;
    }
    try {
      final String? token =
          Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) {
        return null;
      }
      final http.Response response = await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/upload-media'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'apikey': AppConfig.supabasePublishableKey,
              'Content-Type': 'application/octet-stream',
              // HTTP headers are Latin-1: an Arabic file name has to be folded
              // to ASCII here or the request fails before it leaves the phone.
              'x-file-name': fileName,
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        return null;
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? url = decoded['url'];
      if (url is! String || !url.startsWith(imageKitUrlEndpoint)) {
        return null;
      }
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Keeps a file name safe for an HTTP header.
  String _asciiName(String name, {required String fallback}) {
    final String cleaned = name
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  /// The name without its extension, so a header never ends in '.jpg.jpg'.
  String _stemOf(String name) {
    final String trimmed = name.trim();
    final int dot = trimmed.lastIndexOf('.');
    if (dot <= 0) {
      return trimmed;
    }
    return trimmed.substring(0, dot).trim();
  }

  String _extensionOf(String name, {required String fallback}) {
    final int dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) {
      return fallback;
    }
    final String value = name.substring(dot + 1).toLowerCase();
    if (value.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(value)) {
      return fallback;
    }
    return value;
  }

  String _shortName(String name, String fallback) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    return trimmed.length > 32 ? trimmed.substring(0, 32) : trimmed;
  }

  /// Reads a local file into memory, used by the occlusion editor.
  static Future<Uint8List?> readLocal(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
