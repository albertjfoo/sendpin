package app.sendpin

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
    private const val KEY_STATUS_AT = "statusAt"
    private const val KEY_LAST_DESTINATION = "lastDestination"
    private const val KEY_LAST_DESTINATION_AT = "lastDestinationAt"
    private const val KEY_LAST_LAT = "lastLat"
    private const val KEY_LAST_LNG = "lastLng"
    private const val KEY_PAIRED_PHONE = "pairedPhone"

    fun of(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /** Whether the extension should be listening. Defaults on. */
    fun isEnabled(context: Context): Boolean =
        of(context).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        of(context).edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    // Status values the watcher reports. Constants rather than literals because
    // the watcher writes them and the screen matches on them, in different files.
    const val STATUS_LISTENING = "listening"
    const val STATUS_WAITING = "waiting for Bluetooth"
    const val STATUS_OFF = "off"

    /**
     * How long the watcher's note stays believable.
     *
     * The watcher rewrites its status every pass, and an idle pass is bounded by
     * ADAPTER_RECHECK_MS (15s), so a healthy watcher refreshes well inside this.
     * Three times that leaves room for a slow pass without ever calling a live
     * watcher dead.
     */
    private const val STATUS_STALE_MS = 45_000L

    /**
     * What the watcher last reported, or null if it has gone quiet.
     *
     * Null matters as much as the value. The watcher is a separate service the
     * system can stop whenever it likes, and a stopped one leaves its last note
     * frozen in place — without the timestamp the screen would happily show
     * "listening" from a process that died an hour ago. Callers should treat
     * null as "no information" and fall back to what they can check themselves.
     */
    fun status(context: Context): String? {
        val prefs = of(context)
        val writtenAt = prefs.getLong(KEY_STATUS_AT, 0L)
        if (writtenAt == 0L) return null
        val age = System.currentTimeMillis() - writtenAt
        // Also rejects a note from the future, which a clock change can produce.
        if (age !in 0..STATUS_STALE_MS) return null
        return prefs.getString(KEY_STATUS, null)
    }

    /** Called on every watcher pass, so the timestamp doubles as a heartbeat. */
    fun setStatus(context: Context, status: String) {
        of(context).edit()
            .putString(KEY_STATUS, status)
            .putLong(KEY_STATUS_AT, System.currentTimeMillis())
            .apply()
    }

    /** The last pin received: name, coordinates, and when. Enough to re-open it. */
    data class LastPin(val name: String, val lat: Double, val lng: Double, val at: Long)

    fun lastPin(context: Context): LastPin? {
        val p = of(context)
        val name = p.getString(KEY_LAST_DESTINATION, null) ?: return null
        // Older records stored only a name; without coordinates there is
        // nothing to re-open, so treat them as absent for the navigate button.
        if (!p.contains(KEY_LAST_LAT)) return null
        return LastPin(
            name = name,
            lat = Double.fromBits(p.getLong(KEY_LAST_LAT, 0L)),
            lng = Double.fromBits(p.getLong(KEY_LAST_LNG, 0L)),
            at = p.getLong(KEY_LAST_DESTINATION_AT, 0L),
        )
    }

    fun setLastPin(context: Context, name: String, lat: Double, lng: Double) {
        of(context).edit()
            .putString(KEY_LAST_DESTINATION, name)
            // Doubles have no SharedPreferences type; the raw bits round-trip
            // exactly through a Long, where toString/parse would not.
            .putLong(KEY_LAST_LAT, lat.toRawBits())
            .putLong(KEY_LAST_LNG, lng.toRawBits())
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
