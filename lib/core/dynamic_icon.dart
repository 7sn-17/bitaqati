import 'dart:ui' show Color;

import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.background,
    this.pro = false,
  });

  final String alias;
  final String label;
  final String note;

  /// The original 1024px artwork, used everywhere the icon is drawn.
  ///
  /// It is also the file the launcher icon is built from, so the splash, the
  /// login screen, the picker and the home screen are all showing the same
  /// pixels — there is no second, pre-composited copy to drift out of date.
  final String asset;

  /// The colour behind the artwork in the adaptive layer.
  final Color background;

  /// True for the icons that are part of the paid tier.
  final bool pro;

  /// The alias the manifest gives the default icon. Passing null to the plugin
  /// restores it, which is why this one is not toggled like the others.
  static const String defaultAlias = 'DEFAULT';

  /// The option for [alias], falling back to the default for anything unknown.
  /// A preference written by an older build must not blank the icon.
  static AppIconOption byAlias(String alias) {
    for (final AppIconOption option in kAppIcons) {
      if (option.alias == alias) {
        return option;
      }
    }
    return kAppIcons.first;
  }
}

const List<AppIconOption> kAppIcons = <AppIconOption>[
  AppIconOption(
    alias: AppIconOption.defaultAlias,
    label: 'الافتراضي',
    note: 'الأصفر',
    asset: 'assets/app_icons/default.png',
    background: Color(0xFF1A4632),
  ),
  AppIconOption(
    alias: 'CrownIcon',
    label: 'التاج',
    note: 'لمشتركي Pro',
    asset: 'assets/app_icons/crown.png',
    background: Color(0xFF14662A),
    pro: true,
  ),
  AppIconOption(
    alias: 'BlueIcon',
    label: 'الأزرق',
    note: 'لمشتركي Pro',
    asset: 'assets/app_icons/blue.png',
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

  /// The preference that remembers which icon was chosen.
  static const String prefKey = 'launcher_icon_alias';

  /// The icon this install is supposed to be wearing.
  static String remembered(SharedPreferences prefs) {
    final String? saved = prefs.getString(prefKey);
    return saved == null || saved.isEmpty ? AppIconOption.defaultAlias : saved;
  }

  static Future<void> remember(SharedPreferences prefs, String alias) {
    return prefs.setString(prefKey, alias);
  }

  /// Re-applies the remembered icon when the launcher is showing another one.
  ///
  /// Two things make this necessary. The enabled activity-alias survives an
  /// app update, so a device that once picked the blue icon keeps it after the
  /// APK is replaced — including after a build that changed what the default
  /// alias points at. And the plugin answers "no alternate icon" both for the
  /// default alias and when it cannot read the component at all, so the only
  /// trustworthy comparison is against what this install remembers.
  ///
  /// Returns true when the launcher was actually changed.
  static Future<bool> reconcile(SharedPreferences prefs) async {
    final String wanted = remembered(prefs);
    final String live = await current() ?? AppIconOption.defaultAlias;
    if (live == wanted) {
      return false;
    }
    return apply(wanted);
  }
}
