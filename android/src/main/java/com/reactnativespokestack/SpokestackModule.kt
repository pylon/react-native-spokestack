package com.reactnativespokestack

import android.net.Uri
import android.util.Log
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import io.spokestack.spokestack.PipelineProfile
import io.spokestack.spokestack.Spokestack
import io.spokestack.spokestack.profile.*
import io.spokestack.spokestack.tts.AudioResponse
import io.spokestack.spokestack.tts.SpokestackTTSOutput
import io.spokestack.spokestack.tts.SynthesisRequest
import javax.annotation.Nullable

class SpokestackModule(private val reactContext: ReactApplicationContext): ReactContextBaseJavaModule(reactContext) {
  private val adapter = SpokestackAdapter { event: String, data: WritableMap -> sendEvent(event, data) }
  private lateinit var spokestack: Spokestack
  private val promises = mutableMapOf<SpokestackPromise, Promise>()
  private var say: ((url: String) -> Unit)? = null
  private lateinit var audioPlayer: SpokestackTTSOutput
  private lateinit var downloader: Downloader

  override fun getName(): String {
    return "Spokestack"
  }

  override fun onCatalystInstanceDestroy() {
    super.onCatalystInstanceDestroy()
    if (spokestack.speechPipeline != null) {
      spokestack.stop()
    }
  }

  private enum class SpokestackPromise {
    SYNTHESIZE,
    SPEAK,
    CLASSIFY
  }

  private enum class Filenames(val value: String) {
    WakewordFilter("filter.tflite"),
    WakewordDetect("detect.tflite"),
    WakewordEncode("encode.tflite"),
    NluModel("nlu.tflite"),
    NluMetadata("metadata.json"),
    NluVocab("vocab.txt");
  }

  private enum class PipelineProfiles(p:Class<out PipelineProfile>) {
    TFLiteWakewordNativeASR(TFWakewordAndroidASR::class.java),
    VADNativeASR(VADTriggerAndroidASR::class.java),
    PTTNativeASR(PushToTalkAndroidASR::class.java),
    TFLiteWakewordSpokestackASR(TFWakewordSpokestackASR::class.java),
    VADSpokestackASR(VADTriggerSpokestackASR::class.java),
    PTTSpokestackASR(PushToTalkSpokestackASR::class.java);
    private val profile:Class<out PipelineProfile> = p
    fun value():String {
      return this.profile.name
    }
  }

  private fun sendEvent(event:String, @Nullable params:WritableMap) {
    if (reactContext.hasActiveCatalystInstance()) {
      when(event.toLowerCase()) {
        "error" -> {
          // Reject all existing promises
          for ((key, promise) in promises) {
            promise.reject(Exception("Error in Spokestack during ${key.name}."))
          }
          promises.clear()
        }
        "synthesize" -> {
          val url = params.getString("url")
          promises[SpokestackPromise.SYNTHESIZE]?.resolve(url)
          promises.remove(SpokestackPromise.SYNTHESIZE)
          if (say != null && url != null) {
            say!!(url)
            say = null
          }
        }
        "classify" -> {
          promises[SpokestackPromise.CLASSIFY]?.resolve(params.getMap("result"))
          promises.remove(SpokestackPromise.CLASSIFY)
        }
        else -> Log.d(name, "Sending JS event: $event")
      }
      reactContext
        .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
        .emit(event.toLowerCase(), params)
    }
  }

  private fun kebabCase(str: String): String {
    return str.replace(Regex("([a-z])([A-Z])")) {
      m -> "${m.groupValues[1]}-${m.groupValues[2].toLowerCase()}"
    }
  }

  private fun textToSpeech(input: String, format: Int, voice: String) {
    if (format > 2 || format < 0) {
      throw Exception(("A format of $format is not supported. Please use an int from 0 to 2 (or use the TTSFormat enum). Refer to documentation for further details."))
    }
    val req = SynthesisRequest.Builder(input)
      .withMode(SynthesisRequest.Mode.values()[format])
      .withVoice(voice)
      .build()
    spokestack.synthesize(req)
  }

  @ReactMethod
  @Throws(Exception::class)
  fun initialize(clientId: String, clientSecret: String, config: ReadableMap, promise: Promise) {
    if (clientId.isEmpty() || clientSecret.isEmpty()) {
      val e = IllegalArgumentException("Client ID and Client Secret are required to initialize Spokestack")
      promise.reject(e)
      return
    }
    val builder = Spokestack.Builder()
    builder.addListener(adapter)
    builder.withAndroidContext(reactContext.applicationContext)
    builder.setProperty("spokestack-id", clientId)
    builder.setProperty("spokestack-secret", clientSecret)

    downloader = Downloader(
      reactContext.applicationContext,
      if (config.hasKey("allowCellular")) config.getBoolean("allowCellular") else false,
      if (config.hasKey("refreshModels")) config.getBoolean("refreshModels") else false
    )

    // Top-level config
    if (config.hasKey("traceLevel")) {
      builder.setProperty("trace-level", config.getInt("traceLevel"))
    }
    // SpeechPipeline
    // Default to PTT
    builder.pipelineBuilder.useProfile(PipelineProfiles.PTTNativeASR.value())
    if (config.hasKey("pipeline")) {
      val map = config.getMap("pipeline")?.toHashMap()
      if (map != null) {
        for (key in map.keys) {
          // JS uses camelCase for keys
          // Convert to kebab-case
          builder.setProperty(kebabCase(key), map[key])
        }
        if (map.containsKey("profile")) {
          val profile = PipelineProfiles.values()[(map["profile"] as Double).toInt()]
          builder.pipelineBuilder.useProfile(profile.value())
        }
      }
    }
    // Wakeword
    var wakeFiles = 0
    if (config.hasKey("wakeword")) {
      val map = config.getMap("wakeword")?.toHashMap()
      if (map != null) {
        for (key in map.keys) {
          // Map JS keys to Android keys
          when (key) {
            "filter" -> {
              wakeFiles++
              builder.setProperty(
                "wake-filter-path",
                downloader.downloadModel(Filenames.WakewordFilter.value, map[key] as String)
              )
            }
            "detect" -> {
              wakeFiles++
              builder.setProperty(
                "wake-detect-path",
                downloader.downloadModel(Filenames.WakewordDetect.value, map[key] as String)
              )
            }
            "encode" -> {
              wakeFiles++
              builder.setProperty(
                "wake-encode-path",
                downloader.downloadModel(Filenames.WakewordEncode.value, map[key] as String)
              )
            }
            "activeMin" -> builder.setProperty("wake-active-min", map[key])
            "activeMax" -> builder.setProperty("wake-active-max", map[key])
            "encodeLength" -> builder.setProperty("wake-encode-length", map[key])
            "encodeWidth" -> builder.setProperty("wake-encode-width", map[key])
            "stateWidth" -> builder.setProperty("wake-state-width", map[key])
            "threshold" -> builder.setProperty("wake-threshold", map[key])
            else -> builder.setProperty(kebabCase(key), map[key])
          }
        }
      }
    }

    // Wakeword needs all three config paths
    if (wakeFiles != 3) {
      Log.d(name, "Not enough wakeword config files. Building without wakeword.")
      builder.withoutWakeword()
    } else {
      Log.d(name, "Building with wakeword.")
    }

    // NLU
    var nluFiles = 0
    if (config.hasKey("nlu")) {
      val map = config.getMap("nlu")?.toHashMap()
      if (map != null) {
        for (key in map.keys) {
          // Map JS keys to Android keys
          when (key) {
            "model" -> {
              nluFiles++
              builder.setProperty(
                "nlu-model-path",
                downloader.downloadModel(Filenames.NluModel.value, map[key] as String)
              )
            }
            "metadata" -> {
              nluFiles++
              builder.setProperty(
                "nlu-metadata-path",
                downloader.downloadModel(Filenames.NluMetadata.value, map[key] as String)
              )
            }
            "vocab" -> {
              nluFiles++
              builder.setProperty(
                "wordpiece-vocab-path",
                downloader.downloadModel(Filenames.NluVocab.value, map[key] as String)
              )
            }
            "inputLength" -> builder.setProperty("nlu-input-length", map[key])
          }
        }
      }
    }

    if (nluFiles != 3) {
      Log.d(name, "Not enough NLU config files. Building without NLU.")
      builder.withoutNlu()
    } else {
      Log.d(name, "Building with NLU.")
    }

    // TTS is automatically built and available
    builder.withoutAutoPlayback()

    // Initialize the audio player for speaking
    audioPlayer = SpokestackTTSOutput(null)
    audioPlayer.setAndroidContext(reactContext.applicationContext)
    audioPlayer.addListener(adapter)

    spokestack = builder.build()
    promise.resolve(null)
  }

  @ReactMethod
  @Throws(Exception::class)
  fun start(promise: Promise) {
    try {
      spokestack.start()
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject(e)
    }
  }

  @ReactMethod
  fun stop(promise: Promise) {
    try {
      spokestack.stop()
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject(e)
    }
  }

  @ReactMethod
  fun activate(promise: Promise) {
    if (!spokestack.speechPipeline.isRunning) {
      promise.reject(Exception("The speech pipeline is not yet running. Call Spokestack.start() before calling Spokestack.activate()."))
      return
    }
    try {
      spokestack.activate()
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject(e)
    }
  }

  @ReactMethod
  fun deactivate(promise: Promise) {
    try {
      spokestack.deactivate()
      promise.resolve(null)
    } catch (e: Exception) {
      promise.reject(e)
    }
  }

  @ReactMethod
  fun synthesize(input: String, format: Int, voice: String, promise: Promise) {
    promises[SpokestackPromise.SYNTHESIZE] = promise
    try {
      textToSpeech(input, format, voice)
    } catch (e: Exception) {
      promise.reject(e)
      promises.remove(SpokestackPromise.SYNTHESIZE)
    }
  }

  @ReactMethod
  fun speak(input: String, format: Int, voice: String, promise: Promise) {
    promises[SpokestackPromise.SPEAK] = promise
    say = { url ->
      Log.d(name,"Playing audio from URL: $url")
      val uri = Uri.parse(url)
      val response = AudioResponse(uri)
      audioPlayer.audioReceived(response)

      /* TODO: Change this to a playback started listener when spokestack-android supports it. */
      val reactEvent = Arguments.createMap()
      reactEvent.putBoolean("playing", true)
      sendEvent("play", reactEvent)

      // Resolve RN promise
      promise.resolve(null)
      promises.remove(SpokestackPromise.SPEAK)
    }
    try {
      textToSpeech(input, format, voice)
    } catch (e: Exception) {
      promise.reject(e)
      promises.remove(SpokestackPromise.SPEAK)
    }
  }

  @ReactMethod
  fun classify(utterance:String, promise: Promise) {
    promises[SpokestackPromise.CLASSIFY] = promise
    spokestack.classify(utterance)
  }
}
