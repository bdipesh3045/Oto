package com.oto.oto

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import org.json.JSONObject
import java.util.UUID
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager

class MainActivity : AudioServiceActivity() {
    private val executor = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private var exportResult: MethodChannel.Result? = null
    private var exportPath: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oto/downloads").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "initialize" -> background(result) {
                        val store = Downloads.store(this)
                        store.migrate(call.argument<List<*>>("legacyJobs") ?: emptyList<Any>())
                        mapOf("ready" to true)
                    }
                    "inspect" -> background(result) { Engine.inspect(this, call.argument<String>("url") ?: "") }
                    "engineStatus" -> background(result) { Engine.status(this) }
                    "updateEngine" -> background(result) {
                        check(Downloads.store(this).all().none { it.optString("state") in JobStore.active }) { "Finish or cancel active downloads before updating." }
                        try { Engine.update(this) }
                        catch (e: Exception) { throw IllegalArgumentException("Could not check for engine updates. Check your connection and retry. The installed engine was kept.", e) }
                    }
                    "jobs" -> background(result) { Downloads.store(this).all().map { it.toChannelMap() } }
                    "enqueue" -> {
                        val info = call.argument<Map<String, Any>>("info") ?: error("A song is required.")
                        val url = Engine.canonical(info["url"] as? String ?: "")
                        val bitrate = call.argument<Int>("bitrate") ?: 192
                        require(bitrate in setOf(128, 192)) { "Choose 128 or 192 kbps." }
                        val store = Downloads.store(this)
                        check(store.all().count { it.optString("state") in JobStore.active } < 20) { "The download queue is full. Wait for a song to finish." }
                        val id = UUID.randomUUID().toString()
                        val job = JSONObject(info).put("url", url).put("videoId", url.substringAfter("v="))
                            .put("jobId", id).put("bitrate", bitrate).put("state", "queued")
                            .put("progress", 0).put("createdAt", System.currentTimeMillis())
                        store.save(job)
                        try { DownloadService.enqueue(this, id) }
                        catch (e: Exception) { store.change(id, mapOf("state" to "failed", "error" to "Open oto and retry this download.")); throw e }
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 52)
                        }
                        result.success(id)
                    }
                    "cancel" -> {
                        val id = call.argument<String>("id") ?: error("A download is required.")
                        Downloads.store(this).cancel(id)
                        startService(Intent(this, DownloadService::class.java).setAction(DownloadService.CANCEL).putExtra("id", id))
                        result.success(null)
                    }
                    "remove" -> background(result) { Downloads.store(this).remove(call.argument<String>("id") ?: ""); null }
                    "export" -> {
                        check(exportResult == null) { "Finish the current export first." }
                        val file = File(call.argument<String>("path") ?: "").canonicalFile
                        require(file.path.startsWith(File(filesDir, "audio").canonicalPath + File.separator) && file.isFile) { "This audio file is missing." }
                        exportPath = file.path
                        exportResult = result
                        val title = (call.argument<String>("title") ?: "oto track").replace(Regex("[\\\\/:*?\"<>|]"), "_")
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/mpeg"
                            putExtra(Intent.EXTRA_TITLE, "$title.mp3")
                        }, 51)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("oto", e.message ?: "Could not export this MP3. Try another location.", null) }
        }
    }
    private fun background(result: MethodChannel.Result, task: () -> Any?) {
        executor.execute {
            try { val value = task(); main.post { result.success(value) } }
            catch (e: Throwable) {
                if (e is VirtualMachineError || e is ThreadDeath) throw e
                android.util.Log.e("oto", "Native operation failed", e)
                main.post { result.error("oto", Engine.friendly(e), null) }
            }
        }
    }
    @Deprecated("Activity result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 51) return
        val result = exportResult ?: return
        val path = exportPath
        exportResult = null
        exportPath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) { result.success(false); return }
        background(result) {
            contentResolver.openOutputStream(uri)?.use { output -> File(path).inputStream().use { it.copyTo(output) } }
                ?: error("Couldn't write to this location. Choose another folder.")
            true
        }
    }
}
