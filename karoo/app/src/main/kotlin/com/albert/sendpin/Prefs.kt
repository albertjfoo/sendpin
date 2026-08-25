package com.albert.sendpin

import android.content.Context
import android.content.SharedPreferences

/**
 * The only channel between the settings screen and the extension service.
 *
 * They run in the same process today, but nothing guarantees that — the system
 * binds the service on its own schedule and the activity may be gone. Shared
 * preferences survive both, so state is written here rather than held in memory.
 */
object Prefs {
    private const val FILE = "sendpin"

    private const val KEY_ENABLED = "enabled"
    private const val KEY_STATUS = "status"
    private const val KEY_LAST_DESTINATION = "lastDestination"
    private const val KEY_LAST_DESTINATION_AT = "lastDestinationAt"
    private const val KEY_PAIRED_PHONE = "pairedPhone"

    fun of(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /** Whether the extension should be listening. Defaults on. */
    fun isEnabled(context: Context): Boolean =
        of(context).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        of(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    /** A short line the watcher keeps current, so the screen can show what it is doing. */
    fun status(context: Context): String =
        of(context).getString(KEY_STATUS, "not started") ?: "not started"

    fun setStatus(context: Context, status: String) {
        of(context).edit().putString(KEY_STATUS, status).apply()
    }

    fun lastDestination(context: Context): Pair<String, Long>? {
        val name = of(context).getString(KEY_LAST_DESTINATION, null) ?: return null
        return name to of(context).getLong(KEY_LAST_DESTINATION_AT, 0L)
    }

    fun setLastDestination(context: Context, description: String) {
        of(context).edit()
            .putString(KEY_LAST_DESTINATION, description)
            .putLong(KEY_LAST_DESTINATION_AT, System.currentTimeMillis())
            .apply()
    }

    /**
     * The one phone this Karoo accepts pins from.
     *
     * The extension pairs to the first phone it hears and stores its ID here;
     * every other phone is then ignored, so two SendPin users near each other
     * do not cross pins. Null means unpaired -- the next phone heard becomes the
     * pair, which is also what "Forget iPhone" resets it to.
     */
    fun pairedPhone(context: Context): String? =
        of(context).getString(KEY_PAIRED_PHONE, null)

    fun setPairedPhone(context: Context, id: String) {
        of(context).edit().putString(KEY_PAIRED_PHONE, id).apply()
    }

    fun clearPairedPhone(context: Context) {
        of(context).edit().remove(KEY_PAIRED_PHONE).apply()
    }
}
