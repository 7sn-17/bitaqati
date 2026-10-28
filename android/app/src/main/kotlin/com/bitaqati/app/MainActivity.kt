package com.bitaqati.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the launcher icon.
 *
 * The switch itself is a package-manager call: enable the alias that carries
 * the icon, disable the other two. When that call happens is the whole problem.
 *
 * A launcher resolves a package's icon when the package changes, and several of
 * them — MIUI, One UI, anything derived from Launcher3 with a cache — only
 * re-read it once the app has left the foreground. Flipping the alias while the
 * user is looking at the app therefore changes nothing they can see, and on
 * some launchers it finishes the task outright, which reads as "the app closed
 * and the icon stayed the same".
 *
 * So the swap is queued and applied in onStop, at the moment the app leaves the
 * screen. By then the launcher has resumed, the component change arrives while
 * it is in front, and it redraws. That is also the behaviour of the icon
 * plugins that work — flutter_dynamic_launcher_icon documents the same deferral
 * — and it is why the old plugin version looked like it changed the icon
 * "without closing the app": the swap ran after the user had already left.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.bitaqati.app/icon"
    private val aliases = listOf("DEFAULT", "CrownIcon", "BlueIcon")
    private val tag = "BitaqatiIcon"
    private val prefsName = "bitaqati_icon"
    private val pendingKey = "pending_alias"

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
                            result.success(queue(alias))
                        }
                    }

                    "supported" -> result.success(supported())
                    "currentAlias" -> result.success(currentAlias())
                    "pendingAlias" -> result.success(pending())
                    "state" -> result.success(state())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * The swap runs when the app leaves the screen, and this is where it
     * happens: onStop is delivered after the launcher has resumed, so the
     * component change is announced while the home screen is in front of the
     * user.
     */
    override fun onStop() {
        super.onStop()
        applyPending()
    }

    /**
     * Remembers [alias] and reports it back. Nothing is enabled or disabled
     * here — see the class comment for why applying it now would be invisible.
     */
    private fun queue(alias: String): String? {
        if (component(alias) == null) {
            Log.w(tag, "alias " + alias + " is not declared in this build")
            return null
        }
        val current = currentAlias()
        Log.i(tag, "queue " + alias + " · current=" + current + " · " + state())
        if (current == alias) {
            clearPending()
            return alias
        }
        prefs().edit().putString(pendingKey, alias).apply()
        Log.i(tag, "queued " + alias + "; it is applied when the app leaves the screen")
        return alias
    }

    /** Applies whatever was queued, and keeps it queued if the swap is refused. */
    private fun applyPending() {
        val target = pending()
        if (target == null) {
            return
        }
        val current = currentAlias()
        if (current == target) {
            clearPending()
            return
        }
        Log.i(tag, "applying queued " + target + " · was=" + current)
        val applied = applyAlias(target)
        if (applied == null) {
            Log.e(tag, "queued alias " + target + " was refused; kept for the next exit")
            return
        }
        clearPending()
        Log.i(tag, "applied " + applied + " · " + state())
    }

    /**
     * True when every alias this build expects is declared in the manifest.
     *
     * A build whose resources are missing one of them cannot switch icons at
     * all, and the picker says so instead of offering a button that fails.
     */
    private fun supported(): Boolean = aliases.all { component(it) != null }

    /**
     * Enables [alias], then disables the others, then reads the result back.
     *
     * The read-back is the part that matters: the package manager can accept a
     * call and still leave the component as it was, and reporting success on
     * the strength of "the call did not throw" is how the app told the user the
     * icon had changed when it had not.
     *
     * DONT_KILL_APP keeps the process alive through the swap. The alias this
     * task was started from is the one being disabled, and without the flag the
     * system would tear the process down halfway through, possibly before the
     * other aliases are disabled.
     */
    private fun applyAlias(alias: String): String? {
        val target = component(alias)
        if (target == null) {
            Log.w(tag, "alias " + alias + " is not declared in this build")
            return null
        }
        try {
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
        } catch (error: Exception) {
            Log.e(tag, "the package manager refused the swap", error)
            return null
        }

        val after = state()
        Log.i(tag, "after " + after)
        if (after[alias] != "enabled") {
            Log.e(tag, "alias " + alias + " did not enable; it reads " + after[alias])
            return null
        }
        for (name in aliases) {
            if (name != alias && after[name] == "enabled") {
                Log.w(tag, "alias " + name + " is still enabled beside " + alias)
            }
        }
        return alias
    }

    /**
     * The alias currently enabled, or null when none is. A component left at
     * COMPONENT_ENABLED_STATE_DEFAULT follows the manifest, which enables
     * DEFAULT and nothing else.
     */
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

    private fun pending(): String? {
        val value = prefs().getString(pendingKey, null)
        return if (value.isNullOrEmpty()) null else value
    }

    private fun clearPending() {
        prefs().edit().remove(pendingKey).apply()
    }

    private fun prefs() = getSharedPreferences(prefsName, Context.MODE_PRIVATE)

    /**
     * The activity names this package declares, enabled or not.
     *
     * getActivityInfo() answers only for components that are enabled, and two
     * of the three aliases are disabled by design. Asking it about them threw
     * NameNotFoundException, so every lookup failed and the app concluded that
     * the device could not change icons at all. The package listing is asked
     * instead, with disabled components included.
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
