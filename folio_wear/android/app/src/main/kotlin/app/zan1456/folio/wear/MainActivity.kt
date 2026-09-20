package hu.ekrata.ellenorzoplusz.wear

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import android.view.MotionEvent
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(),
    DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener {

    private val CHANNEL = "hu.ekrata.ellenorzoplusz.wear/data"
    private val TAG = "FolioWear.MainActivity"
    private val PREFS = "folio_wear"

    companion object {
        var methodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel!!.setMethodCallHandler { call, result ->
            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
            when (call.method) {

                "getCachedData" -> {
                    val timetable = prefs.getString("timetable", null)
                    val notifications = prefs.getString("notifications", null)
                    Log.d(TAG, "getCachedData: timetable=${timetable != null} notifications=${notifications != null}")
                    result.success(mapOf(
                        "timetable"    to timetable,
                        "notifications" to notifications,
                        "connected"    to WearConnectionHelper.isConnected,
                        "offlineMode"  to prefs.getBoolean("offline_mode", false),
                        "isPaired"     to prefs.getBoolean("is_paired", false),
                        "pairingCode"  to prefs.getString("pairing_code", "")
                    ))
                }

                "requestSync" -> {
                    Log.d(TAG, "requestSync from Flutter")
                    sendSyncRequestToPhone()
                    result.success(null)
                }

                "pullDataNow" -> {
                    Log.d(TAG, "pullDataNow from Flutter")
                    pullDataItems()
                    // Also re-push cached data from SharedPreferences
                    prefs.getString("timetable", null)?.let {
                        methodChannel?.invokeMethod("onTimetableReceived", it)
                    }
                    prefs.getString("notifications", null)?.let {
                        methodChannel?.invokeMethod("onNotificationsReceived", it)
                    }
                    result.success(null)
                }

                "setOfflineMode" -> {
                    val offline = call.arguments as Boolean
                    prefs.edit().putBoolean("offline_mode", offline).apply()
                    Log.d(TAG, "setOfflineMode: $offline")
                    result.success(null)
                }

                "setPairingCode" -> {
                    val code = call.arguments as String
                    prefs.edit().putString("pairing_code", code).apply()
                    Log.d(TAG, "setPairingCode: $code")
                    result.success(null)
                }

                "setIsPaired" -> {
                    val paired = call.arguments as Boolean
                    prefs.edit().putBoolean("is_paired", paired).apply()
                    Log.d(TAG, "setIsPaired: $paired")
                    result.success(null)
                }

                "sendPairingRequest" -> {
                    val code = call.arguments as String
                    Log.d(TAG, "sendPairingRequest: code=$code")
                    sendMessageToPhone("/folio/pair-request", code.toByteArray(Charsets.UTF_8))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume: registering listeners")
        Wearable.getDataClient(this).addListener(this)
        Wearable.getMessageClient(this).addListener(this)

        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                val connected = nodes.isNotEmpty()
                WearConnectionHelper.isConnected = connected
                Log.d(TAG, "onResume: connected=$connected")
                methodChannel?.invokeMethod("onConnectionChanged", connected)
            }
            .addOnFailureListener { e ->
                Log.e(TAG, "onResume connectedNodes FAILED: ${e.message}")
            }

        // Pull from Data Layer (fallback)
        pullDataItems()

        // Re-push cached data to Flutter
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        prefs.getString("timetable", null)?.let {
            methodChannel?.invokeMethod("onTimetableReceived", it)
        }
        prefs.getString("notifications", null)?.let {
            methodChannel?.invokeMethod("onNotificationsReceived", it)
        }
    }

    override fun onPause() {
        Wearable.getDataClient(this).removeListener(this)
        Wearable.getMessageClient(this).removeListener(this)
        super.onPause()
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val path = event.dataItem.uri.path ?: continue
            val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
            when (path) {
                "/folio/timetable" -> {
                    val json = dataMap.getString("json") ?: continue
                    saveAndForward("timetable", json, "onTimetableReceived")
                }
                "/folio/notifications" -> {
                    val json = dataMap.getString("json") ?: continue
                    saveAndForward("notifications", json, "onNotificationsReceived")
                }
            }
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val payload = messageEvent.data
        Log.d(TAG, "onMessageReceived: path=$path size=${payload.size}")
        when (path) {
            "/folio/timetable" -> {
                val json = payload.toString(Charsets.UTF_8)
                saveAndForward("timetable", json, "onTimetableReceived")
            }
            "/folio/notifications" -> {
                val json = payload.toString(Charsets.UTF_8)
                saveAndForward("notifications", json, "onNotificationsReceived")
            }
            "/folio/ping" -> {
                val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
                prefs.getString("timetable", null)?.let {
                    methodChannel?.invokeMethod("onTimetableReceived", it)
                }
                prefs.getString("notifications", null)?.let {
                    methodChannel?.invokeMethod("onNotificationsReceived", it)
                }
            }
            "/folio/pair-confirm" -> {
                val code = payload.toString(Charsets.UTF_8)
                Log.d(TAG, "pair-confirm received: code=$code")
                Handler(Looper.getMainLooper()).post {
                    methodChannel?.invokeMethod("onPairConfirmed", code)
                }
            }
        }
    }

    // ── Rotary Crown ────────────────────────────────────────────────────────

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL) {
            val delta = event.getAxisValue(MotionEvent.AXIS_SCROLL)
            if (delta != 0f) {
                Log.d(TAG, "rotary (dispatch): delta=$delta")
                methodChannel?.invokeMethod("onRotaryInput", delta.toDouble())
                return true
            }
        }
        return super.dispatchGenericMotionEvent(event)
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL) {
            val delta = event.getAxisValue(MotionEvent.AXIS_SCROLL)
            if (delta != 0f) {
                Log.d(TAG, "rotary (onGeneric): delta=$delta")
                methodChannel?.invokeMethod("onRotaryInput", delta.toDouble())
                return true
            }
        }
        return super.onGenericMotionEvent(event)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        val delta = when (keyCode) {
            KeyEvent.KEYCODE_NAVIGATE_NEXT, KeyEvent.KEYCODE_DPAD_DOWN  ->  0.5
            KeyEvent.KEYCODE_NAVIGATE_PREVIOUS, KeyEvent.KEYCODE_DPAD_UP -> -0.5
            else -> null
        }
        if (delta != null) {
            methodChannel?.invokeMethod("onRotaryInput", delta)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun pullDataItems() {
        Wearable.getDataClient(this).getDataItems()
            .addOnSuccessListener { dataItems ->
                Log.d(TAG, "pullDataItems: ${dataItems.count} item(s)")
                for (item in dataItems) {
                    val path = item.uri.path ?: continue
                    try {
                        val dataMap = DataMapItem.fromDataItem(item).dataMap
                        when (path) {
                            "/folio/timetable" -> {
                                val json = dataMap.getString("json") ?: continue
                                saveAndForward("timetable", json, "onTimetableReceived")
                            }
                            "/folio/notifications" -> {
                                val json = dataMap.getString("json") ?: continue
                                saveAndForward("notifications", json, "onNotificationsReceived")
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "pullDataItems error at $path: ${e.message}")
                    }
                }
                dataItems.release()
            }
            .addOnFailureListener { e -> Log.e(TAG, "pullDataItems FAILED: ${e.message}") }
    }

    private fun saveAndForward(key: String, json: String, method: String) {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(key, json).apply()
        methodChannel?.invokeMethod(method, json)
    }

    private fun sendSyncRequestToPhone() {
        sendMessageToPhone("/folio/sync-request", ByteArray(0))
    }

    private fun sendMessageToPhone(path: String, payload: ByteArray) {
        Wearable.getNodeClient(this).connectedNodes
            .addOnSuccessListener { nodes ->
                for (node in nodes) {
                    Wearable.getMessageClient(this)
                        .sendMessage(node.id, path, payload)
                        .addOnSuccessListener { Log.d(TAG, "$path sent to ${node.id}") }
                        .addOnFailureListener { e -> Log.e(TAG, "$path FAILED to ${node.id}: ${e.message}") }
                }
                if (nodes.isEmpty()) Log.w(TAG, "sendMessage $path: no nodes connected")
            }
            .addOnFailureListener { e -> Log.e(TAG, "sendMessage connectedNodes FAILED: ${e.message}") }
    }
}
