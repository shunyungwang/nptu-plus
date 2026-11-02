package tw.edu.nptu.nptu_campus

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingFilePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tw.edu.nptu.nptu_campus/file_picker",
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingFilePickerResult != null) {
                result.error("picker_busy", "A file picker is already open.", null)
                return@setMethodCallHandler
            }

            val mimeTypes = call.argument<List<String>>("acceptTypes")
                .orEmpty().filter { it.isNotBlank() }.distinct()
            val allowMultiple = call.argument<Boolean>("multiple") ?: false
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeTypes.singleOrNull() ?: "*/*"
                if (mimeTypes.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            try {
                pendingFilePickerResult = result
                startActivityForResult(intent, FILE_PICKER_REQUEST)
            } catch (error: Exception) {
                pendingFilePickerResult = null
                result.error("picker_unavailable", error.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Android, retained for WebView file input compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_PICKER_REQUEST) return

        val result = pendingFilePickerResult ?: return
        pendingFilePickerResult = null
        val uris = mutableListOf<Uri>()
        if (resultCode == RESULT_OK && data != null) {
            val clip = data.clipData
            if (clip != null) {
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.let(uris::add)
                }
            } else {
                data.data?.let(uris::add)
            }
        }
        val files = uris.mapNotNull { uri ->
            try {
                val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
                } ?: "attachment"
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return@mapNotNull null
                mapOf(
                    "name" to name,
                    "mimeType" to (contentResolver.getType(uri) ?: "application/octet-stream"),
                    "bytes" to bytes,
                )
            } catch (_: Exception) {
                null
            }
        }
        result.success(files)
    }

    private companion object {
        const val FILE_PICKER_REQUEST = 4817
    }
}
