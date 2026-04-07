package com.lecturerecorder.app

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var recorderMethodChannel: MethodChannel
    private lateinit var platformMethodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val recordingEventListener = object : RecordingEventListener {
        override fun onRecordingEvent(event: Map<String, Any?>) {
            runOnUiThread {
                eventSink?.success(event)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        recorderMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lecture_recorder/recorder"
        )
        platformMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lecture_recorder/platform"
        )
        eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lecture_recorder/recorder_events"
        )

        recorderMethodChannel.setMethodCallHandler(this)
        platformMethodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "startRecording" -> {
                    AndroidRecordingService.start(applicationContext)
                    try {
                        val response = RecordingCoordinator.startRecording(
                            applicationContext,
                            call.arguments as Map<*, *>
                        )
                        result.success(response)
                    } catch (error: Throwable) {
                        stopService(Intent(applicationContext, AndroidRecordingService::class.java))
                        throw error
                    }
                }
                "stopRecording" -> {
                    RecordingCoordinator.stopRecording()
                    result.success(null)
                }
                "pauseRecording" -> {
                    RecordingCoordinator.pauseRecording()
                    result.success(null)
                }
                "resumeRecording" -> {
                    RecordingCoordinator.resumeRecording()
                    result.success(null)
                }
                "getRecordingState" -> {
                    result.success(RecordingCoordinator.getRecordingState())
                }
                "hasActiveRecording" -> {
                    result.success(RecordingCoordinator.hasActiveRecording())
                }
                "openLocation" -> {
                    openLocation(call.argument<String>("filePath"))
                    result.success(null)
                }
                "getPublicRecordingsDirectory" -> {
                    result.success(getPublicRecordingsDirectory().absolutePath)
                }
                "migrateLegacyRecordings" -> {
                    migrateLegacyRecordings(call.argument<String>("publicRootPath"))
                    result.success(null)
                }
                "openManageAllFilesAccess" -> {
                    openManageAllFilesAccess()
                    result.success(null)
                }
                "openOverlayPermissionAccess" -> {
                    openOverlayPermissionAccess()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.error(
                "recorder_error",
                error.message ?: "Native recorder failure",
                null
            )
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        RecordingCoordinator.addListener(recordingEventListener)
    }

    override fun onCancel(arguments: Any?) {
        RecordingCoordinator.removeListener(recordingEventListener)
        eventSink = null
    }

    override fun onDestroy() {
        recorderMethodChannel.setMethodCallHandler(null)
        platformMethodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        super.onDestroy()
    }

    private fun openLocation(filePath: String?) {
        require(!filePath.isNullOrBlank()) { "filePath is required." }

        val target = File(filePath)
        val directory = if (target.isDirectory) target else target.parentFile ?: target
        val documentUri = buildDocumentUri(directory)
        val treeUri = buildTreeUri(directory)

        val openDirectoryIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(documentUri, DocumentsContract.Document.MIME_TYPE_DIR)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val fallbackIntent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            putExtra(DocumentsContract.EXTRA_INITIAL_URI, treeUri)
        }

        if (openDirectoryIntent.resolveActivity(packageManager) != null) {
            try {
                startActivity(openDirectoryIntent)
                return
            } catch (_: SecurityException) {
            } catch (_: IllegalArgumentException) {
            }
        }

        startActivity(fallbackIntent)
    }

    private fun getPublicRecordingsDirectory(): File {
        val musicDirectory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_MUSIC
        )
        return File(musicDirectory, "Recordings/Lecture Recorder")
    }

    private fun migrateLegacyRecordings(publicRootPath: String?) {
        require(!publicRootPath.isNullOrBlank()) { "publicRootPath is required." }

        val externalFilesDirectory = getExternalFilesDir(null) ?: return
        val legacyRoot = File(externalFilesDirectory, "recordings")
        val publicRoot = File(publicRootPath)
        cleanupEmptyAudioFiles(publicRoot)
        if (!legacyRoot.exists()) {
            return
        }

        legacyRoot.walkTopDown().forEach { source ->
            val relative = source.relativeTo(legacyRoot).path
            val destination = if (relative.isEmpty()) publicRoot else File(publicRoot, relative)

            if (source.isDirectory) {
                if (!destination.exists()) {
                    destination.mkdirs()
                }
            } else if (source.isFile) {
                if (source.length() == 0L) {
                    if (destination.exists() && destination.length() == 0L) {
                        destination.delete()
                    }
                    return@forEach
                }
                destination.parentFile?.mkdirs()
                if (!destination.exists() || destination.length() == 0L) {
                    source.copyTo(destination, overwrite = true)
                    scanAudioFile(destination)
                }
            }
        }
    }

    private fun buildDocumentUri(directory: File): Uri {
        val externalRoot = Environment.getExternalStorageDirectory().absolutePath
        val absolutePath = directory.absolutePath
        if (absolutePath.startsWith(externalRoot)) {
            val relativePath = absolutePath.removePrefix("$externalRoot/")
            return DocumentsContract.buildDocumentUri(
                "com.android.externalstorage.documents",
                "primary:$relativePath"
            )
        }
        return Uri.fromFile(directory)
    }

    private fun buildTreeUri(directory: File): Uri {
        val externalRoot = Environment.getExternalStorageDirectory().absolutePath
        val absolutePath = directory.absolutePath
        if (absolutePath.startsWith(externalRoot)) {
            val relativePath = absolutePath.removePrefix("$externalRoot/")
            return DocumentsContract.buildTreeDocumentUri(
                "com.android.externalstorage.documents",
                "primary:$relativePath"
            )
        }
        return Uri.fromFile(directory)
    }

    private fun scanAudioFile(file: File) {
        if (!file.exists() || !file.isFile) {
            return
        }
        MediaScannerConnection.scanFile(
            this,
            arrayOf(file.absolutePath),
            arrayOf("audio/mp4"),
            null
        )
    }

    private fun cleanupEmptyAudioFiles(root: File) {
        if (!root.exists()) {
            return
        }

        root.walkTopDown().forEach { candidate ->
            if (candidate.isFile && candidate.length() == 0L) {
                candidate.delete()
            }
        }
    }

    private fun openManageAllFilesAccess() {
        val intent = Intent(
            Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
            Uri.parse("package:$packageName")
        ).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        if (intent.resolveActivity(packageManager) != null) {
            startActivity(intent)
            return
        }

        startActivity(
            Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }

    private fun openOverlayPermissionAccess() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }
}
