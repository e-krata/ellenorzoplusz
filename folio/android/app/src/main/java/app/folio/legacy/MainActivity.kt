package hu.ekrata.ellenorzoplusz

import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import hu.ekrata.ellenorzoplusz.live_activity.LiveLessonNotificationManager
import hu.ekrata.ellenorzoplusz.wear.WearSyncManager

class MainActivity : FlutterActivity(), MessageClient.OnMessageReceivedListener {

    private val LIVE_ACTIVITY_CHANNEL = "hu.ekrata.ellenorzoplusz/android_live_activity"
    private val WEAR_CHANNEL = "hu.ekrata.ellenorzoplusz/wear_sync"
    private val TAG = "FolioPhone.MainActivity"

    private var wearSync: WearSyncManager? = null

    companion object {
        var wearChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val manager = LiveLessonNotificationManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_ACTIVITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showOrUpdateNative" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val subText = call.argument<String>("subText")
                        manager.showOrUpdateNative(title, body, subText)
                        result.success(null)
                    }
                    "showOrUpdateHyperOs" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val subText = call.argument<String>("subText")
                        val remainingSeconds = call.argument<Int>("remainingSeconds") ?: 0
                        manager.showOrUpdateHyperOs(title, body, subText, remainingSeconds)
                        result.success(null)
                    }
                    "cancel" -> {
                        manager.cancel()
                        result.success(null)
                    }
                    "getCookies" -> {
                        val url = call.argument<String>("url") ?: ""
                        val cookieManager = android.webkit.CookieManager.getInstance()
                        val cookies = cookieManager.getCookie(url) ?: ""
                        result.success(cookies)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Wear OS sync channel ──────────────────────────────────────────
        val wearMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WEAR_CHANNEL
        )
        wearChannel = wearMethodChannel
        val sync = WearSyncManager(this, wearMethodChannel)
        wearSync = sync

        wearMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendTimetable" -> {
                    val json = call.argument<String>("json") ?: ""
                    sync.sendTimetable(json)
                    result.success(null)
                }
                "sendNotifications" -> {
                    val json = call.argument<String>("json") ?: ""
                    sync.sendNotifications(json)
                    result.success(null)
                }
                "isWatchConnected" -> {
                    sync.checkConnection()
                    result.success(sync.isConnected())
                }
                "scheduleMorningSync" -> {
                    sync.scheduleMorningSync()
                    result.success(null)
                }
                "getSyncEnabled" -> {
                    result.success(sync.getSyncEnabled())
                }
                "setSyncEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    sync.setSyncEnabled(enabled)
                    result.success(null)
                }
                "sendCachedToWatch" -> {
                    sync.sendCachedData()
                    result.success(null)
                }
                "sendPairConfirm" -> {
                    val code = call.argument<String>("code") ?: ""
                    sync.sendPairConfirm(code)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        sync.checkConnection()
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume: registering MessageClient listener")
        Wearable.getMessageClient(this).addListener(this)
            .addOnSuccessListener { Log.d(TAG, "MessageClient listener registered OK") }
            .addOnFailureListener { e -> Log.e(TAG, "MessageClient addListener FAILED: ${e.message}", e) }
    }

    override fun onPause() {
        Log.d(TAG, "onPause: unregistering MessageClient listener")
        Wearable.getMessageClient(this).removeListener(this)
        super.onPause()
    }

    // Receives messages from the watch when the phone app is in the foreground.
    // Complements PhoneWearListenerService which handles background delivery.
    override fun onMessageReceived(messageEvent: MessageEvent) {
        val path = messageEvent.path
        Log.d(TAG, "onMessageReceived: path=$path from=${messageEvent.sourceNodeId}")
        when (path) {
            "/folio/sync-request" -> {
                Log.d(TAG, "sync-request: pushing cached data to watch")
                wearSync?.sendCachedData()
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    wearChannel?.invokeMethod("onSyncRequested", null)
                }
            }
            "/folio/pair-request" -> {
                val code = messageEvent.data.toString(Charsets.UTF_8)
                Log.d(TAG, "pair-request from watch: code=$code")
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    wearChannel?.invokeMethod("onPairRequest", code)
                }
            }
        }
    }

    override fun onDestroy() {
        wearChannel = null
        wearSync = null
        super.onDestroy()
    }
}
