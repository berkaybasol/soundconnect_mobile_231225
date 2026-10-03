package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.Context
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException

/** Independent logout latch. No identity or token; never backed up to another install. */
internal object PushResetState {
    private val lock = Any()
    private fun file(context: Context) = AtomicFile(File(context.noBackupFilesDir, "soundconnect-push-reset"))

    fun required(context: Context): Boolean = synchronized(lock) {
        val storage = file(context)
        val bytes = try { storage.readFully() }
        catch (error: FileNotFoundException) {
            // An install predating this latch has no file. An interrupted first
            // write or an unreadable existing file must not authorize rendering.
            val path = storage.baseFile
            if (path.parentFile?.isDirectory == true && path.parentFile?.canRead() == true
                && !path.exists() && !File(path.path + ".bak").exists() && !File(path.path + ".new").exists())
                return@synchronized false
            throw error
        }
        val json = JSONObject(String(bytes, Charsets.UTF_8))
        val value = json.opt("required")
        if (value !is Boolean) throw IOException("Invalid push reset state")
        value
    }

    fun setRequired(context: Context, required: Boolean) = synchronized(lock) {
        val storage = file(context)
        val stream = storage.startWrite()
        try {
            stream.write(JSONObject().put("required", required).toString().toByteArray(Charsets.UTF_8))
            storage.finishWrite(stream)
        } catch (error: Exception) {
            storage.failWrite(stream)
            throw error
        }
    }

    /** Missing legacy state is allowed; corrupt/unavailable state suppresses native delivery. */
    fun blocksRendering(context: Context): Boolean = runCatching { required(context) }.getOrDefault(true)
}
