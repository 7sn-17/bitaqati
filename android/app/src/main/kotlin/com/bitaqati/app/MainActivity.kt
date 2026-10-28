package com.bitaqati.app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the launcher icon.
 *
 * flutter_dynamic_icon_plus does not apply a change when it is called: it hands
 * the swap to a service and waits for onTaskRemoved, because disabling the
 * alias that hosts a running task makes some launchers close the app. That is
 * why the picker looked like it worked — the app redrew with the new preview —
 * while the home screen kept the old icon. Pressing Home and coming back from
 * recents never removes the task, so the swap was never applied.
 *
 * Here the alias is flipped directly, with DONT_KILL_APP so the process is not
 * torn down, and the new alias is enabled before the old one is disabled so the
 * package is never without a launcher entry. The package manager broadcasts the
 * component change and launchers re-read the icon on their own.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.bitaqati.app/icon"
    private val aliases = listOf("DEFAULT", "CrownIcon", "BlueIcon")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAlias" -> {
                        val alias = call.argument<String>("alias")
                        if (alias == null || !aliases.contains(alias)) {
                            result.error(
                                "unknown_alias",
                                "No launcher alias named " + alias,
                                null,
                            )
                        } else {
                            result.success(applyAlias(alias))
                        }
                    }

                    "supported" -> result.success(supported())
                    "currentAlias" -> result.success(currentAlias())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * True when every alias this build expects is declared in the manifest.
     *
     * A build whose resources are missing one of them cannot switch icons at
     * all, and the picker says so instead of offering a button that fails.
     */
    private fun supported(): Boolean = aliases.all { component(it) != null }

    /**
     * Enables [alias], then disables the others. Returns the alias that is on,
     * or null when the package manager refused the change.
     */
    private fun applyAlias(alias: String): String? {
        return try {
            val target = component(alias) ?: return null
            packageManager.setComponentEnabledSetting(
                target,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP,
            )
            for (name in aliases) {
                if (name == alias) {
                    continue
                }
                val other = component(name) ?: continue
                packageManager.setComponentEnabledSetting(
                    other,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
            alias
        } catch (error: Exception) {
            null
        }
    }

    /**
     * The alias currently enabled, or null when none is. A component left at
     * COMPONENT_ENABLED_STATE_DEFAULT follows the manifest, which enables
     * DEFAULT and nothing else.
     */
    private fun currentAlias(): String? {
        var fallback: String? = null
        for (name in aliases) {
            val declared = component(name) ?: continue
            when (packageManager.getComponentEnabledSetting(declared)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> return name
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT ->
                    if (name == "DEFAULT") {
                        fallback = name
                    }
            }
        }
        return fallback
    }

    /** The alias as a component, or null when the manifest does not declare it. */
    private fun component(alias: String): ComponentName? {
        val name = ComponentName(this, packageName + "." + alias)
        return try {
            packageManager.getActivityInfo(name, 0)
            name
        } catch (error: PackageManager.NameNotFoundException) {
            null
        }
    }
}
