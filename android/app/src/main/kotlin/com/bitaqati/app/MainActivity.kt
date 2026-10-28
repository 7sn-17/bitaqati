package com.bitaqati.app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the launcher icon.
 *
 * The swap itself is a package-manager call: enable the alias that carries the
 * icon, disable the other two, both with DONT_KILL_APP so the process is not
 * torn down halfway through and left with every alias disabled.
 *
 * What the package manager does not do is make the launcher redraw. The system
 * announces the component change, but a launcher that already has an entry for
 * this package keeps drawing the icon it read at install time until the app has
 * no live task to go back to. That is why the icon used to change inside the
 * app and nowhere else: the preview is Flutter's, the home screen is the
 * launcher's cache, and nothing ever invalidated it.
 *
 * So a change ends by handing the screen back to the launcher and dropping this
 * process. The next time the icon is resolved it is resolved from the alias
 * that is actually enabled.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.bitaqati.app/icon"
    private val aliases = listOf("DEFAULT", "CrownIcon", "BlueIcon")
    private val tag = "BitaqatiIcon"
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAlias" -> {
                        val alias = call.argument<String>("alias")
                        val restart = call.argument<Boolean>("restart") ?: false
                        if (alias == null || !aliases.contains(alias)) {
                            result.error(
                                "unknown_alias",
                                "No launcher alias named " + alias,
                                null,
                            )
                        } else {
                            result.success(applyAlias(alias, restart))
                        }
                    }

                    "supported" -> result.success(supported())
                    "currentAlias" -> result.success(currentAlias())
                    "state" -> result.success(state())
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
     * Enables [alias], then disables the others, then reads the result back.
     *
     * The read-back is the part that matters: the package manager can accept a
     * call and still leave the component as it was, and reporting success on
     * the strength of "the call did not throw" is how the app told the user the
     * icon had changed when it had not.
     *
     * [restart] hands the screen to the launcher and drops this process once
     * the swap is verified. It is false for the reconcile pass at startup,
     * which must never close the app the user just opened.
     */
    private fun applyAlias(alias: String, restart: Boolean): String? {
        val target = component(alias)
        if (target == null) {
            Log.w(tag, "alias " + alias + " is not declared in this build")
            return null
        }
        Log.i(tag, "before " + state())
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
        if (restart) {
            handOverToLauncher()
        }
        return alias
    }

    /**
     * Makes the launcher draw the new icon.
     *
     * ACTION_PACKAGE_CHANGED and ACTION_PACKAGE_RESTARTED are protected
     * broadcasts: only the system may send them, and an app that tries gets a
     * SecurityException. They are also already sent for us — the package
     * manager announces the component change on its own. The part that was
     * missing is that a launcher with a live task for this package keeps the
     * entry it already has.
     *
     * So: bring the home screen forward, so the launcher resumes and rebinds,
     * then remove the task and drop the process. On the next resolve there is
     * nothing left pointing at the old alias.
     */
    private fun handOverToLauncher() {
        Toast.makeText(this, "تم تغيير الأيقونة", Toast.LENGTH_SHORT).show()
        try {
            val home = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(home)
        } catch (error: Exception) {
            Log.w(tag, "could not bring the home screen forward", error)
        }
        main.postDelayed({
            Log.i(tag, "removing the task so the launcher re-reads the icon")
            try {
                finishAndRemoveTask()
            } catch (error: Exception) {
                Log.w(tag, "could not remove the task", error)
            }
            main.postDelayed({ Process.killProcess(Process.myPid()) }, 250)
        }, 700)
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
