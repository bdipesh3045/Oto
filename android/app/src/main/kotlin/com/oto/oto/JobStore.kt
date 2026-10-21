package com.oto.oto

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject
import java.io.File
import java.util.UUID

class JobStore(context: Context) : SQLiteOpenHelper(context, "oto_native_jobs.db", null, 1) {
    val audioRoot = File(context.filesDir, "audio").apply { mkdirs() }.canonicalFile
    companion object { val active = setOf("queued", "preparing", "downloading", "converting", "saving") }
    override fun onCreate(db: SQLiteDatabase) { db.execSQL("CREATE TABLE jobs (id TEXT PRIMARY KEY, data TEXT NOT NULL)") }
    override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) = Unit
    init {
        all().filter { it.optString("state") in active }.forEach {
            it.put("state", "interrupted").put("error", "Android stopped this download. Tap Retry to start again.")
            save(it)
            folder(it.getString("jobId")).deleteRecursively()
        }
    }
    @Synchronized fun all(): List<JSONObject> = readableDatabase.rawQuery("SELECT data FROM jobs ORDER BY rowid DESC", null).use { cursor ->
        buildList { while (cursor.moveToNext()) add(JSONObject(cursor.getString(0))) }
    }
    @Synchronized fun get(id: String): JSONObject? = readableDatabase.rawQuery("SELECT data FROM jobs WHERE id=?", arrayOf(id)).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else null
    }
    @Synchronized fun save(job: JSONObject) {
        writableDatabase.insertWithOnConflict("jobs", null, ContentValues().apply {
            put("id", job.getString("jobId")); put("data", job.toString())
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }
    @Synchronized fun change(id: String, changes: Map<String, Any?>): JSONObject? {
        val job = get(id) ?: return null
        if (job.optString("state") == "cancelled") return job
        changes.forEach { (key, value) -> if (value == null) job.remove(key) else job.put(key, value) }
        save(job)
        return job
    }
    @Synchronized fun cancel(id: String) {
        val job = get(id) ?: return
        if (job.optString("state") in active) { job.put("state", "cancelled"); save(job) }
    }
    @Synchronized fun remove(id: String) {
        require(get(id)?.optString("state") !in active) { "Cancel this download first." }
        writableDatabase.delete("jobs", "id=?", arrayOf(id))
        // Completed files belong to the library, independently of download history.
    }
    fun folder(id: String): File {
        require(UUID.fromString(id).toString() == id) { "Invalid download ID." }
        return File(audioRoot, id)
    }
    @Synchronized fun migrate(legacy: List<*>) {
        legacy.forEach { value ->
            val record = value as? Map<*, *> ?: return@forEach
            val job = JSONObject(record)
            val id = job.optString("jobId")
            if (runCatching { UUID.fromString(id) }.isFailure || get(id) != null) return@forEach
            if (job.optString("state") in active || job.optString("state") == "ready") {
                job.put("state", "interrupted").put("error", "This older server download needs to be retried on your phone.")
            }
            job.remove("_server")
            save(job)
        }
    }
}

fun JSONObject.toChannelMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
    when (val value = opt(key)) { JSONObject.NULL -> null; is JSONObject -> value.toChannelMap(); else -> value }
}
