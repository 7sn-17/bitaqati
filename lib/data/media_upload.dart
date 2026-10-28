import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/config/imagekit_config.dart';
import '../core/media/image_compress.dart';
import '../core/media/image_crop.dart';

/// Public bucket that holds card audio.
///
/// Pictures moved to ImageKit: they are served from its CDN and uploaded
/// through the upload-image Edge Function, so only sound still lives here.
const String kCardMediaBucket = 'card-media';

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

  /// Public URL when [uploaded] is true, otherwise a local `file://` path.
  final String url;
  final String name;
  final bool isImage;
  final bool uploaded;
  final String? localPath;

  String get markup => isImage ? '![$name]($url)' : '[صوت]($url)';
}

/// Picks media from the device, prepares it, and uploads it.
///
/// Pictures go through crop, compress and then the upload-image Edge Function
/// (which talks to ImageKit); sound still goes to Supabase Storage. When the
/// upload is not possible (guest build, no network, no session) the local file
/// path is returned instead, so the card still works on this device and the
/// user is never blocked mid-edit.
class MediaUploadService {
  MediaUploadService();

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  /// Picks a picture, lets the learner crop it, compresses it, then uploads.
  ///
  /// The order is the whole point: the crop decides what the card shows, the
  /// compression decides how many bytes travel, and both have to happen
  /// before anything is sent. Uploading first would leave the full frame at
  /// full resolution in storage forever.
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
    final String name = _shortName(picked.name, 'صورة');
    final String? url = await _uploadToImageKit(bytes: bytes, fileName: name);
    return PickedMedia(
      url: url ?? 'file://${source.path}',
      name: name,
      isImage: true,
      uploaded: url != null,
      localPath: source.path,
    );
  }

  /// Pushes [bytes] through the upload-image Edge Function, which is the only
  /// holder of the ImageKit private key.
  ///
  /// Returns null when the function is missing, the session expired, the
  /// device is offline, or ImageKit refused the file. The caller then keeps
  /// the picture on the device rather than losing it.
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
            Uri.parse('${AppConfig.supabaseUrl}/functions/v1/upload-image'),
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'apikey': AppConfig.supabasePublishableKey,
              'Content-Type': 'application/octet-stream',
              // HTTP headers are Latin-1: an Arabic file name has to be folded
              // to ASCII here or the request fails before it leaves the phone.
              'x-file-name': _asciiName(fileName),
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 45));
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
  String _asciiName(String name) {
    final String cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return cleaned.isEmpty || cleaned == '-' ? 'image' : cleaned;
  }

  Future<PickedMedia?> pickAudio() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.audio,
      dialogTitle: 'اختر ملفاً صوتياً',
    );
    if (files.isEmpty) {
      return null;
    }
    final PlatformFile file = files.first;
    final Uint8List bytes = await file.readAsBytes();
    final String extension = _extensionOf(file.name, fallback: 'mp3');
    final String name = _shortName(file.name, 'صوت');
    return _upload(
      bytes: bytes,
      fileName: name,
      extension: extension,
      isImage: false,
      localPath: file.path,
    );
  }

  Future<PickedMedia> _upload({
    required Uint8List bytes,
    required String fileName,
    required String extension,
    required bool isImage,
    String? localPath,
  }) async {
    final String? publicUrl = await _uploadToStorage(
      bytes: bytes,
      extension: extension,
      contentType: _contentType(extension, isImage),
    );
    if (publicUrl != null) {
      return PickedMedia(
        url: publicUrl,
        name: fileName,
        isImage: isImage,
        uploaded: true,
        localPath: localPath,
      );
    }
    final String fallback = localPath == null || localPath.isEmpty
        ? ''
        : 'file://$localPath';
    return PickedMedia(
      url: fallback,
      name: fileName,
      isImage: isImage,
      uploaded: false,
      localPath: localPath,
    );
  }

  /// Returns the public URL, or null when the upload is not possible.
  Future<String?> _uploadToStorage({
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (!AppConfig.hasSupabase) {
      return null;
    }
    try {
      final SupabaseClient client = Supabase.instance.client;
      final User? user = client.auth.currentUser;
      if (user == null) {
        return null;
      }
      final String path = '${user.id}/${_uuid.v4()}.$extension';
      await client.storage
          .from(kCardMediaBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              cacheControl: '31536000',
              upsert: false,
            ),
          );
      return client.storage.from(kCardMediaBucket).getPublicUrl(path);
    } catch (_) {
      // Storage is best-effort: the caller falls back to the local file.
      return null;
    }
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

  String _contentType(String extension, bool isImage) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'mp3':
        return 'audio/mpeg';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return isImage ? 'image/jpeg' : 'audio/mpeg';
    }
  }

  /// Deletes a previously uploaded file. Failures are ignored: the card is
  /// already gone from the user's point of view.
  Future<void> deleteUploaded(String url) async {
    if (!url.contains(kCardMediaBucket)) {
      return;
    }
    try {
      final int index = url.indexOf('$kCardMediaBucket/');
      if (index == -1) {
        return;
      }
      final String path = url.substring(index + kCardMediaBucket.length + 1);
      await Supabase.instance.client.storage.from(kCardMediaBucket).remove(
        <String>[path],
      );
    } catch (_) {
      // Orphaned files are cheap; a failed delete must never surface.
    }
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
