package hu.ekrata.ellenorzoplusz.wear

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker that runs daily at 07:00 and pushes the latest cached
 * timetable + notifications to the paired WearOS watch.
 *
 * The data is read from SharedPreferences (written by [WearSyncManager] whenever
 * the Flutter app syncs), so this worker has no dependency on the Flutter engine.
 */
class WearMorningSyncWorker(
    private val ctx: Context,
    params: WorkerParameters
) : Worker(ctx, params) {

    override fun doWork(): Result {
        return try {
            val prefs = ctx.getSharedPreferences("folio_wear_phone", Context.MODE_PRIVATE)
            val syncEnabled = prefs.getBoolean("sync_enabled", true)
            if (!syncEnabled) return Result.success()

            // WearSyncManager needs no Flutter channel for cached sends
            val manager = WearSyncManager(ctx, NoOpMethodChannel)
            manager.sendCachedData()
            Result.success()
        } catch (e: Exception) {
            android.util.Log.e("WearMorningSyncWorker", "Work failed: $e")
            Result.retry()
        }
    }

    companion object {
        private const val WORK_NAME = "folio_wear_morning_sync"

        fun schedule(context: Context) {
            val now = Calendar.getInstance()
            val target = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 7)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                // If 7 AM already passed today, schedule for tomorrow
                if (before(now)) add(Calendar.DAY_OF_YEAR, 1)
            }

            val initialDelayMs = target.timeInMillis - now.timeInMillis

            val request = PeriodicWorkRequestBuilder<WearMorningSyncWorker>(
                1, TimeUnit.DAYS
            )
                .setInitialDelay(initialDelayMs, TimeUnit.MILLISECONDS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                        .build()
                )
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}

