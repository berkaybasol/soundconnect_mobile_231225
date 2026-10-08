package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Pixel-only checks: no application storage, accounts or OS notification APIs. */
@RunWith(AndroidJUnit4::class)
class PushAvatarBitmapInstrumentationTest {
    @Test fun widePhotoCenterCropsAndKeepsTransparentCorners() {
        val photo = Bitmap.createBitmap(600, 200, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(photo)
        canvas.drawColor(Color.RED)
        canvas.drawRect(200f, 0f, 400f, 200f, Paint().apply { color = Color.GREEN })
        val result = PushAvatarBitmap.circular(photo)
        assertEquals(200, result.width)
        assertEquals(200, result.height)
        assertEquals(Color.GREEN, result.getPixel(100, 100))
        assertEquals(Color.GREEN, result.getPixel(10, 100))
        assertEquals(0, Color.alpha(result.getPixel(0, 0)))
        assertEquals(0, Color.alpha(result.getPixel(199, 199)))
        result.recycle(); photo.recycle()
    }

    @Test fun tallPhotoCenterCropsInsteadOfStretching() {
        val photo = Bitmap.createBitmap(200, 600, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(photo)
        canvas.drawColor(Color.RED)
        canvas.drawRect(0f, 200f, 200f, 400f, Paint().apply { color = Color.BLUE })
        val result = PushAvatarBitmap.circular(photo)
        assertEquals(Color.BLUE, result.getPixel(100, 10))
        assertEquals(Color.BLUE, result.getPixel(100, 190))
        assertEquals(0, Color.alpha(result.getPixel(199, 0)))
        result.recycle(); photo.recycle()
    }

    @Test fun largePhotoOutputIsBoundedTo256Pixels() {
        val photo = Bitmap.createBitmap(1024, 1024, Bitmap.Config.ARGB_8888)
        photo.eraseColor(Color.MAGENTA)
        val result = PushAvatarBitmap.circular(photo)
        assertEquals(256, result.width)
        assertEquals(256, result.height)
        assertEquals(Color.MAGENTA, result.getPixel(128, 128))
        assertEquals(0, Color.alpha(result.getPixel(255, 255)))
        result.recycle(); photo.recycle()
    }
}
