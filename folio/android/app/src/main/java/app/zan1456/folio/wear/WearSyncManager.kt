package hu.ekrata.ellenorzoplusz.wear

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.MethodChannel

/**
 * Handles all Wearable Data Layer communication from the phone side.
 *
 * Responsibilities:
 *  - Send timetable JSON to watch  (/folio/timetable)
 *  - Send notifications JSON to watch (/folio/notifications)
 *  - Cache latest data in SharedPreferences (used by WorkManager for morning sync)
 *  - Listen for sync requests from the watch
 *  - Report connection status back to Flutter
 */
class WearSyncManager(
    private val context: Context,
    private val flutterChannel: MethodChannel
) {

    private val TAG = "FolioPhone.WearSync"
    private val prefs: SharedPreferences =
        context.getSharedPreferences("folio_wear_phone", Context.MODE_PRIVATE)

    // ── Connection ───────────────────────────────────────────────────────────

    fun checkConnection() {
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                val connected = nodes.isNotEmpty()
                Log.d(TAG, "checkConnection: connected=$connected nodes=${nodes.size}")
                nodes.forEach { Log.d(TAG, "  node id=${it.id} name=${it.displayName} nearby=${it.isNearby}") }
                prefs.edit().putBoolean("connected", connected).apply()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    flutterChannel.invokeMethod("onConnectionChanged", connected)
                }
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "checkConnection FAILED: ${e.message}", e)
            }
    }

    fun isConnected(): Boolean = prefs.getBoolean("connected", false)

    // ── Sending data to watch ────────────────────────────────────────────────

    /**
     * Sends timetable JSON to the watch via Wearable Data Layer.
     * The DataItem is keyed by path so the watch always gets the latest version.
     */
    fun sendTimetable(json: String) {
        prefs.edit().putString("timetable", json).apply()
        Log.d(TAG, "sendTimetable: ${json.length} chars")
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                Log.d(TAG, "sendTimetable: ${nodes.size} node(s)")
                for (node in nodes) {
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/folio/timetable", json.toByteArray(Charsets.UTF_8))
                        .addOnSuccessListener { Log.d(TAG, "sendTimetable OK to ${node.id}") }
                        .addOnFailureListener { e -> Log.e(TAG, "sendTimetable FAILED to ${node.id}: ${e.message}", e) }
                }
            }
            .addOnFailureListener { e -> Log.e(TAG, "sendTimetable: getNodes FAILED: ${e.message}", e) }
    }

    /**
     * Sends the top-10 notifications JSON to the watch.
     */
    fun sendNotifications(json: String) {
        prefs.edit().putString("notifications", json).apply()
        Log.d(TAG, "sendNotifications: ${json.length} chars")
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                Log.d(TAG, "sendNotifications: ${nodes.size} node(s)")
                for (node in nodes) {
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/folio/notifications", json.toByteArray(Charsets.UTF_8))
                        .addOnSuccessListener { Log.d(TAG, "sendNotifications OK to ${node.id}") }
                        .addOnFailureListener { e -> Log.e(TAG, "sendNotifications FAILED to ${node.id}: ${e.message}", e) }
                }
            }
            .addOnFailureListener { e -> Log.e(TAG, "sendNotifications: getNodes FAILED: ${e.message}", e) }
    }

    /**
     * Reads cached data from SharedPreferences and pushes it to the watch.
     * Used by [WearMorningSyncWorker] without needing the Flutter engine.
     */
    fun sendCachedData() {
        val timetable = prefs.getString("timetable", null)
        val notifications = prefs.getString("notifications", null)
        timetable?.let { sendTimetable(it) }
        notifications?.let { sendNotifications(it) }
    }

    // ── Morning sync scheduling ──────────────────────────────────────────────

    fun scheduleMorningSync() {
        WearMorningSyncWorker.schedule(context)
    }

    // ── Settings ─────────────────────────────────────────────────────────────

    fun setSyncEnabled(enabled: Boolean) {
        prefs.edit().putBoolean("sync_enabled", enabled).apply()
        if (!enabled) {
            WearMorningSyncWorker.cancel(context)
        } else {
            scheduleMorningSync()
        }
    }

    fun getSyncEnabled(): Boolean = prefs.getBoolean("sync_enabled", true)

    // ── Pairing ───────────────────────────────────────────────────────────────

    /** Sends the pairing confirmation code to the watch. */
    fun sendPairConfirm(code: String) {
        Log.d(TAG, "sendPairConfirm: code=$code")
        Wearable.getNodeClient(context).connectedNodes
            .addOnSuccessListener { nodes ->
                for (node in nodes) {
                    Wearable.getMessageClient(context)
                        .sendMessage(node.id, "/folio/pair-confirm", code.toByteArray(Charsets.UTF_8))
                        .addOnSuccessListener { Log.d(TAG, "sendPairConfirm OK to ${node.id}") }
                        .addOnFailureListener { e -> Log.e(TAG, "sendPairConfirm FAILED: ${e.message}") }
                }
            }
            .addOnFailureListener { e -> Log.e(TAG, "sendPairConfirm: getNodes FAILED: ${e.message}") }
    }
}
