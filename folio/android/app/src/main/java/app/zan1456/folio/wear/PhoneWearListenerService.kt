package hu.ekrata.ellenorzoplusz.wear

import android.content.Context
import android.util.Log
import hu.ekrata.ellenorzoplusz.MainActivity
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class PhoneWearListenerService : WearableListenerService() {

    private val TAG = "FolioPhone.ListenerSvc"

    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "onMessageReceived: path=${messageEvent.path} from=${messageEvent.sourceNodeId}")
        when (messageEvent.path) {
            "/folio/sync-request" -> {
                val prefs = getSharedPreferences("folio_wear_phone", Context.MODE_PRIVATE)
                val timetable = prefs.getString("timetable", null)
                val notifications = prefs.getString("notifications", null)
                Log.d(TAG, "sync-request: cached timetable=${timetable != null} notifications=${notifications != null}")

                val manager = WearSyncManager(this, NoOpMethodChannel)
                timetable?.let {
                    Log.d(TAG, "sync-request: sending cached timetable (${it.length} chars)")
                    manager.sendTimetable(it)
                }
                notifications?.let {
                    Log.d(TAG, "sync-request: sending cached notifications (${it.length} chars)")
                    manager.sendNotifications(it)
                }

                val channelAvailable = MainActivity.wearChannel != null
                Log.d(TAG, "sync-request: wearChannel available=$channelAvailable")
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    MainActivity.wearChannel?.invokeMethod("onSyncRequested", null)
                }
            }
            "/folio/pair-request" -> {
                val code = messageEvent.data.toString(Charsets.UTF_8)
                Log.d(TAG, "pair-request: code=$code")
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    MainActivity.wearChannel?.invokeMethod("onPairRequest", code)
                }
            }
            else -> Log.w(TAG, "unknown path: ${messageEvent.path}")
        }
    }
}
