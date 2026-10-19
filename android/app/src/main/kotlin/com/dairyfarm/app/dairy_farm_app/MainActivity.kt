package com.dairyfarm.app.dairy_farm_app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dairyfarm.app/media_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "milk_history_${System.currentTimeMillis()}.png"
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "Image bytes cannot be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val path = saveImageToMediaStore(bytes, fileName)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.localizedMessage, null)
                    }
                }
                "saveFileToDownloads" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "document_${System.currentTimeMillis()}"
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (bytes == null) {
                        result.error("INVALID_ARGS", "File bytes cannot be null", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val path = saveDocumentToDownloads(bytes, fileName, mimeType)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveImageToMediaStore(bytes: ByteArray, fileName: String): String {
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + File.separator + "FarmFlow")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }

            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IllegalStateException("Failed to create MediaStore record")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            }

            contentValues.clear()
            contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            return Environment.DIRECTORY_PICTURES + "/FarmFlow/" + fileName
        } else {
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val farmFlowDir = File(picturesDir, "FarmFlow")
            if (!farmFlowDir.exists()) farmFlowDir.mkdirs()
            val file = File(farmFlowDir, fileName)
            FileOutputStream(file).use {
                it.write(bytes)
                it.flush()
            }
            MediaScannerConnection.scanFile(applicationContext, arrayOf(file.absolutePath), arrayOf("image/png"), null)
            return file.absolutePath
        }
    }

    private fun saveDocumentToDownloads(bytes: ByteArray, fileName: String, mimeType: String): String {
        val resolver = applicationContext.contentResolver
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + File.separator + "FarmFlow")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IllegalStateException("Failed to create Downloads record")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            }

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            return Environment.DIRECTORY_DOWNLOADS + "/FarmFlow/" + fileName
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val farmFlowDir = File(downloadsDir, "FarmFlow")
            if (!farmFlowDir.exists()) farmFlowDir.mkdirs()
            val file = File(farmFlowDir, fileName)
            FileOutputStream(file).use {
                it.write(bytes)
                it.flush()
            }
            MediaScannerConnection.scanFile(applicationContext, arrayOf(file.absolutePath), arrayOf(mimeType), null)
            return file.absolutePath
        }
    }
}
