package com.oto.oto

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

object Downloads {
    @Volatile private var instance: JobStore? = null
    fun store(context: Context): JobStore = instance ?: synchronized(this) {
        instance ?: JobStore(context.applicationContext).also { instance = it }
    }
}

class DownloadService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pending = ConcurrentHashMap<String, AtomicBoolean>()
    private lateinit var store: JobStore
    private var lastStart = 0
    private var destroying = false
    companion object {
        const val START = "com.oto.oto.DOWNLOAD"
        const val CANCEL = "com.oto.oto.CANCEL_DOWNLOAD"
        private const val CHANNEL = "oto_downloads"
        private const val NOTIFICATION = 42
        fun enqueue(context: Context, id: String) {
            context.startForegroundService(Intent(context, DownloadService::class.java).setAction(START).putExtra("id", id))
        }
    }
    override fun onCreate() {
        super.onCreate()
        store = Downloads.store(this)
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Music downloads", NotificationManager.IMPORTANCE_LOW))
    }
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        lastStart = startId
        val id = intent?.getStringExtra("id") ?: return START_NOT_STICKY
        if (intent.action == CANCEL) {
            store.cancel(id)
            pending[id]?.set(true)
            if (pending.isEmpty()) stopSelf(startId)
            return START_NOT_STICKY
        }
        if (store.get(id)?.optString("state") != "queued") {
            if (pending.isEmpty()) stopSelf(startId)
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION, notification(id, "Preparing your download", null))
        val cancelled = AtomicBoolean(false)
        if (pending.putIfAbsent(id, cancelled) == null) executor.execute { work(id, cancelled) }
        return START_NOT_STICKY
    }
    private fun work(id: String, cancelled: AtomicBoolean) {
        val wake = (getSystemService(POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "oto:download")
        try {
            if (cancelled.get() || store.get(id)?.optString("state") == "cancelled") return
            wake.acquire(20 * 60 * 1000L)
            store.change(id, mapOf("state" to "preparing"))
            notify(id, "Preparing audio", null)
            var last = 0L
            Engine.download(this, store, id, cancelled) { percent, state ->
                val now = System.currentTimeMillis()
                if (now - last > 400 || percent == 100) {
                    last = now
                    store.change(id, mapOf("state" to state, "progress" to percent))
                    notify(id, if (state == "converting") "Converting to MP3" else "Downloading audio", if (state == "downloading") percent else null)
                }
            }
        } catch (error: Exception) {
            android.util.Log.e("oto", "Local download failed", error)
            if (!cancelled.get()) store.change(id, mapOf("state" to "failed", "error" to Engine.friendly(error)))
        } finally {
            if (wake.isHeld) wake.release()
            val state = store.get(id)?.optString("state")
            if (state != "completed") store.folder(id).deleteRecursively()
            if (state in setOf("completed", "failed") && !destroying) {
                val launch = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                val done = Notification.Builder(this, CHANNEL).setSmallIcon(com.oto.oto.R.drawable.ic_music_note)
                    .setContentTitle(store.get(id)?.optString("title") ?: "Music download")
                    .setContentText(if (state == "completed") "MP3 saved on this phone" else "Download stopped. Open oto to retry.")
                    .setContentIntent(launch).setAutoCancel(true).build()
                getSystemService(NotificationManager::class.java).notify(id.hashCode(), done)
            }
            pending.remove(id)
            main.post {
                if (pending.isEmpty() && !destroying) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelfResult(lastStart)
                }
            }
        }
    }
    private fun notification(id: String, status: String, progress: Int?): Notification {
        val launch = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val cancel = PendingIntent.getService(this, id.hashCode(), Intent(this, DownloadService::class.java).setAction(CANCEL).putExtra("id", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return Notification.Builder(this, CHANNEL).setSmallIcon(com.oto.oto.R.drawable.ic_music_note)
            .setContentTitle(store.get(id)?.optString("title") ?: "Music download")
            .setContentText(status).setContentIntent(launch).setOngoing(true).setOnlyAlertOnce(true)
            .setProgress(100, progress ?: 0, progress == null)
            .addAction(Notification.Action.Builder(null, "Cancel", cancel).build()).build()
    }
    private fun notify(id: String, status: String, progress: Int?) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification(id, status, progress))
    }
    override fun onDestroy() {
        destroying = true
        pending.forEach { (id, flag) ->
            flag.set(true)
            store.change(id, mapOf("state" to "interrupted", "error" to "Android stopped this download. Tap Retry to start again."))
        }
        executor.shutdownNow()
        super.onDestroy()
    }
    override fun onTimeout(startId: Int, fgsType: Int) {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
