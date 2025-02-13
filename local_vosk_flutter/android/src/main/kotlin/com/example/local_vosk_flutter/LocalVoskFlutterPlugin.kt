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
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService

/** LocalVoskFlutterPlugin */
public class LocalVoskFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var speechService: SpeechService? = null
    private var recognitionListener: RecognitionListener? = null

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
                    val sampleRateArg = call.argument<Number>("sampleRate")
                    if (sampleRateArg == null) {
                        result.error("RECOGNIZER_ERROR", "sampleRate argument is missing", null)
                        return
                    }
                    val sampleRate = sampleRateArg.toFloat()
                    recognizer = Recognizer(model, sampleRate)

                    // Il supporto per il grammar non è disponibile nella versione attuale dell'API.
                    call.argument<String>("grammar")?.let { grammar ->
                        // Se necessario, gestisci il parametro "grammar" qui.
                    }

                    result.success(0) // ID dummy, in quanto si supporta un solo recognizer
                } catch (e: Exception) {
                    result.error("RECOGNIZER_ERROR", "Error creating recognizer: ${e.message}", null)
                }
            }
            "speechService.init" -> {
                try {
                    recognitionListener = object : RecognitionListener {
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
                        override fun onFinalResult(hypothesis: String?) {
                            Handler(Looper.getMainLooper()).post {
                                hypothesis?.let { resultEventSink?.success(it) }
                            }
                        }
                        override fun onError(exception: Exception?) {
                            Handler(Looper.getMainLooper()).post {
                                errorEventSink?.error("RECOGNITION_ERROR",
                                    exception?.message ?: "Unknown error", null)
                            }
                        }
                        override fun onTimeout() {
                            // Implementa se necessario
                        }
                    }
                    speechService = SpeechService(recognizer, 16000.0f)
                    speechService?.startListening(recognitionListener)
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
                    // Utilizza cancel() per "pausare" in quanto pause() non esiste
                    speechService?.cancel()
                } else {
                    recognitionListener?.let { listener ->
                        speechService?.startListening(listener)
                    }
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
