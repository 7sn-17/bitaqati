import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
/// The work is done by the app itself, in MainActivity: the aliases are enabled
/// and disabled directly through the package manager. A plugin was tried first
/// and removed — it deferred the swap to a service that waits for the task to
/// be removed from recents, so a user who pressed Home and came back never got
/// the new icon. There is no library between this call and the platform now,
/// which is also why a device that refuses the change can be reported honestly
/// instead of guessed at.
///
/// Every call is wrapped: a device whose launcher ignores aliases, or a build
/// whose manifest is missing one, must never take the settings screen down. The
/// caller gets a bool and shows a quiet message.
abstract final class DynamicIconService {
  static const MethodChannel _channel = MethodChannel('com.bitaqati.app/icon');

  /// Whether this build can change its icon at all: every alias has to be
  /// declared, and the platform channel has to answer.
  static Future<bool> get supported async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// The alias currently enabled, as a bare name, or null when it cannot be
  /// read.
  static Future<String?> current() async {
    try {
      final String? name = await _channel.invokeMethod<String>('currentAlias');
      return name == null || name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// Applies [alias] now and reports whether the package manager took it.
  ///
  /// [restart] hands the screen to the launcher and drops this process once the
  /// swap is verified. That is what makes the home screen redraw: a launcher
  /// with a live task for this package keeps the icon it already has, so the
  /// change stays invisible until the app has no task left to return to. The
  /// reconcile pass at startup leaves it false — closing the app the user just
  /// opened would be worse than a stale icon.
  static Future<bool> apply(String alias, {bool restart = false}) async {
    try {
      final String? applied = await _channel.invokeMethod<String>(
        'setAlias',
        <String, Object?>{'alias': alias, 'restart': restart},
      );
      return applied != null;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Every alias and the state the package manager reports for it.
  ///
  /// Diagnostics only: "enabled" is the one on the home screen, "default"
  /// follows the manifest, "disabled" was switched off by this app. A read of
  /// this before and after a change is the difference between "the launcher
  /// ignored us" and "the swap never happened".
  static Future<Map<String, String>> state() async {
    try {
      final Map<Object?, Object?>? raw = await _channel
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
    debugPrint('[icon] launcher drifted · wanted=$wanted live=$live');
    return apply(wanted);
  }
}
