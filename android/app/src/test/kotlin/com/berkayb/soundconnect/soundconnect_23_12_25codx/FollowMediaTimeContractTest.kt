package com.berkayb.soundconnect.soundconnect_23_12_25codx

import java.io.File
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

@RunWith(Parameterized::class)
class FollowMediaTimeContractTest(private val type: String, private val version: String,
    private val row: List<String>) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name = "{0}: {2}")
        fun cases(): List<Array<Any>> {
            val fixture = listOf(File("test/fixtures/follow_media_time_contract.tsv"),
                File("../../test/fixtures/follow_media_time_contract.tsv")).first { it.isFile }
            val rows = fixture.readLines().drop(1).filter { it.isNotEmpty() }.map { it.split('\t') }
            return listOf("SOCIAL_NEW_FOLLOWER" to "ANDROID_FOLLOW_V1",
                "SOCIAL_NEW_BAND_FOLLOWER" to "ANDROID_FOLLOW_V1",
                "SOCIAL_LIKE" to "ANDROID_MEDIA_V1", "SOCIAL_COMMENT" to "ANDROID_MEDIA_V1")
                .flatMap { (type, version) -> rows.map { arrayOf<Any>(type, version, it) } }
        }
    }
    @Test fun commonWireTable() {
        val now = row[1].toLong()
        val sent = row[2].replace("<empty>", "")
        val expiry = row[3].replace("<empty>", "")
        val result = VenuePushPayload.parse(mapOf(
            "notificationId" to "50000000-0000-4000-8000-000000000001",
            "recipientId" to "70000000-0000-4000-8000-000000000001",
            "type" to type, "presentationVersion" to version, "displayVariant" to "DEFAULT",
            "sentAt" to sent, "expiresAt" to expiry
        ), now)
        assertEquals(row[0], row[4].toBoolean(), result != null)
        if (result != null) {
            assertEquals(minOf(now, sent.toLong()), result.sentAt)
            assertEquals(expiry.toLong(), result.expiresAt)
            assertEquals(setOf("notificationId", "recipientId", "type"), result.target().keys)
            assertEquals(type, result.type)
        }
    }
}
