import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One launcher icon the learner can wear.
///
/// [alias] is the `activity-alias` declared in AndroidManifest.xml. The plugin
/// toggles the enabled component, so the value has to match that declaration
/// exactly.
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

  /// The full-bleed artwork: the splash, the login screen and the legacy
  /// mipmap all draw this file, unscaled and uncropped.
  final String asset;

  /// The composed adaptive layer: the same artwork at 70% on [background].
  ///
  /// The launcher masks this file to a circle and draws it edge to edge, so
  /// the settings preview uses this one at full tile size. Using [asset] and
  /// scaling it down by hand would show the card larger than the home screen
  /// does — the artwork already sits inside the adaptive safe zone.
  final String adaptiveAsset;

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
/// The swap is done by flutter_dynamic_icon_plus. It is deliberate: this is the
/// exact code that has changed the icon on this project's devices before, and
/// hand-rolling the same package-manager calls did not, because the timing is
/// the whole problem.
///
/// The plugin stores the request and hands it to a service that applies it in
/// onTaskRemoved — once the app has left the recents list. That is the only
/// moment a launcher re-reads a package's icon; flipping an alias while the app
/// is still on screen leaves the home screen showing the artwork it already
/// resolved, and on several launchers it finishes the task as well. Nothing is
/// applied in the foreground, so nothing closes under the user.
abstract final class DynamicIconService {
  /// Read-only diagnostics. The plugin owns every write; this channel only asks
  /// the package manager what it currently thinks, so a stuck icon can be
  /// diagnosed from logcat instead of guessed at.
  static const MethodChannel _diagnostics = MethodChannel(
    'com.bitaqati.app/icon',
  );

  /// Whether this build can change its icon at all: every alias has to be
  /// declared, and the platform channel has to answer.
  static Future<bool> get supported async {
    try {
      return await FlutterDynamicIconPlus.supportsAlternateIcons;
    } catch (error) {
      debugPrint('[icon] supportsAlternateIcons failed: $error');
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
    } catch (error) {
      debugPrint('[icon] alternateIconName failed: $error');
      return null;
    }
  }

  /// Every alias and the state the package manager reports for it.
  ///
  /// "enabled" is the one on the home screen, "default" follows the manifest,
  /// "disabled" was switched off. Logged before a request and at launch.
  static Future<Map<String, String>> state() async {
    try {
      final Map<Object?, Object?>? raw = await _diagnostics
          .invokeMethod<Map<Object?, Object?>>('state');
      if (raw == null) {
        return const <String, String>{};
      }
      return <String, String>{
        for (final MapEntry<Object?, Object?> entry in raw.entries)
          entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  /// Queues [alias]. The plugin applies it when the task leaves recents, which
  /// is what makes the home screen redraw.
  static Future<bool> apply(String alias) async {
    final String? live = await current();
    debugPrint('[icon] request=$alias · live=$live · ${await state()}');
    try {
      await FlutterDynamicIconPlus.setAlternateIconName(
        iconName: alias == AppIconOption.defaultAlias ? null : alias,
      );
      debugPrint('[icon] queued $alias; applied when the task leaves recents');
      return true;
    } catch (error) {
      debugPrint('[icon] the plugin refused $alias: $error');
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
  /// APK is replaced. And a request that never reached the service — the
  /// process can be killed before the task is removed — would otherwise be
  /// lost for good. Queueing it again costs one call and heals both.
  ///
  /// Returns true when a swap was queued.
  static Future<bool> reconcile(SharedPreferences prefs) async {
    final String wanted = remembered(prefs);
    final String live = await current() ?? AppIconOption.defaultAlias;
    if (live == wanted) {
      debugPrint('[icon] launch · live=$live matches the choice');
      return false;
    }
    debugPrint(
      '[icon] launch · wanted=$wanted live=$live · ${await state()} · re-queueing',
    );
    return apply(wanted);
  }
}
