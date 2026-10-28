import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../theme/app_colors.dart';

/// Opens the platform cropping screen for [image] and returns the result.
///
/// Returns null when the learner backs out, which has to mean \"do not attach
/// this\" rather than \"attach it uncropped\": a cancel is a decision, and
/// quietly using the original would override it.
///
/// When there is no cropper on the platform, or it refuses the file, the
/// original is returned instead. Losing the picture because the crop screen
/// failed would be a worse outcome than keeping it uncropped.
Future<File?> cropImage(File image) async {
  try {
    final CroppedFile? result = await ImageCropper().cropImage(
      sourcePath: image.path,
      // No maxWidth/maxHeight here on purpose: sizing belongs to compressImage,
      // which runs next and caps the longest edge at 1600. Letting the cropper
      // downscale first would add a second resampling step to every picture.
      // The quality stays high because this is an intermediate file.
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: <PlatformUiSettings>[
        AndroidUiSettings(
          toolbarTitle: 'قص الصورة',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          backgroundColor: AppColors.primary,
          activeControlsWidgetColor: AppColors.accent,
          cropFrameColor: Colors.white,
          cropGridColor: Colors.white,
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'قص الصورة',
          doneButtonTitle: 'تم',
          cancelButtonTitle: 'إلغاء',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
    if (result == null) {
      return null;
    }
    return File(result.path);
  } catch (_) {
    return image;
  }
}
