package com.albert.karoosend

import android.util.Log
import io.hammerhead.karooext.KarooSystemService
import io.hammerhead.karooext.extension.KarooExtension
import io.hammerhead.karooext.models.InRideAlert
import io.hammerhead.karooext.models.LaunchPinDrop
import io.hammerhead.karooext.models.PlayBeepPattern
import io.hammerhead.karooext.models.ReleaseBluetooth
import io.hammerhead.karooext.models.RequestBluetooth
import io.hammerhead.karooext.models.Symbol
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Receives a destination from the iPhone over BLE and hands it to the Karoo's
 * own navigation.
 *
 * Flow, triggered by the "Get destination from phone" bonus action:
 *
 *   RequestBluetooth -> scan by service UUID -> connect -> read {lat,lng,name}
 *   -> Symbol.POI -> LaunchPinDrop -> (radio released on destroy)
 *
 * Every effect used here was confirmed present in this Karoo's own firmware on
 * 2026-08-06 by searching io.hammerhead.appstore's dex — see RISKS.md.
 */
class KarooSendExtension : KarooExtension(EXTENSION_ID, "0.1") {

    private lateinit var karooSystem: KarooSystemService
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var inFlight: Job? = null

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
            }
        }
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
        inFlight = scope.launch { fetchAndNavigate() }
    }

    private suspend fun fetchAndNavigate() {
        val waypoint = WaypointClient(applicationContext).fetch()

        if (waypoint == null) {
            // The overwhelmingly likely cause is the phone not advertising:
            // iOS hides the service UUID from non-Apple devices the moment the
            // app backgrounds (RISKS.md R3). Say so rather than "failed".
            alert("No destination found", "Open KarooSend on your phone and keep it on screen.")
            return
        }

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
    }
}
