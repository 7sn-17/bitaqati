package com.bitaqati.app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the launcher-icon state for the app. It does not change anything.
 *
 * The swap belongs to flutter_dynamic_icon_plus, whose service applies the
 * queued alias in onTaskRemoved — after the app has left recents, which is when
 * a launcher re-reads a package icon. Doing it from here, while the app is on
 * screen, is what left the home screen showing the old artwork through several
 * releases, so this class only answers questions: which alias is enabled, and
 * what does the package manager say about all three.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.bitaqati.app/icon"
    private val aliases = listOf("DEFAULT", "CrownIcon", "BlueIcon")
    private val tag = "BitaqatiIcon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "state" -> result.success(state())
                    "currentAlias" -> result.success(currentAlias())
                    "supported" -> result.success(aliases.all { component(it) != null })
                    else -> result.notImplemented()
                }
            }
    }

    /** The alias currently enabled, or null when none is. */
    private fun currentAlias(): String? {
        for (name in aliases) {
            if (stateName(name) == "enabled") {
                return name
            }
        }
        return if (stateName("DEFAULT") == "default") "DEFAULT" else null
    }

    /** Every alias and the state the package manager reports for it. */
    private fun state(): Map<String, String> {
        val result = LinkedHashMap<String, String>()
        for (name in aliases) {
            result[name] = stateName(name)
        }
        Log.d(tag, "state " + result)
        return result
    }

    private fun stateName(name: String): String {
        val entry = component(name) ?: return "missing"
        return try {
            when (packageManager.getComponentEnabledSetting(entry)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> "enabled"
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> "disabled"
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER -> "disabled_user"
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED ->
                    "disabled_until_used"
                else -> "default"
            }
        } catch (error: Exception) {
            Log.w(tag, "could not read the state of " + name, error)
            "unknown"
        }
    }

    /**
     * The activity names this package declares, enabled or not.
     *
     * getActivityInfo() answers only for components that are enabled, and two
     * of the three aliases are disabled by design. Asking it about them throws
     * NameNotFoundException, so the listing is asked for instead, with disabled
     * components included.
     */
    private val declared: Set<String> by lazy {
        try {
            val flags =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    PackageManager.GET_ACTIVITIES or
                        PackageManager.MATCH_DISABLED_COMPONENTS
                } else {
                    @Suppress("DEPRECATION")
                    PackageManager.GET_ACTIVITIES
                }
            packageManager
                .getPackageInfo(packageName, flags)
                .activities
                ?.map { it.name }
                ?.toSet()
                ?: emptySet()
        } catch (error: Exception) {
            emptySet()
        }
    }

    /** The alias as a component, or null when the manifest does not declare it. */
    private fun component(alias: String): ComponentName? {
        val name = ComponentName(this, packageName + "." + alias)
        return if (declared.contains(name.className)) name else null
    }
}
