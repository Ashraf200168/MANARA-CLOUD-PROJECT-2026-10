package com.manara.manara_app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private companion object {
        const val FILES_CHANNEL = "com.manara.manara_app/files"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILES_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveCertificate") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val bytes = call.argument<ByteArray>("bytes")
            val requestedName = call.argument<String>("fileName")
            if (bytes == null || bytes.isEmpty()) {
                result.error("EMPTY_CERTIFICATE", "لم تصل صورة الشهادة إلى الجهاز.", null)
                return@setMethodCallHandler
            }

            try {
                val fileName = safePngName(requestedName)
                val location = saveCertificate(bytes, fileName)
                result.success(location)
            } catch (error: Exception) {
                result.error(
                    "SAVE_CERTIFICATE_FAILED",
                    "تعذر حفظ الشهادة: ${error.localizedMessage ?: "خطأ غير معروف"}",
                    null,
                )
            }
        }
    }

    private fun safePngName(requestedName: String?): String {
        val base = requestedName
            ?.trim()
            ?.replace(Regex("[\\\\/:*?\"<>|]"), "-")
            ?.takeIf { it.isNotEmpty() }
            ?: "Manara-Certificate.png"
        return if (base.lowercase().endsWith(".png")) base else "$base.png"
    }

    private fun saveCertificate(bytes: ByteArray, fileName: String): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveToMediaStore(bytes, fileName)
        } else {
            saveToExternalAppPictures(bytes, fileName)
        }
    }

    private fun saveToMediaStore(bytes: ByteArray, fileName: String): String {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(
                MediaStore.Images.Media.RELATIVE_PATH,
                "${Environment.DIRECTORY_PICTURES}/Manara",
            )
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Images.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        val uri = contentResolver.insert(collection, values)
            ?: error("تعذر إنشاء ملف الشهادة في معرض الصور.")

        try {
            contentResolver.openOutputStream(uri, "w")?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: error("تعذر فتح ملف الشهادة للكتابة.")

            val completed = ContentValues().apply {
                put(MediaStore.Images.Media.IS_PENDING, 0)
            }
            contentResolver.update(uri, completed, null, null)
            return uri.toString()
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun saveToExternalAppPictures(bytes: ByteArray, fileName: String): String {
        val picturesRoot = getExternalFilesDir(Environment.DIRECTORY_PICTURES)
            ?: filesDir
        val manaraDirectory = File(picturesRoot, "Manara")
        if (!manaraDirectory.exists() && !manaraDirectory.mkdirs()) {
            error("تعذر إنشاء مجلد الشهادات.")
        }
        val output = uniqueFile(manaraDirectory, fileName)
        output.outputStream().use { stream ->
            stream.write(bytes)
            stream.flush()
        }
        return output.absolutePath
    }

    private fun uniqueFile(directory: File, fileName: String): File {
        var candidate = File(directory, fileName)
        if (!candidate.exists()) return candidate

        val stem = fileName.removeSuffix(".png")
        var index = 2
        while (candidate.exists()) {
            candidate = File(directory, "$stem-$index.png")
            index += 1
        }
        return candidate
    }
}
