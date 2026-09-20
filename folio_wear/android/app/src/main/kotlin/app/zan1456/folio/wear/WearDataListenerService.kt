package hu.ekrata.ellenorzoplusz.wear

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearDataListenerService : WearableListenerService() {

    private val TAG = "FolioWear.ListenerSvc"

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate: service started by system")
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        super.onDestroy()
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        Log.d(TAG, "onDataChanged: ${dataEvents.count} event(s)")
        for (event in dataEvents) {
            val path = event.dataItem.uri.path ?: continue
            Log.d(TAG, "  event type=${event.type} path=$path")
            if (event.type != DataEvent.TYPE_CHANGED) continue

            val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap

            when (path) {
                "/folio/timetable" -> {
                    val json = dataMap.getString("json")
                    if (json == null) { Log.w(TAG, "timetable: json key missing") }
                    else {
                        Log.d(TAG, "timetable received: ${json.length} chars")
                        saveAndNotify("timetable", json)
                        Handler(Looper.getMainLooper()).post {
                            MainActivity.methodChannel?.invokeMethod("onTimetableReceived", json)
                        }
                    }
                }
                "/folio/notifications" -> {
                    val json = dataMap.getString("json")
                    if (json == null) { Log.w(TAG, "notifications: json key missing") }
                    else {
                        Log.d(TAG, "notifications received: ${json.length} chars")
                        saveAndNotify("notifications", json)
                        Handler(Looper.getMainLooper()).post {
                            MainActivity.methodChannel?.invokeMethod("onNotificationsReceived", json)
                        }
                    }
                }
                else -> Log.w(TAG, "unknown path: $path")
            }
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        val payload = messageEvent.data
        Log.d(TAG, "onMessageReceived: path=$path payloadSize=${payload.size}")
        when (path) {
            "/folio/timetable" -> {
                val json = payload.toString(Charsets.UTF_8)
                Log.d(TAG, "timetable: ${json.length} chars")
                saveAndNotify("timetable", json)
                Handler(Looper.getMainLooper()).post {
                    MainActivity.methodChannel?.invokeMethod("onTimetableReceived", json)
                }
            }
            "/folio/notifications" -> {
                val json = payload.toString(Charsets.UTF_8)
                Log.d(TAG, "notifications: ${json.length} chars")
                saveAndNotify("notifications", json)
                Handler(Looper.getMainLooper()).post {
                    MainActivity.methodChannel?.invokeMethod("onNotificationsReceived", json)
                }
            }
            "/folio/ping" -> {
                Log.d(TAG, "ping: delivering cached data")
                val prefs = getSharedPreferences("folio_wear", Context.MODE_PRIVATE)
                val timetable = prefs.getString("timetable", null)
                val notifications = prefs.getString("notifications", null)
                Handler(Looper.getMainLooper()).post {
                    timetable?.let { MainActivity.methodChannel?.invokeMethod("onTimetableReceived", it) }
                    notifications?.let { MainActivity.methodChannel?.invokeMethod("onNotificationsReceived", it) }
                }
            }
            else -> Log.w(TAG, "unknown message path: $path")
        }
    }

    override fun onConnectedNodes(connectedNodes: MutableList<com.google.android.gms.wearable.Node>) {
        Log.d(TAG, "onConnectedNodes: count=${connectedNodes.size}")
        connectedNodes.forEach { Log.d(TAG, "  node id=${it.id} name=${it.displayName} nearby=${it.isNearby}") }
        val connected = connectedNodes.isNotEmpty()
        WearConnectionHelper.isConnected = connected
        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod("onConnectionChanged", connected)
        }
    }

    override fun onPeerConnected(peer: com.google.android.gms.wearable.Node) {
        Log.d(TAG, "onPeerConnected: id=${peer.id} name=${peer.displayName} nearby=${peer.isNearby}")
        WearConnectionHelper.isConnected = true
        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod("onConnectionChanged", true)
        }
    }

    override fun onPeerDisconnected(peer: com.google.android.gms.wearable.Node) {
        Log.d(TAG, "onPeerDisconnected: id=${peer.id} name=${peer.displayName}")
        WearConnectionHelper.isConnected = false
        Handler(Looper.getMainLooper()).post {
            MainActivity.methodChannel?.invokeMethod("onConnectionChanged", false)
        }
    }

    private fun saveAndNotify(key: String, json: String) {
        getSharedPreferences("folio_wear", Context.MODE_PRIVATE)
            .edit()
            .putString(key, json)
            .apply()
    }
}
