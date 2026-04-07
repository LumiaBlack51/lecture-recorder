package com.lecturerecorder.app

import android.content.Context

interface RecordingEventListener {
    fun onRecordingEvent(event: Map<String, Any?>)
}

private enum class RecordingRuntimeStatus {
    IDLE,
    RECORDING,
    PAUSED,
    ERROR,
}

private data class RecordingRuntimeState(
    val status: RecordingRuntimeStatus = RecordingRuntimeStatus.IDLE,
    val courseName: String? = null,
    val sessionStartMillis: Long? = null,
    val segmentIndex: Int = 0,
    val filePath: String? = null,
    val accumulatedPausedMillis: Long = 0L,
    val pausedAtMillis: Long? = null,
    val errorMessage: String? = null,
) {
    val isActive: Boolean
        get() = status == RecordingRuntimeStatus.RECORDING ||
            status == RecordingRuntimeStatus.PAUSED

    fun elapsedMillis(nowMillis: Long): Long {
        val startedAt = sessionStartMillis ?: return 0L
        val activeUntil = if (status == RecordingRuntimeStatus.PAUSED) {
            pausedAtMillis ?: nowMillis
        } else {
            nowMillis
        }
        return (activeUntil - startedAt - accumulatedPausedMillis).coerceAtLeast(0L)
    }
}

object RecordingCoordinator {
    private val listeners = linkedSetOf<RecordingEventListener>()

    private var recorderManager: NativeRecorderManager? = null
    private var state = RecordingRuntimeState()

    @Synchronized
    fun startRecording(context: Context, arguments: Map<*, *>): Map<String, Any?> {
        ensureRecorderManager(context.applicationContext)

        val courseName = arguments["courseName"] as? String
            ?: throw IllegalArgumentException("courseName is required.")
        val sessionStartMillis = (arguments["sessionStartMillis"] as? Number)?.toLong()
            ?: throw IllegalArgumentException("sessionStartMillis is required.")

        state = state.copy(
            status = RecordingRuntimeStatus.RECORDING,
            courseName = courseName,
            sessionStartMillis = sessionStartMillis,
            accumulatedPausedMillis = 0L,
            pausedAtMillis = null,
            errorMessage = null,
        )

        val response = recorderManager!!.startRecording(arguments)
        state = state.copy(
            status = RecordingRuntimeStatus.RECORDING,
            segmentIndex = (response["segmentIndex"] as? Number)?.toInt() ?: 1,
            filePath = response["filePath"] as? String,
        )
        return response
    }

    @Synchronized
    fun stopRecording() {
        recorderManager?.stopRecording()
    }

    @Synchronized
    fun pauseRecording() {
        recorderManager?.pauseRecording()
    }

    @Synchronized
    fun resumeRecording() {
        recorderManager?.resumeRecording()
    }

    @Synchronized
    fun getRecordingState(): Map<String, Any?>? {
        if (!state.isActive) {
            return null
        }

        return mapOf(
            "courseName" to state.courseName,
            "sessionStartMillis" to state.sessionStartMillis,
            "segmentIndex" to state.segmentIndex,
            "filePath" to state.filePath,
            "isPaused" to (state.status == RecordingRuntimeStatus.PAUSED),
            "elapsedMillis" to state.elapsedMillis(System.currentTimeMillis()),
        )
    }

    @Synchronized
    fun addListener(listener: RecordingEventListener) {
        listeners.add(listener)
    }

    @Synchronized
    fun removeListener(listener: RecordingEventListener) {
        listeners.remove(listener)
    }

    @Synchronized
    fun hasActiveRecording(): Boolean {
        return state.isActive
    }

    @Synchronized
    private fun ensureRecorderManager(context: Context) {
        if (recorderManager != null) {
            return
        }

        recorderManager = NativeRecorderManager(context) { event ->
            handleEvent(event)
        }
    }

    @Synchronized
    private fun handleEvent(event: Map<String, Any?>) {
        val eventType = event["type"] as? String
        state = when (eventType) {
            "started" -> state.copy(
                status = RecordingRuntimeStatus.RECORDING,
                segmentIndex = (event["segmentIndex"] as? Number)?.toInt() ?: state.segmentIndex,
                filePath = event["filePath"] as? String ?: state.filePath,
                pausedAtMillis = null,
                errorMessage = null,
            )
            "paused" -> state.copy(
                status = RecordingRuntimeStatus.PAUSED,
                pausedAtMillis = System.currentTimeMillis(),
            )
            "resumed" -> {
                val resumedAt = System.currentTimeMillis()
                val pausedAt = state.pausedAtMillis
                val pausedDuration = if (pausedAt == null) {
                    0L
                } else {
                    (resumedAt - pausedAt).coerceAtLeast(0L)
                }
                state.copy(
                    status = RecordingRuntimeStatus.RECORDING,
                    accumulatedPausedMillis = state.accumulatedPausedMillis + pausedDuration,
                    pausedAtMillis = null,
                )
            }
            "segment_switched" -> state.copy(
                status = RecordingRuntimeStatus.RECORDING,
                segmentIndex = (event["segmentIndex"] as? Number)?.toInt() ?: state.segmentIndex,
                filePath = event["filePath"] as? String ?: state.filePath,
                pausedAtMillis = null,
            )
            "stopped" -> RecordingRuntimeState()
            "error" -> state.copy(
                status = RecordingRuntimeStatus.ERROR,
                errorMessage = event["message"] as? String,
            )
            else -> state
        }

        listeners.toList().forEach { listener ->
            listener.onRecordingEvent(event)
        }
    }
}
