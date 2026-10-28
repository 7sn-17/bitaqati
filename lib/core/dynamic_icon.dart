import 'dart:ui' show Color;

import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

/// One launcher icon the learner can wear.
///
/// [alias] is the `activity-alias` declared in AndroidManifest.xml. The plugin
/// toggles the enabled component, so the value has to match that declaration
/// exactly; the launcher picks the new icon up without the app restarting.
class AppIconOption {
  const AppIconOption({
    required this.alias,
    required this.label,
    required this.note,
    required this.asset,
    required this.adaptiveAsset,
    required this.background,
    this.pro = false,
  });

  final String alias;
  final String label;
  final String note;

  /// The full-bleed artwork, which is what the legacy mipmap ships.
  final String asset;

  /// The composed adaptive layer: the same artwork at 70% on [background].
  ///
  /// The launcher masks this file to a circle and draws it edge to edge, so
  /// the settings preview uses this one at full tile size. Using [asset] and
  /// scaling it down by hand would show the card smaller than the home screen
  /// does — the artwork already sits inside the adaptive safe zone.
  final String adaptiveAsset;

  /// The colour behind the artwork in the adaptive layer.
  final Color background;

  /// True for the icons that are part of the paid tier.
  final bool pro;

  /// The alias the manifest gives the default icon. Passing null to the plugin
  /// restores it, which is why this one is not toggled like the others.
  static const String defaultAlias = 'DEFAULT';
}

const List<AppIconOption> kAppIcons = <AppIconOption>[
  AppIconOption(
    alias: AppIconOption.defaultAlias,
    label: 'الافتراضي',
    note: 'الأصفر',
    asset: 'assets/app_icons/default.png',
    adaptiveAsset: 'assets/app_icons/default_adaptive.png',
    background: Color(0xFF1A4632),
  ),
  AppIconOption(
    alias: 'CrownIcon',
    label: 'التاج',
    note: 'لمشتركي Pro',
    asset: 'assets/app_icons/crown.png',
    adaptiveAsset: 'assets/app_icons/crown_adaptive.png',
    background: Color(0xFF14662A),
    pro: true,
  ),
  AppIconOption(
    alias: 'BlueIcon',
    label: 'الأزرق',
    note: 'لمشتركي Pro',
    asset: 'assets/app_icons/blue.png',
    adaptiveAsset: 'assets/app_icons/blue_adaptive.png',
    background: Color(0xFF0F2C51),
    pro: true,
  ),
];

/// Switches the launcher icon.
///
/// Every call is wrapped: the platform channel throws on iOS, on a device whose
/// launcher ignores aliases, and on a build where the manifest has not been
/// updated. A failed icon change must never take the settings screen down with
/// it, so the caller gets a bool and shows a quiet message.
abstract final class DynamicIconService {
  static Future<bool> get supported async {
    try {
      return await FlutterDynamicIconPlus.supportsAlternateIcons;
    } catch (_) {
      return false;
    }
  }

  /// The alias currently enabled, as a bare name, or null when it cannot be
  /// read. The plugin answers with a fully qualified component name.
  static Future<String?> current() async {
    try {
      final String? name = await FlutterDynamicIconPlus.alternateIconName;
      if (name == null || name.isEmpty) {
        return null;
      }
      final int dot = name.lastIndexOf('.');
      return dot == -1 ? name : name.substring(dot + 1);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> apply(String alias) async {
    try {
      await FlutterDynamicIconPlus.setAlternateIconName(
        iconName: alias == AppIconOption.defaultAlias ? null : alias,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
