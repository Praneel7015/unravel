package app.unravel.foss

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.io.FileOutputStream
import java.util.ArrayList
import java.util.Arrays
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * 100% FOSS-pure Android host for `app.unravel.foss`.
 *
 * Bridges Android's hardware `AudioRecord` (16kHz mono 16-bit PCM) directly into
 * Dart's `EphemeralHardwareVoiceCaptureService` over:
 * - `app.unravel.audio/control` (`MethodChannel`)
 * - `app.unravel.audio/pcm_stream` (`EventChannel`)
 *
 * Zero Persistent Audio Disk Leaks:
 * Audio frames are read into a small RAM buffer, dispatched to Flutter for 30fps
 * waveform rendering. On stop, those words are written from an on-device
 * Vosk model, then every captured byte is zero-filled. The recording is not stored.
 */
class MainActivity : FlutterActivity() {
    private val controlChannelName = "app.unravel.audio/control"
    private val pcmStreamChannelName = "app.unravel.audio/pcm_stream"
    private val recordPermissionRequestCode = 4101
    private val modelAssetName = "vosk-model-small-en-us-0.15"
    private val maxCapturedBytes = 16000 * 2 * 60

    private val isCapturing = AtomicBoolean(false)
    private val pcmLock = Any()
    private val capturedFrames = ArrayList<ByteArray>()
    private var audioRecord: AudioRecord? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var pendingSampleRate: Int = 16000
    @Volatile private var speechModel: Model? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            pcmStreamChannelName
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            controlChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startPcmCapture" -> {
                    val sampleRate = call.argument<Int>("sampleRateHz") ?: 16000
                    startEphemeralPcmStream(sampleRate, result)
                }
                "stopPcmCaptureAndTranscribe" -> {
                    stopAndShredAudioRecord()
                    thread(name = "UnravelOnDeviceSpeech") {
                        Thread.sleep(80)
                        val pcm = takeCapturedPcm()
                        val text = transcribe(pcm)
                        Arrays.fill(pcm, 0.toByte())
                        mainHandler.post { result.success(text) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startEphemeralPcmStream(sampleRate: Int, result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingCaptureResult = result
            pendingSampleRate = sampleRate
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                recordPermissionRequestCode
            )
            return
        }

        beginPcmCapture(sampleRate, result)
    }

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != recordPermissionRequestCode) {
            return
        }
        val pending = pendingCaptureResult ?: return
        pendingCaptureResult = null
        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            beginPcmCapture(pendingSampleRate, pending)
        } else {
            pending.error(
                "PERMISSION_DENIED",
                "Microphone permission was not granted.",
                null
            )
        }
    }

    private fun beginPcmCapture(sampleRate: Int, result: MethodChannel.Result) {
        stopAndShredAudioRecord()

        val minBufSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(1024)

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBufSize
        )

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            result.error("MIC_INIT_FAILED", "Could not initialize AudioRecord.", null)
            return
        }

        audioRecord = recorder
        isCapturing.set(true)
        synchronized(pcmLock) {
            for (frame in capturedFrames) {
                Arrays.fill(frame, 0.toByte())
            }
            capturedFrames.clear()
        }
        recorder.startRecording()
        result.success(null)

        thread(start = true, name = "UnravelEphemeralPcmThread") {
            val frameBuffer = ByteArray(1064) // ~33ms @ 16kHz mono 16-bit PCM (30fps)
            try {
                while (isCapturing.get()) {
                    val readBytes = recorder.read(frameBuffer, 0, frameBuffer.size)
                    if (readBytes > 0) {
                        val copyForUi = frameBuffer.copyOf(readBytes)
                        rememberPcm(frameBuffer.copyOf(readBytes))
                        mainHandler.post {
                            eventSink?.success(copyForUi)
                        }
                    }
                }
            } finally {
                // Zero-fill temporary RAM buffer immediately on exit
                Arrays.fill(frameBuffer, 0.toByte())
            }
        }
    }

    private fun stopAndShredAudioRecord() {
        isCapturing.set(false)
        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }
        try {
            audioRecord?.release()
        } catch (_: Exception) {
        }
        audioRecord = null
    }

    private fun rememberPcm(frame: ByteArray) {
        synchronized(pcmLock) {
            var used = 0
            for (existing in capturedFrames) {
                used += existing.size
            }
            if (used >= maxCapturedBytes) {
                Arrays.fill(frame, 0.toByte())
                return
            }
            val keep = minOf(frame.size, maxCapturedBytes - used)
            if (keep == frame.size) {
                capturedFrames.add(frame)
            } else {
                capturedFrames.add(frame.copyOf(keep))
                Arrays.fill(frame, 0.toByte())
            }
        }
    }

    private fun takeCapturedPcm(): ByteArray {
        synchronized(pcmLock) {
            var size = 0
            for (frame in capturedFrames) {
                size += frame.size
            }
            val pcm = ByteArray(size)
            var offset = 0
            for (frame in capturedFrames) {
                frame.copyInto(pcm, offset)
                Arrays.fill(frame, 0.toByte())
                offset += frame.size
            }
            capturedFrames.clear()
            return pcm
        }
    }

    private fun transcribe(pcm: ByteArray): String? {
        if (pcm.isEmpty()) {
            return null
        }
        val model = try {
            ensureSpeechModel()
        } catch (_: Exception) {
            null
        } ?: return null
        val recognizer = Recognizer(model, 16000.0f)
        try {
            var offset = 0
            while (offset < pcm.size) {
                val length = minOf(8000, pcm.size - offset)
                val slice = pcm.copyOfRange(offset, offset + length)
                recognizer.acceptWaveForm(slice, slice.size)
                Arrays.fill(slice, 0.toByte())
                offset += length
            }
            val text = JSONObject(recognizer.finalResult).optString("text").trim()
            return text.ifEmpty { null }
        } catch (_: Exception) {
            return null
        } finally {
            recognizer.close()
        }
    }

    private fun ensureSpeechModel(): Model? {
        speechModel?.let { return it }
        val dir = File(filesDir, modelAssetName)
        val marker = File(dir, "am/final.mdl")
        if (!marker.exists()) {
            if (assets.list(modelAssetName).isNullOrEmpty()) {
                return null
            }
            copyAssetFolder(modelAssetName, dir)
        }
        if (!marker.exists()) {
            return null
        }
        val loaded = Model(dir.absolutePath)
        speechModel = loaded
        return loaded
    }

    private fun copyAssetFolder(assetPath: String, dest: File) {
        val children = assets.list(assetPath)
        if (children.isNullOrEmpty()) {
            dest.parentFile?.mkdirs()
            assets.open(assetPath).use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            }
            return
        }
        dest.mkdirs()
        for (child in children) {
            copyAssetFolder("$assetPath/$child", File(dest, child))
        }
    }

    override fun onDestroy() {
        stopAndShredAudioRecord()
        val leftover = takeCapturedPcm()
        Arrays.fill(leftover, 0.toByte())
        try {
            speechModel?.close()
        } catch (_: Exception) {
        }
        speechModel = null
        super.onDestroy()
    }
}
