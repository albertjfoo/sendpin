package com.albert.karoosend

import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanCallback
import android.util.Log
import io.hammerhead.karooext.KarooSystemService
import io.hammerhead.karooext.extension.KarooExtension
import io.hammerhead.karooext.models.InRideAlert
import io.hammerhead.karooext.models.LaunchPinDrop
import io.hammerhead.karooext.models.PlayBeepPattern
import io.hammerhead.karooext.models.ReleaseBluetooth
import io.hammerhead.karooext.models.RequestBluetooth
import io.hammerhead.karooext.models.Symbol
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Receives a destination from the iPhone over BLE and hands it to the Karoo's
 * own navigation.
 *
 * The trigger is the phone, not the head unit. Sending is meant to feel like a
 * push from your pocket, so the extension scans continuously and reacts on its
 * own; nothing is touched on the Karoo to start a transfer.
 *
 *   RequestBluetooth -> watch by service UUID -> connect -> read {lat,lng,name}
 *   -> Symbol.POI -> LaunchPinDrop -> (radio released on destroy)
 *
 * The "Get destination from phone" bonus action is only a manual retry for when
 * the automatic path has not fired.
 *
 * Every effect used here was confirmed present in this Karoo's own firmware on
 * 2026-08-06 by searching io.hammerhead.appstore's dex — see RISKS.md.
 */
class KarooSendExtension : KarooExtension(EXTENSION_ID, "0.1") {

    private lateinit var karooSystem: KarooSystemService
    // SupervisorJob alone does not save the process: an exception escaping a
    // launched coroutine still reaches the default handler and kills it. This
    // extension is meant to sit watching for hours, so anything unforeseen
    // should be logged and survived rather than fatal.
    private val crashGuard = CoroutineExceptionHandler { _, e ->
        Log.e(TAG, "watcher coroutine failed, extension stays alive", e)
    }
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob() + crashGuard)
    private var inFlight: Job? = null
    private var watcher: Job? = null
    private var lastWaypoint: WaypointClient.Waypoint? = null
    private var lastWaypointAt = 0L

    override fun onCreate() {
        super.onCreate()
        // Logged unconditionally and before anything can fail. Without this,
        // silence in logcat cannot distinguish "service never created" from
        // "created, but KarooSystemService never called back" — which cost a
        // debugging round on 2026-08-06.
        Log.i(TAG, "extension onCreate, id=$extension")
        karooSystem = KarooSystemService(applicationContext)
        karooSystem.connect { connected ->
            Log.i(TAG, "karoo system connected=$connected")
            if (connected) {
                // Mandatory, not defensive. The coordinator revokes any radio
                // claim it does not recognise within ~4 seconds — watched live
                // on 2026-08-06 while nRF Connect tried and failed to hold it.
                // Without this the scan below finds nothing, because the
                // adapter is switched off underneath it.
                karooSystem.dispatch(RequestBluetooth(extension))
                startWatching()
            }
        }
    }

    /**
     * The product's actual trigger: the phone advertising.
     *
     * The Karoo cannot be woken by the phone, so to make sending feel like a
     * push the extension has to already be looking. It scans continuously for
     * the whole time it is alive, so a send from the phone lands here within a
     * second or two with nothing touched on the head unit.
     */
    private fun startWatching() {
        if (watcher?.isActive == true) return
        watcher = scope.launch {
            Log.i(TAG, "watching for waypoints")
            val client = WaypointClient(applicationContext)
            // CONFLATED: the phone advertises many times a second while its
            // screen is on. Only the most recent sighting is worth acting on.
            val sightings = Channel<BluetoothDevice>(Channel.CONFLATED)
            var scan: ScanCallback? = null
            try {
                while (isActive) {
                    // The claim does not stick forever. Observed 2026-08-06: the
                    // coordinator emptied its client list and switched the adapter
                    // off mid-run. Re-assert rather than busy-fail, and drop the
                    // scan first so it is restarted cleanly against a live radio.
                    if (!client.isAdapterOn()) {
                        Log.w(TAG, "adapter off — re-requesting bluetooth")
                        scan?.let { client.stopScan(it) }
                        scan = null
                        karooSystem.dispatch(RequestBluetooth(extension))
                        delay(RADIO_RETRY_MS)
                        continue
                    }

                    if (scan == null) {
                        scan = client.startPersistentScan { sightings.trySend(it) }
                        if (scan == null) {
                            delay(RADIO_RETRY_MS)
                            continue
                        }
                    }

                    // Wake periodically even with nothing in sight, so a radio
                    // that died underneath us is noticed by the check above.
                    val device = withTimeoutOrNull(ADAPTER_RECHECK_MS) { sightings.receive() }
                        ?: continue

                    val waypoint = client.read(device)
                    if (waypoint != null && !isDuplicate(waypoint)) {
                        navigateTo(waypoint)
                    }
                    // Settle before acting on the next sighting. The scan itself
                    // keeps running throughout — it is never restarted here.
                    delay(RESCAN_DELAY_MS)
                }
            } finally {
                scan?.let { client.stopScan(it) }
            }
        }
    }

    /**
     * The phone keeps advertising after a send, so the same waypoint would
     * otherwise be picked up over and over and re-open the pin drop. Ignore an
     * identical destination for a cooldown; re-sending the same place after
     * that still works.
     */
    private fun isDuplicate(waypoint: WaypointClient.Waypoint): Boolean {
        val now = System.currentTimeMillis()
        val same = waypoint == lastWaypoint && now - lastWaypointAt < DUPLICATE_WINDOW_MS
        if (same) {
            Log.i(TAG, "ignoring repeat of $waypoint")
        } else {
            lastWaypoint = waypoint
            lastWaypointAt = now
        }
        return same
    }

    override fun onBonusAction(actionId: String) {
        if (actionId != ACTION_FETCH) {
            Log.w(TAG, "unknown action $actionId")
            return
        }
        // Ignore a second tap while one fetch is already running; two
        // concurrent scans on this radio just make both slower.
        if (inFlight?.isActive == true) {
            Log.i(TAG, "fetch already in progress")
            return
        }
        inFlight = scope.launch { fetchOnce() }
    }

    /** Manual fallback for the bonus action; the normal path is startWatching(). */
    private suspend fun fetchOnce() {
        val waypoint = WaypointClient(applicationContext).fetch()

        if (waypoint == null) {
            // The overwhelmingly likely cause is the phone not advertising:
            // iOS hides the service UUID from non-Apple devices the moment the
            // app backgrounds (RISKS.md R3). Say so rather than "failed".
            alert("No destination found", "Open KarooSend on your phone and keep it on screen.")
            return
        }
        navigateTo(waypoint)
    }

    private fun navigateTo(waypoint: WaypointClient.Waypoint) {
        val poi = Symbol.POI(
            id = "karoo2send-${System.currentTimeMillis()}",
            lat = waypoint.lat,
            lng = waypoint.lng,
            name = waypoint.name,
        )
        Log.i(TAG, "dispatching LaunchPinDrop for $poi")
        karooSystem.dispatch(LaunchPinDrop(poi))

        // Audible confirmation so the destination can be sent without staring
        // at the head unit.
        karooSystem.dispatch(
            PlayBeepPattern(
                listOf(
                    PlayBeepPattern.Tone(1_000, 150),
                    PlayBeepPattern.Tone(1_400, 150),
                ),
            ),
        )
    }

    private fun alert(title: String, detail: String) {
        Log.w(TAG, "$title — $detail")
        karooSystem.dispatch(
            InRideAlert(
                id = "karoo2send-${System.currentTimeMillis()}",
                icon = R.drawable.ic_karoosend,
                title = title,
                detail = detail,
                autoDismissMs = 6_000L,
                backgroundColor = -1,
                textColor = -1,
            ),
        )
    }

    override fun onDestroy() {
        watcher?.cancel()
        inFlight?.cancel()
        // Hand the radio back. Holding it for a whole ride would cost battery
        // for a feature used once or twice.
        karooSystem.dispatch(ReleaseBluetooth(extension))
        karooSystem.disconnect()
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "KarooSend"
        private const val EXTENSION_ID = "karoo2send"
        private const val ACTION_FETCH = "fetch"
        private const val RESCAN_DELAY_MS = 2_000L
        private const val DUPLICATE_WINDOW_MS = 120_000L
        private const val RADIO_RETRY_MS = 10_000L
        private const val ADAPTER_RECHECK_MS = 15_000L
    }
}
