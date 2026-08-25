package app.sendpin

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONObject
import java.util.UUID

/**
 * Finds the iPhone and reads one waypoint off it.
 *
 * Deliberately built on the raw Android BLE APIs rather than a wrapper. Three
 * behaviours have to be exact, and all three were learned the hard way on
 * 2026-08-06 by driving nRF Connect by hand against this same peripheral:
 *
 *  1. **Never bond.** Nothing served requires encryption. A bond attempt wedged
 *     the Karoo's Bluetooth stack badly enough to need the process restarted,
 *     because iOS rotated its address mid-pairing.
 *  2. **Never reuse an address.** iOS rotates its resolvable private address
 *     roughly every 15 minutes; it was observed changing mid-test. The address
 *     is used once, immediately, and never stored.
 *  3. **Connect the instant the scan matches.** A scan result minutes old points
 *     at an address that no longer exists. Discovery against it hangs forever
 *     rather than failing, which is how it presents.
 *
 * See PROTOCOL.md for the wire contract and RISKS.md R6 for the address story.
 */
class WaypointClient(private val context: Context) {

    data class Waypoint(val lat: Double, val lng: Double, val name: String?, val id: String? = null)

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE)
            as? android.bluetooth.BluetoothManager)?.adapter

    /**
     * Whether the radio is actually usable right now.
     *
     * On the Karoo this is not a given even after RequestBluetooth: the
     * coordinator turns the adapter off the instant its client list empties,
     * so this can flip to false underneath a running watcher.
     */
    fun isAdapterOn(): Boolean = adapter?.isEnabled == true

    /**
     * Scan for the phone, connect, read the waypoint, disconnect.
     * Returns null if the phone was never seen or the payload was unusable.
     *
     * @param timeoutMs how long to wait for an advertisement, or null to wait
     *   indefinitely. The extension passes null: the phone advertising IS the
     *   trigger, so there is nothing to time out against.
     */
    @SuppressLint("MissingPermission")
    suspend fun fetch(timeoutMs: Long? = SCAN_TIMEOUT_MS): Waypoint? {
        val adapter = adapter
        if (adapter == null || !adapter.isEnabled) {
            // Almost always means RequestBluetooth was not dispatched, or the
            // coordinator revoked the claim. See RISKS.md R2.
            Log.w(TAG, "bluetooth adapter unavailable or off")
            return null
        }

        suspend fun run(): Waypoint? {
            val device = scanForPeripheral(adapter)
            Log.i(TAG, "matched peripheral, connecting immediately")
            return readWaypoint(device)
        }

        return try {
            if (timeoutMs == null) run() else withTimeout(timeoutMs) { run() }
        } catch (e: TimeoutCancellationException) {
            Log.w(TAG, "timed out after ${timeoutMs}ms — is the app foregrounded on the phone?")
            null
        } catch (e: Exception) {
            Log.e(TAG, "fetch failed", e)
            null
        }
    }

    /** Resolves with the first advertiser carrying our service UUID. */
    @SuppressLint("MissingPermission")
    private suspend fun scanForPeripheral(adapter: BluetoothAdapter): android.bluetooth.BluetoothDevice {
        val scanner = adapter.bluetoothLeScanner
            ?: error("no BLE scanner — adapter off?")
        val found = CompletableDeferred<android.bluetooth.BluetoothDevice>()

        // Filtering by service UUID in the scan filter is the whole design: it
        // is the only identifier that survives the phone's address rotation.
        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(WAYPOINT_SERVICE))
            .build()

        // LOW_LATENCY because the phone only advertises while the user is
        // holding it, foregrounded. Seconds matter; battery does not.
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (found.isCompleted) return
                Log.i(TAG, "scan hit rssi=${result.rssi}")
                found.complete(result.device)
            }

            override fun onScanFailed(errorCode: Int) {
                found.completeExceptionally(IllegalStateException("scan failed: $errorCode"))
            }
        }

        scanner.startScan(listOf(filter), settings, callback)
        try {
            return found.await()
        } finally {
            // Stop scanning before connecting; scanning while connecting is
            // slow and flaky on older Android radios.
            runCatching { scanner.stopScan(callback) }
        }
    }

    /**
     * Start a scan and leave it running. Returns the callback needed to stop it.
     *
     * Long-lived on purpose. Android silently blocks an app that calls startScan
     * more than 5 times in 30 seconds, and repeated start/stop churn corrupted
     * this app's scanner registration outright — the stack began logging
     * "BtGatt.ContextMap: Context not found" and the extension went deaf while
     * still looking perfectly healthy. Observed 2026-08-06. Start once, keep it.
     */
    @SuppressLint("MissingPermission")
    fun startPersistentScan(onMatch: (android.bluetooth.BluetoothDevice) -> Unit): ScanCallback? {
        val scanner = adapter?.bluetoothLeScanner ?: return null
        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(WAYPOINT_SERVICE))
            .build()
        // LOW_POWER duty-cycles the radio at roughly 10%, against LOW_LATENCY's
        // continuous scanning. This scan runs for as long as the Karoo is
        // switched on, so duty cycle is the dominant battery cost of the whole
        // extension — and the ~3-5s it adds before a phone is spotted costs
        // nothing real, because the phone keeps advertising until the waypoint
        // is actually read. There is no race to win here.
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_POWER)
            .build()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                onMatch(result.device)
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "scan failed: $errorCode")
            }
        }
        return try {
            scanner.startScan(listOf(filter), settings, callback)
            Log.i(TAG, "persistent scan started")
            callback
        } catch (e: Exception) {
            Log.e(TAG, "could not start scan", e)
            null
        }
    }

    @SuppressLint("MissingPermission")
    fun stopScan(callback: ScanCallback) {
        runCatching { adapter?.bluetoothLeScanner?.stopScan(callback) }
    }

    /**
     * Read one waypoint from an already-discovered device. Never throws, and
     * always returns within [READ_TIMEOUT_MS].
     *
     * A failed connect is normal traffic, not an exceptional case: status 133
     * is Android's catch-all GATT error and shows up routinely on a first
     * attempt, especially when the peripheral has just started advertising.
     * The caller is a long-lived watcher, so a throw here would take the whole
     * extension down — which it did, once per failed connect, until this
     * existed.
     *
     * The timeout matters as much as the catch, and for a failure that does not
     * look like one. Point 3 in this file's header: a scan result whose address
     * iOS has since rotated does not fail, it *hangs* — connectGatt never calls
     * back at all. Without a deadline the watcher blocks here forever, the loop
     * never runs again, and the status line keeps showing whatever it last said.
     * The extension is then deaf while looking perfectly healthy on screen, and
     * only a toggle or a reboot brings it back. The timeout also unwinds through
     * readWaypoint's finally, so the BluetoothGatt is closed rather than leaked —
     * Android caps concurrent GATT clients, so leaks make every later connect
     * worse.
     */
    @SuppressLint("MissingPermission")
    suspend fun read(device: android.bluetooth.BluetoothDevice): Waypoint? =
        try {
            // withTimeoutOrNull rather than withTimeout: a timeout here means
            // "no usable waypoint", which is the same thing every other failure
            // in this function returns. Nothing downstream wants an exception.
            withTimeoutOrNull(READ_TIMEOUT_MS) { readWaypoint(device) }
        } catch (e: Exception) {
            Log.w(TAG, "read failed, will retry on next sighting: ${e.message}")
            null
        }

    @SuppressLint("MissingPermission")
    private suspend fun readWaypoint(device: android.bluetooth.BluetoothDevice): Waypoint? {
        val result = CompletableDeferred<ByteArray?>()
        var gatt: BluetoothGatt? = null

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    Log.i(TAG, "connected, requesting MTU")
                    // A larger MTU lets the ~72-byte payload arrive in a single
                    // read instead of a blob sequence. Android will fall back to
                    // blob reads by itself if the phone refuses, so this is an
                    // optimisation rather than a requirement.
                    if (!g.requestMtu(PREFERRED_MTU)) g.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    if (!result.isCompleted) {
                        result.completeExceptionally(
                            IllegalStateException("disconnected before read, status=$status"))
                    }
                }
            }

            override fun onMtuChanged(g: BluetoothGatt, mtu: Int, status: Int) {
                Log.i(TAG, "mtu=$mtu, discovering services")
                g.discoverServices()
            }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                val characteristic = g.getService(WAYPOINT_SERVICE)
                    ?.getCharacteristic(WAYPOINT_CHARACTERISTIC)
                if (characteristic == null) {
                    result.completeExceptionally(
                        IllegalStateException("waypoint characteristic missing (status=$status)"))
                    return
                }
                g.readCharacteristic(characteristic)
            }

            @Suppress("DEPRECATION")
            override fun onCharacteristicRead(
                g: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    result.complete(characteristic.value)
                } else {
                    result.completeExceptionally(
                        IllegalStateException("read failed, status=$status"))
                }
            }
        }

        return try {
            // autoConnect=false: connect now, against this address, once.
            gatt = device.connectGatt(context, false, callback)
            val bytes = result.await() ?: return null
            parse(bytes)
        } finally {
            runCatching {
                gatt?.disconnect()
                gatt?.close()
            }
        }
    }

    /** Rejects anything it cannot fully trust — a partial parse would navigate you somewhere wrong. */
    private fun parse(bytes: ByteArray): Waypoint? {
        // trimEnd('\u0000') as an escape, never a raw NUL byte: a literal
        // control character in source makes the file read as binary to grep,
        // diff and review, so nobody can see what is being trimmed.
        val text = bytes.toString(Charsets.UTF_8).trim().trimEnd('\u0000')
        return try {
            val json = JSONObject(text)
            val lat = json.getDouble("lat")
            val lng = json.getDouble("lng")
            if (lat !in -90.0..90.0 || lng !in -180.0..180.0) {
                Log.w(TAG, "coordinates out of range: $lat,$lng")
                return null
            }
            val name = json.optString("name").takeIf { it.isNotBlank() }
            // The sending phone's ID, absent on pre-pairing app versions.
            val id = json.optString("id").takeIf { it.isNotBlank() }
            Waypoint(lat, lng, name, id).also { Log.i(TAG, "parsed $it") }
        } catch (e: Exception) {
            Log.e(TAG, "unparseable payload: '$text'", e)
            null
        }
    }

    companion object {
        private const val TAG = "SendPin"
        private const val PREFERRED_MTU = 185
        private const val SCAN_TIMEOUT_MS = 20_000L

        /**
         * Ceiling on one connect → MTU → discover → read round trip.
         *
         * Generous rather than tight: on this Android 8.1 radio a first attempt
         * that eventually succeeds has been seen to take several seconds, and a
         * deadline that fires on a slow-but-working read would turn a delivered
         * pin into a dropped one. The job here is only to break an infinite
         * hang, so seconds of slack cost nothing.
         */
        private const val READ_TIMEOUT_MS = 15_000L

        // Must match ios/SendPin/SendPinPeripheral.swift — see PROTOCOL.md.
        val WAYPOINT_SERVICE: UUID = UUID.fromString("4B027EEA-0001-45A6-AB37-310A7471C7DC")
        val WAYPOINT_CHARACTERISTIC: UUID = UUID.fromString("4B027EEA-0002-45A6-AB37-310A7471C7DC")
    }
}
