package com.oto.oto

import android.content.Context
import android.os.Build
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.ffmpeg.FFmpeg
import org.json.JSONObject
import java.io.File
import java.io.ByteArrayOutputStream
import java.net.URI
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

object Engine {
    private val lock = ReentrantReadWriteLock()
    private var initialized = false
    const val maxBytes = 100L * 1024 * 1024
    @Synchronized fun init(context: Context) {
        if (initialized) return
        require(Build.SUPPORTED_ABIS.contains("arm64-v8a")) { "This build needs an ARM64 Android device." }
        YoutubeDL.init(context)
        FFmpeg.getInstance().init(context)
        // Upstream 0.18.1 still packs five 4 KB-aligned WebP libraries. Replace
        // these with source-built 16 KB versions before starting any converter.
        val destination = File(context.noBackupFilesDir, "youtubedl-android/packages/ffmpeg/usr/lib")
        destination.mkdirs()
        for (name in listOf("libsharpyuv.so", "libwebp.so", "libwebpdecoder.so", "libwebpdemux.so", "libwebpmux.so")) {
            val target = File(destination, name)
            context.assets.open("native/arm64-v8a/$name").use { input -> target.outputStream().use { input.copyTo(it) } }
        }
        initialized = true
    }
    fun canonical(value: String): String {
        require(value.length <= 2048) { "Paste a valid YouTube video link." }
        val uri = URI(value.trim())
        val host = uri.host?.lowercase()
        require(uri.scheme in setOf("https", "http") && host in setOf("youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be") && uri.userInfo == null && uri.port in setOf(-1, 80, 443)) { "Paste a YouTube or YouTube Music video link." }
        val parts = (uri.path ?: "").trim('/').split('/')
        val id = when {
            host == "youtu.be" -> parts.firstOrNull()
            parts.firstOrNull() == "watch" -> uri.rawQuery?.split('&')?.firstOrNull { it.startsWith("v=") }?.substringAfter('=')
            parts.size == 2 && parts[0] in setOf("shorts", "embed", "live") -> parts[1]
            else -> null
        }
        require(id != null && Regex("[A-Za-z0-9_-]{11}").matches(id)) { "Use a link to one video, rather than a playlist or channel." }
        return "https://www.youtube.com/watch?v=$id"
    }
    private fun request(url: String) = YoutubeDLRequest(canonical(url)).apply {
        addOption("--no-playlist"); addOption("--no-warnings")
        addOption("--socket-timeout", 20); addOption("--retries", 2)
        addOption("--extractor-retries", 1)
        addOption("--remote-components", "ejs:github")
        addOption("-f", "bestaudio/best")
    }
    private fun metadata(raw: JSONObject, url: String): Map<String, Any> {
        require(!raw.optBoolean("is_live") && raw.optString("live_status") !in setOf("is_live", "is_upcoming")) { "Live and upcoming videos cannot be saved. Choose a finished video." }
        val duration = raw.optDouble("duration", 0.0).toInt()
        require(duration in 1..1200) { "Choose a video with a known duration under 20 minutes." }
        fun text(vararg keys: String) = keys.map { raw.optString(it).takeUnless { s -> s.isBlank() || s == "null" } }.firstOrNull { it != null }
        return mapOf("videoId" to url.substringAfter("v="), "url" to url,
            "title" to (text("track", "title") ?: "Untitled track"),
            "artist" to (text("artist", "uploader") ?: "Unknown artist").removeSuffix(" - Topic"),
            "duration" to duration, "thumbnail" to (text("thumbnail") ?: ""))
    }
    fun inspect(context: Context, value: String): Map<String, Any> = lock.read {
        init(context)
        val url = canonical(value)
        val req = request(url).apply { addOption("--dump-single-json"); addOption("--skip-download") }
        val response = YoutubeDL.execute(req)
        metadata(JSONObject(response.out.trim()), url)
    }
    fun status(context: Context): Map<String, Any> = lock.read {
        init(context)
        mapOf("version" to version(context), "ready" to true)
    }
    private fun version(context: Context): String = context.getSharedPreferences("oto_engine", Context.MODE_PRIVATE).getString("version", null)
        ?: context.assets.open("bundled-engine.json").bufferedReader().use { JSONObject(it.readText()).getString("version") }
    fun update(context: Context): Map<String, Any> = lock.write {
        init(context)
        val release = JSONObject(String(fetch("https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest", 1024 * 1024), Charsets.UTF_8))
        val tag = release.getString("tag_name")
        require(Regex("[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}(\\.[0-9]+)?").matches(tag)) { "The engine update returned an unexpected version. Retry later." }
        if (tag == version(context)) return@write mapOf("version" to tag, "updated" to false)
        val prefix = "https://github.com/yt-dlp/yt-dlp/releases/download/$tag/"
        val checksums = String(fetch(prefix + "SHA2-256SUMS", 512 * 1024), Charsets.UTF_8)
        val expected = checksums.lineSequence().map { it.trim().split(Regex("\\s+")) }
            .firstOrNull { it.size == 2 && it[1].removePrefix("*") == "yt-dlp" }?.first()
        require(expected != null && Regex("[0-9a-fA-F]{64}").matches(expected)) { "Could not verify the download engine. Retry later." }
        val bytes = fetch(prefix + "yt-dlp", 10 * 1024 * 1024)
        val actual = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }
        check(actual.equals(expected, true)) { "Engine verification failed. The existing engine was kept." }
        val target = File(context.noBackupFilesDir, "youtubedl-android/yt-dlp/yt-dlp")
        val temporary = File(target.parentFile, "yt-dlp.part")
        try {
            temporary.writeBytes(bytes)
            Files.move(temporary.toPath(), target.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
            context.getSharedPreferences("oto_engine", Context.MODE_PRIVATE).edit().putString("version", tag).commit()
        } finally { temporary.delete() }
        mapOf("version" to tag, "updated" to true)
    }
    private fun fetch(url: String, limit: Int): ByteArray {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 10_000; connection.readTimeout = 15_000
            connection.setRequestProperty("User-Agent", "oto-android")
            check(connection.responseCode == 200) { "The download engine update is unavailable. Retry later." }
            return connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    check(output.size() + count <= limit) { "The engine update was larger than expected. Retry later." }
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
        } finally { connection.disconnect() }
    }
    fun download(context: Context, store: JobStore, id: String, cancelled: AtomicBoolean, progress: (Int, String) -> Unit) = lock.read {
        init(context)
        check(!cancelled.get()) { "Download cancelled." }
        val job = store.get(id) ?: error("Download no longer exists.")
        val url = canonical(job.getString("url"))
        val folder = store.folder(id).apply { mkdirs() }
        require(folder.usableSpace > 250L * 1024 * 1024) { "Free at least 250 MB on your phone and retry." }
        val req = request(url).apply {
            addOption("-o", File(folder, "source.%(ext)s").path)
            addOption("--extract-audio"); addOption("--audio-format", "mp3")
            addOption("--audio-quality", "${job.getInt("bitrate")}K")
            addOption("--embed-metadata"); addOption("--write-info-json")
            addOption("--no-mtime"); addOption("--max-filesize", "100M")
            addOption("--match-filter", "!is_live & duration > 0 & duration <= 1200")
        }
        val monitor = Executors.newSingleThreadScheduledExecutor()
        val watcher = monitor.scheduleAtFixedRate({ if (cancelled.get()) YoutubeDL.destroyProcessById(id) }, 0, 100, TimeUnit.MILLISECONDS)
        try {
            YoutubeDL.execute(req, id, { value, _, line ->
                val percent = value.toInt().coerceIn(0, 100)
                progress(percent, if (percent >= 100 || line.contains("[ExtractAudio]")) "converting" else "downloading")
            })
            check(!cancelled.get()) { "Download cancelled." }
            val infoFile = folder.listFiles()?.firstOrNull { it.name.endsWith(".info.json") } ?: error("Download metadata was not returned.")
            val info = metadata(JSONObject(infoFile.readText()), url)
            val mp3 = folder.listFiles()?.firstOrNull { it.extension == "mp3" } ?: error("This source did not return usable audio.")
            require(mp3.length() in 1..maxBytes) { "This audio exceeds the 100 MB file limit." }
            val target = File(folder, "track.mp3")
            check(mp3.renameTo(target)) { "Could not save the completed MP3. Check free storage." }
            val cover = artwork(info["thumbnail"] as String, folder)
            check(!cancelled.get()) { "Download cancelled." }
            // Only a complete local MP3 is imported into the library.
            store.change(id, info + mapOf("state" to "completed", "progress" to 100,
                "path" to target.path, "artwork" to cover, "bytes" to target.length(),
                "completedAt" to System.currentTimeMillis(), "error" to null))
            folder.listFiles()?.filter { it.name !in setOf("track.mp3", "cover.jpg") }?.forEach { it.delete() }
        } finally { watcher.cancel(false); monitor.shutdownNow() }
    }
    private fun artwork(value: String, folder: File): String = runCatching {
        val uri = URI(value)
        require(uri.scheme == "https" && (uri.host ?: "").endsWith(".ytimg.com"))
        val connection = URL(value).openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 5000; connection.readTimeout = 5000; connection.instanceFollowRedirects = false
            require(connection.responseCode == 200)
            val bytes = connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    require(output.size() + count <= 4 * 1024 * 1024)
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            require(bytes.size <= 4 * 1024 * 1024)
            File(folder, "cover.jpg").apply { writeBytes(bytes) }.path
        } finally { connection.disconnect() }
    }.getOrDefault("")
    fun friendly(error: Throwable): String {
        val text = error.message.orEmpty()
        return when {
            text.contains("sign in", true) || text.contains("not a bot", true) || text.contains("age-restricted", true) -> "YouTube requires sign-in for this video. Try another link."
            text.contains("private", true) || text.contains("unavailable", true) -> "This video is private or unavailable. Try another link."
            error is IllegalArgumentException || text.startsWith("Free at least") -> text
            else -> "Could not download this audio. Check your connection, update the download engine in Settings, and retry."
        }
    }
}
