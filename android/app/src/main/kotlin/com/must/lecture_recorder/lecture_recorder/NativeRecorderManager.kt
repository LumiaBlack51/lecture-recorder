package com.must.lecture_recorder.lecture_recorder

import android.content.Context
import android.media.MediaScannerConnection
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class NativeRecorderManager(
    private val context: Context,
    private val emitEvent: (Map<String, Any?>) -> Unit
) {
    private var mediaRecorder: MediaRecorder? = null
    private var courseName: String = ""
    private var courseDirectoryPath: String = ""
    private var sessionStartMillis: Long = 0L
    private var segmentationEnabled: Boolean = true
    private var maxFileSizeBytes: Long = 99L * 1024L * 1024L
    private var bitRate: Int = 96000
    private var sampleRate: Int = 32000
    private var currentSegmentIndex: Int = 0
    private var currentFile: File? = null
    private var nextFile: File? = null
    private var nextOutputPrepared: Boolean = false

    @Synchronized
    fun startRecording(arguments: Map<*, *>): Map<String, Any?> {
        if (mediaRecorder != null) {
            throw IllegalStateException("A recording session is already active.")
        }

        courseName = arguments["courseName"] as? String
            ?: throw IllegalArgumentException("courseName is required.")
        courseDirectoryPath = resolveCourseDirectoryPath(
            arguments["courseDirectoryPath"] as? String
        )
        sessionStartMillis = (arguments["sessionStartMillis"] as? Number)?.toLong()
            ?: throw IllegalArgumentException("sessionStartMillis is required.")
        segmentationEnabled = arguments["segmentationEnabled"] as? Boolean ?: true
        maxFileSizeBytes = ((arguments["maxFileSizeMb"] as? Number)?.toLong() ?: 99L) * 1024L * 1024L
        bitRate = (arguments["bitRate"] as? Number)?.toInt() ?: 96000
        sampleRate = (arguments["sampleRate"] as? Number)?.toInt() ?: 32000

        val courseDirectory = File(courseDirectoryPath)
        if (!courseDirectory.exists()) {
            courseDirectory.mkdirs()
        }

        currentSegmentIndex = 1
        currentFile = buildSegmentFile(currentSegmentIndex)
        nextFile = null
        nextOutputPrepared = false

        mediaRecorder = createRecorder(currentFile!!).also { recorder ->
            recorder.prepare()
            recorder.start()
        }

        emitEvent(
            mapOf(
                "type" to "started",
                "segmentIndex" to currentSegmentIndex,
                "filePath" to currentFile!!.absolutePath
            )
        )

        return mapOf(
            "segmentIndex" to currentSegmentIndex,
            "filePath" to currentFile!!.absolutePath
        )
    }

    @Synchronized
    fun pauseRecording() {
        val recorder = mediaRecorder ?: return
        recorder.pause()
        emitEvent(
            mapOf(
                "type" to "paused",
                "segmentIndex" to currentSegmentIndex,
                "filePath" to currentFile?.absolutePath
            )
        )
    }

    @Synchronized
    fun resumeRecording() {
        val recorder = mediaRecorder ?: return
        recorder.resume()
        emitEvent(
            mapOf(
                "type" to "resumed",
                "segmentIndex" to currentSegmentIndex,
                "filePath" to currentFile?.absolutePath
            )
        )
    }

    @Synchronized
    fun stopRecording() {
        val recorder = mediaRecorder ?: return
        try {
            recorder.stop()
            emitCurrentSegmentCompleted()
            currentFile?.let(::scanAudioFile)
        } catch (_: RuntimeException) {
            currentFile?.takeIf { it.exists() && it.length() == 0L }?.delete()
        } finally {
            recorder.reset()
            recorder.release()
            mediaRecorder = null
            cleanupUnusedNextFile()
            emitEvent(
                mapOf(
                    "type" to "stopped",
                    "segmentIndex" to currentSegmentIndex,
                    "filePath" to currentFile?.absolutePath
                )
            )
            currentFile = null
            nextFile = null
            currentSegmentIndex = 0
            nextOutputPrepared = false
        }
    }

    @Synchronized
    fun release() {
        mediaRecorder?.runCatching {
            stop()
        }
        mediaRecorder?.reset()
        mediaRecorder?.release()
        mediaRecorder = null
        cleanupUnusedNextFile()
    }

    private fun createRecorder(outputFile: File): MediaRecorder {
        outputFile.parentFile?.mkdirs()
        if (!outputFile.exists()) {
            outputFile.createNewFile()
        }

        return MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(bitRate)
            setAudioSamplingRate(sampleRate)
            setOutputFile(outputFile.absolutePath)
            if (segmentationEnabled) {
                setMaxFileSize(maxFileSizeBytes)
            }
            setOnInfoListener { recorder, what, _ ->
                when (what) {
                    MediaRecorder.MEDIA_RECORDER_INFO_NEXT_OUTPUT_FILE_STARTED -> {
                        handleSegmentSwitch()
                    }
                    MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_APPROACHING -> {
                        prepareNextOutputFile(recorder)
                    }
                    MediaRecorder.MEDIA_RECORDER_INFO_MAX_FILESIZE_REACHED -> {
                        emitEvent(
                            mapOf(
                                "type" to "error",
                                "message" to "The recorder reached the size limit before the next segment was attached."
                            )
                        )
                    }
                }
            }
            setOnErrorListener { _, _, _ ->
                emitEvent(
                    mapOf(
                        "type" to "error",
                        "message" to "Android recorder reported an unrecoverable error."
                    )
                )
            }
        }
    }

    @Synchronized
    private fun prepareNextOutputFile(recorder: MediaRecorder) {
        if (!segmentationEnabled || nextOutputPrepared || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val candidate = buildSegmentFile(currentSegmentIndex + 1)
        candidate.parentFile?.mkdirs()
        if (!candidate.exists()) {
            candidate.createNewFile()
        }
        recorder.setNextOutputFile(candidate)
        nextFile = candidate
        nextOutputPrepared = true
    }

    @Synchronized
    private fun handleSegmentSwitch() {
        val completedFile = currentFile
        if (completedFile != null) {
            scanAudioFile(completedFile)
            emitEvent(
                mapOf(
                    "type" to "segment_completed",
                    "segmentIndex" to currentSegmentIndex,
                    "filePath" to completedFile.absolutePath
                )
            )
        }

        currentSegmentIndex += 1
        currentFile = nextFile
        nextFile = null
        nextOutputPrepared = false
        emitEvent(
            mapOf(
                "type" to "segment_switched",
                "segmentIndex" to currentSegmentIndex,
                "filePath" to currentFile?.absolutePath
            )
        )

    }

    private fun emitCurrentSegmentCompleted() {
        val file = currentFile ?: return
        if (!file.exists() || file.length() == 0L) {
            return
        }
        emitEvent(
            mapOf(
                "type" to "segment_completed",
                "segmentIndex" to currentSegmentIndex,
                "filePath" to file.absolutePath
            )
        )
    }

    private fun cleanupUnusedNextFile() {
        val file = nextFile
        if (file != null && file.exists() && file.length() == 0L) {
            file.delete()
        }
    }

    private fun buildSegmentFile(segmentIndex: Int): File {
        val safeCourseName = sanitizeFileComponent(courseName)
        val dateCode = SimpleDateFormat("MMdd", Locale.getDefault())
            .format(Date(sessionStartMillis))
        val indexCode = segmentIndex.toString().padStart(2, '0')
        return File(courseDirectoryPath, "${safeCourseName}_${dateCode}_${indexCode}.m4a")
    }

    private fun resolveCourseDirectoryPath(requestedPath: String?): String {
        val publicDirectory = File(getPublicRecordingsRoot(), sanitizeFileComponent(courseName))
        publicDirectory.mkdirs()

        if (requestedPath.isNullOrBlank()) {
            return publicDirectory.absolutePath
        }

        val normalizedRequested = requestedPath.replace('\\', '/')
        if (
            normalizedRequested.contains("/Android/data/") ||
            !normalizedRequested.startsWith(getPublicRecordingsRoot().absolutePath.replace('\\', '/'))
        ) {
            return publicDirectory.absolutePath
        }

        return requestedPath
    }

    private fun getPublicRecordingsRoot(): File {
        val musicDirectory = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_MUSIC
        )
        return File(musicDirectory, "Recordings/Lecture Recorder")
    }

    private fun scanAudioFile(file: File) {
        if (!file.exists() || !file.isFile) {
            return
        }
        MediaScannerConnection.scanFile(
            context,
            arrayOf(file.absolutePath),
            arrayOf("audio/mp4"),
            null
        )
    }

    private fun sanitizeFileComponent(value: String): String {
        val sanitized = value
            .replace(Regex("[<>:\"/\\\\|?*]"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
        return if (sanitized.isEmpty()) "Course" else sanitized
    }
}
