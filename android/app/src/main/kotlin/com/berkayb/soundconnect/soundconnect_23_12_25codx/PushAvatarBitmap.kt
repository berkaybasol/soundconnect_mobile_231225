package com.berkayb.soundconnect.soundconnect_23_12_25codx

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader

internal object PushAvatarBitmap {
    /** Center crop without distorting faces; transparent corners survive OEM layouts. */
    fun circular(source: Bitmap): Bitmap {
        val size = minOf(256, source.width, source.height).coerceAtLeast(1)
        val scale = maxOf(size.toFloat() / source.width, size.toFloat() / source.height)
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((size - source.width * scale) / 2, (size - source.height * scale) / 2)
        }
        val shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            setLocalMatrix(matrix)
        }
        return Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also {
            Canvas(it).drawCircle(size / 2f, size / 2f, size / 2f,
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { this.shader = shader })
        }
    }
}
