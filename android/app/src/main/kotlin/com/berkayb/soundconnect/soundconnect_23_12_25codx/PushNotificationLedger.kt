package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.content.ContentValues
import android.content.Context
import android.database.DatabaseUtils
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteDatabaseCorruptException
import java.io.File

/** Only UUIDs and expiry, never message content, names, avatars or credentials. */
internal object PushNotificationLedger {
    private const val TABLE = "deliveries"
    private const val MAX_DATABASE_BYTES = 64L * 1024 * 1024

    private fun open(context: Context): SQLiteDatabase {
        // The DB and its journal stay outside Android backup/restore.
        val database = SQLiteDatabase.openOrCreateDatabase(
            File(context.noBackupFilesDir, "soundconnect-push-deliveries.sqlite").absolutePath, null,
            DatabaseErrorHandler { database ->
                // Android's default corruption handler deletes the DB. Losing
                // every seen key would permit old deliveries to render again.
                database.close()
                throw SQLiteDatabaseCorruptException("Notification ledger unavailable")
            })
        try {
            database.setMaximumSize(MAX_DATABASE_BYTES)
            database.execSQL("CREATE TABLE IF NOT EXISTS $TABLE (" +
                "recipient_id TEXT NOT NULL, notification_id TEXT NOT NULL, " +
                "expires_at INTEGER NOT NULL, PRIMARY KEY(recipient_id, notification_id))")
            database.execSQL("CREATE INDEX IF NOT EXISTS deliveries_expiry ON $TABLE(expires_at)")
            // A subset of existing reservations, with the same expiry and 64 MiB budget.
            // No reserved key is deleted to dismiss a notification.
            database.execSQL("CREATE TABLE IF NOT EXISTS dismissed_deliveries (" +
                "recipient_id TEXT NOT NULL, notification_id TEXT NOT NULL, " +
                "expires_at INTEGER NOT NULL, PRIMARY KEY(recipient_id, notification_id))")
            database.execSQL("CREATE INDEX IF NOT EXISTS dismissed_deliveries_expiry ON dismissed_deliveries(expires_at)")
            return database
        } catch (error: Exception) {
            database.close()
            throw error
        }
    }

    fun seen(context: Context, recipient: String, id: String, now: Long): Boolean =
        open(context).use { database ->
            database.rawQuery("SELECT 1 FROM $TABLE WHERE recipient_id=? AND notification_id=? AND expires_at>? LIMIT 1",
                arrayOf(recipient, id, now.toString())).use { it.moveToFirst() }
        }

    fun reserve(context: Context, recipient: String, id: String, expiresAt: Long, now: Long): Boolean =
        open(context).use { database ->
            database.beginTransaction()
            try {
                val reserved = PushNotificationLedgerPolicy.reserve(SqlEntries(database), recipient, id, expiresAt, now)
                database.setTransactionSuccessful()
                reserved
            } finally { database.endTransaction() }
        }

    fun mayUpdate(context: Context, recipient: String, id: String, now: Long): Boolean =
        open(context).use { database ->
            database.rawQuery("SELECT 1 FROM $TABLE d WHERE d.recipient_id=? AND d.notification_id=? " +
                "AND d.expires_at>? AND NOT EXISTS (SELECT 1 FROM dismissed_deliveries x " +
                "WHERE x.recipient_id=d.recipient_id AND x.notification_id=d.notification_id) LIMIT 1",
                arrayOf(recipient, id, now.toString())).use { it.moveToFirst() }
        }

    fun expiry(context: Context, recipient: String, id: String): Long? = open(context).use { database ->
        database.rawQuery("SELECT expires_at FROM $TABLE WHERE recipient_id=? AND notification_id=? LIMIT 1",
            arrayOf(recipient, id)).use { if (it.moveToFirst()) it.getLong(0) else null }
    }

    fun eligibleIds(context: Context, recipient: String, ids: Set<String>, now: Long): Set<String> {
        if (ids.isEmpty()) return emptySet()
        return open(context).use { database ->
            ids.chunked(PushDeliveredPolicy.MAX_IDS).flatMap { batch ->
                val placeholders = batch.joinToString(",") { "?" }
                database.rawQuery("SELECT d.notification_id FROM $TABLE d WHERE d.recipient_id=? " +
                    "AND d.expires_at>? AND d.notification_id IN ($placeholders) " +
                    "AND NOT EXISTS (SELECT 1 FROM dismissed_deliveries x " +
                    "WHERE x.recipient_id=d.recipient_id AND x.notification_id=d.notification_id)",
                    arrayOf(recipient, now.toString(), *batch.toTypedArray())).use { cursor ->
                    buildList { while (cursor.moveToNext()) add(cursor.getString(0)) }
                }
            }.toSet()
        }
    }

    fun markDismissed(context: Context, recipient: String, ids: Set<String>) {
        require(ids.size <= PushDeliveredPolicy.MAX_IDS)
        if (ids.isEmpty()) return
        open(context).use { database ->
            // One atomic insert-select: unknown IDs cannot consume storage, and
            // duplicate dismissals cannot grow the bounded reservation subset.
            val placeholders = ids.joinToString(",") { "?" }
            database.execSQL("INSERT OR IGNORE INTO dismissed_deliveries(recipient_id,notification_id,expires_at) " +
                "SELECT recipient_id,notification_id,expires_at FROM $TABLE WHERE recipient_id=? " +
                "AND notification_id IN ($placeholders)", arrayOf(recipient, *ids.toTypedArray()))
        }
    }

    private class SqlEntries(private val database: SQLiteDatabase) : PushLedgerEntries {
        override fun removeExpired(now: Long) {
            database.delete("dismissed_deliveries", "expires_at<=?", arrayOf(now.toString()))
            database.delete(TABLE, "expires_at<=?", arrayOf(now.toString()))
        }
        override fun contains(recipient: String, notification: String): Boolean =
            database.rawQuery("SELECT 1 FROM $TABLE WHERE recipient_id=? AND notification_id=? LIMIT 1",
                arrayOf(recipient, notification)).use { it.moveToFirst() }
        override fun count(): Long = DatabaseUtils.queryNumEntries(database, TABLE)
        override fun insert(recipient: String, notification: String, expiresAt: Long) {
            database.insertOrThrow(TABLE, null, ContentValues().apply {
                put("recipient_id", recipient)
                put("notification_id", notification)
                put("expires_at", expiresAt)
            })
        }
    }
}
