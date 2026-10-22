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
 * waveform rendering, and zero-filled (`Arrays.fill(buffer, 0)`) immediately on stop.
 */
class MainActivity : FlutterActivity() {
    private val controlChannelName = "app.unravel.audio/control"
    private val pcmStreamChannelName = "app.unravel.audio/pcm_stream"
    private val recordPermissionRequestCode = 4101

    private val isCapturing = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var pendingSampleRate: Int = 16000

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
                    result.success(null)
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
        recorder.startRecording()
        result.success(null)

        thread(start = true, name = "UnravelEphemeralPcmThread") {
            val frameBuffer = ByteArray(1064) // ~33ms @ 16kHz mono 16-bit PCM (30fps)
            try {
                while (isCapturing.get()) {
                    val readBytes = recorder.read(frameBuffer, 0, frameBuffer.size)
                    if (readBytes > 0) {
                        val copyForUi = frameBuffer.copyOf(readBytes)
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

    override fun onDestroy() {
        stopAndShredAudioRecord()
        super.onDestroy()
    }
}
