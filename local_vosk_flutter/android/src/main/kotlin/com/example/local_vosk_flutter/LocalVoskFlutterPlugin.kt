package com.example.local_vosk_flutter

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import android.content.Context
import android.os.Handler
import android.os.Looper
import java.io.File
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import org.json.JSONObject

/** LocalVoskFlutterPlugin */
public class LocalVoskFlutterPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var speechService: SpeechService? = null

    private var resultEventSink: EventChannel.EventSink? = null
    private var partialEventSink: EventChannel.EventSink? = null
    private var errorEventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "vosk_flutter")
        channel.setMethodCallHandler(this)

        // Setup event channels
        EventChannel(flutterPluginBinding.binaryMessenger, "result_event_channel")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    resultEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    resultEventSink = null
                }
            })

        EventChannel(flutterPluginBinding.binaryMessenger, "partial_event_channel")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    partialEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    partialEventSink = null
                }
            })

        EventChannel(flutterPluginBinding.binaryMessenger, "error_event_channel")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    errorEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    errorEventSink = null
                }
            })
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "model.create" -> {
                try {
                    val modelPath = call.arguments as String
                    model = Model(modelPath)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("MODEL_ERROR", "Error creating model: ${e.message}", null)
                }
            }
            "recognizer.create" -> {
                try {
                    val sampleRate = (call.argument("sampleRate") as Number).toFloat()
                    recognizer = Recognizer(model, sampleRate)

                    // Handle grammar if provided
                    call.argument<String>("grammar")?.let { grammar ->
                        recognizer?.setGrammar(grammar)
                    }

                    result.success(0) // Return a dummy ID since we only support one recognizer
                } catch (e: Exception) {
                    result.error("RECOGNIZER_ERROR", "Error creating recognizer: ${e.message}", null)
                }
            }
            "speechService.init" -> {
                try {
                    speechService = SpeechService(recognizer, 16000.0f)
                    speechService?.startListening(object : RecognitionListener {
                        override fun onResult(hypothesis: String?) {
                            Handler(Looper.getMainLooper()).post {
                                hypothesis?.let { resultEventSink?.success(it) }
                            }
                        }

                        override fun onPartialResult(hypothesis: String?) {
                            Handler(Looper.getMainLooper()).post {
                                hypothesis?.let { partialEventSink?.success(it) }
                            }
                        }

                        override fun onError(exception: Exception?) {
                            Handler(Looper.getMainLooper()).post {
                                errorEventSink?.error("RECOGNITION_ERROR",
                                    exception?.message ?: "Unknown error", null)
                            }
                        }

                        override fun onTimeout() {
                            // Implement if needed
                        }
                    })
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SERVICE_ERROR", "Error initializing speech service: ${e.message}", null)
                }
            }
            "speechService.stop" -> {
                speechService?.stop()
                result.success(true)
            }
            "speechService.reset" -> {
                recognizer?.reset()
                result.success(true)
            }
            "speechService.setPause" -> {
                val paused = call.arguments as Boolean
                if (paused) {
                    speechService?.pause()
                } else {
                    speechService?.startListening()
                }
                result.success(true)
            }
            "speechService.cancel" -> {
                speechService?.cancel()
                result.success(true)
            }
            "speechService.destroy" -> {
                speechService?.shutdown()
                speechService = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        speechService?.shutdown()
        speechService = null
        recognizer = null
        model?.close()
        model = null
    }
}