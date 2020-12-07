import Spokestack

enum RNSpokestackError: Error {
    case notInitialized
    case notStarted
    case networkNotAvailable
    case networkStatusNotAvailable
}

extension RNSpokestackError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return NSLocalizedString("Spokestack has not yet been initialized. Call Spokestack.initialize()", comment: "")
        case .notStarted:
            return NSLocalizedString("Spokestack has not yet been started. Call Spokestack.start() before calling Spokestack.activate().", comment: "")
        case .networkNotAvailable:
            return NSLocalizedString("The network is not available. Check your network connection. If the network is cellular and you'd like to download over cellular, ensure allowCellular is set to true.", comment: "")
        case .networkStatusNotAvailable:
            return NSLocalizedString("The network status has not yet been set by iOS.", comment: "")
        }
    }
}

enum RNSpokestackPromise: String {
    case initialize
    case start
    case stop
    case activate
    case deactivate
    case synthesize
    case speak
    case classify
}

@objc(RNSpokestack)
class RNSpokestack: RCTEventEmitter, SpokestackDelegate {
    var speechPipelineBuilder: SpeechPipelineBuilder?
    var speechPipeline: SpeechPipeline?
    var speechConfig: SpeechConfiguration = SpeechConfiguration()
    var speechContext: SpeechContext?
    var synthesizer: TextToSpeech?
    var classifier: NLUTensorflow?
    var started = false
    var resolvers: [RNSpokestackPromise:RCTPromiseResolveBlock] = [:]
    var rejecters: [RNSpokestackPromise:RCTPromiseRejectBlock] = [:]
    var numRequests = 0
    var makeClassifer = false
    var downloader: Downloader?

    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }

    override func supportedEvents() -> [String]! {
        return ["activate", "deactivate", "timeout", "recognize", "partial_recognize", "play", "error", "trace"]
    }

    func handleError(_ error: Error) -> Void {
        print(error)
        sendEvent(withName: "error", body: [ "error": error.localizedDescription ])
    }

    func failure(error: Error) {
        handleError(error)

        // Reject all existing promises
        for (key, reject) in rejecters {
            let value = key.rawValue
            reject(String(format: "%@_error", value), String(format: "Spokestack error during %@.", value), error)
        }
        // Reset
        resolvers = [:]
        rejecters = [:]
    }

    func didTrace(_ trace: String) {
        sendEvent(withName: "trace", body: [ "message": trace ])
    }

    func didInit() {
        print("Spokestack initialized!")
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.initialize) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.initialize)
        }
    }

    func didActivate() {
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.activate) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.activate)
        }
        sendEvent(withName: "activate", body: [ "transcript": "" ])
    }

    func didDeactivate() {
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.deactivate) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.deactivate)
        }
        sendEvent(withName: "deactivate", body: [ "transcript": "" ])
    }

    func didStart() {
        started = true
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.start) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.start)
        }
    }

    func didStop() {
        started = false
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.stop) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.stop)
        }
    }

    func didTimeout() {
        sendEvent(withName: "timeout", body: [ "transcript": "" ])
    }

    func didRecognize(_ result: SpeechContext) {
        sendEvent(withName: "recognize", body: [ "transcript": result.transcript ])
    }

    func didRecognizePartial(_ result: SpeechContext) {
        sendEvent(withName: "partial_recognize", body: [ "transcript": result.transcript ])
    }

    func success(result: TextToSpeechResult) {
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.synthesize) {
            resolve(result.url)
            rejecters.removeValue(forKey: RNSpokestackPromise.synthesize)
        } else if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.speak) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.speak)
        }
    }

    func classification(result: NLUResult) {
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.classify) {
            for (name, slot) in result.slots! {
                print(name, slot)
            }
            resolve([
                "intent": result.intent,
                "confidence": result.confidence,
                "slots": result.slots!.map { (name, slot) in [
                    "type": slot.type,
                    "value": slot.value ?? nil,
                    "rawValue": slot.rawValue ?? nil
                ] }
            ])
            rejecters.removeValue(forKey: RNSpokestackPromise.classify)
        }
    }

    func didBeginSpeaking() {
        if let resolve = resolvers.removeValue(forKey: RNSpokestackPromise.speak) {
            resolve(nil)
            rejecters.removeValue(forKey: RNSpokestackPromise.speak)
        }
        sendEvent(withName: "play", body: [ "playing": true ])
    }

    func didFinishSpeaking() {
        sendEvent(withName: "play", body: [ "playing": false ])
    }

    func makeCompleteForModelDownload(speechProp: String) -> (Error?, String?) -> Void {
        return { (error: Error?, fileUrl: String?) -> Void in
            self.numRequests -= 1

            if (error != nil) {
                self.numRequests -= 1
                self.failure(error: error!)
            } else {
                // Set model path on speech config
                self.speechConfig.setValue(fileUrl, forKey: speechProp)

                // Build the pipeline if there are no more requests
                if self.numRequests <= 0 {
                    self.buildPipeline()
                }
            }
        }
    }

    func buildPipeline() {
        if speechPipeline != nil {
            return
        }
        if makeClassifer {
            do {
                try classifier = NLUTensorflow([self], configuration: speechConfig)
            } catch {
                failure(error: error)
                return
            }
        }
        if var builder = speechPipelineBuilder {
            builder = builder.setConfiguration(speechConfig)
            builder = builder.addListener(self)
            do {
                try speechPipeline = builder.build()
            } catch {
                failure(error: error)
            }
        }
    }

    /// Initialize the speech pipeline
    /// - Parameters:
    ///   - clientId: Spokestack client ID token available from https://spokestack.io
    ///   - clientSecret: Spokestack client Secret token available from https://spokestack.io
    ///   - config: Spokestack config object to be used for initializing the Speech Pipeline.
    ///     See https://github.com/spokestack/react-native-spokestack for available options
    @objc(initialize:withClientSecret:withConfig:withResolver:withRejecter:)
    func initialize(clientId: String, clientSecret: String, config: Dictionary<String, Any>?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if speechPipeline != nil {
            return
        }
        downloader = Downloader(allowCellular: RCTConvert.bool(config?["allowCellular"]), refreshModels: RCTConvert.bool(config?["refreshModels"]))
        speechContext = SpeechContext(speechConfig)
        speechConfig.apiId = clientId
        speechConfig.apiSecret = clientSecret
        speechPipelineBuilder = SpeechPipelineBuilder()
        speechPipelineBuilder = speechPipelineBuilder?.useProfile(SpeechPipelineProfiles.pushToTalkAppleSpeech)
        var nluFiles = 0
        for (key, value) in config! {
            switch key {
            case "traceLevel":
                speechConfig.tracing = Trace.Level(rawValue: RCTConvert.nsInteger(value)) ?? Trace.Level.NONE
                break
            case "nlu":
                // All values in pipeline are Strings
                // so no RCTConvert calls are needed
                for (nluKey, nluValue) in value as! Dictionary<String, String> {
                    switch nluKey {
                    case "model":
                        nluFiles += 1
                        numRequests += 1
                        downloader!.downloadModel(RCTConvert.nsurl(nluValue), makeCompleteForModelDownload(speechProp: "nluModelPath"))
                        break
                    case "metadata":
                        nluFiles += 1
                        numRequests += 1
                        downloader!.downloadModel(RCTConvert.nsurl(nluValue), makeCompleteForModelDownload(speechProp: "nluModelMetadataPath"))
                        break
                    case "vocab":
                        nluFiles += 1
                        numRequests += 1
                        downloader!.downloadModel(RCTConvert.nsurl(nluValue), makeCompleteForModelDownload(speechProp: "nluVocabularyPath"))
                        break
                    default:
                        break
                    }
                }
            case "wakeword":
                for (wakeKey, wakeValue) in value as! Dictionary<String, Any> {
                    switch wakeKey {
                    case "filter":
                        numRequests += 1
                        downloader!.downloadModel(RCTConvert.nsurl(wakeValue), makeCompleteForModelDownload(speechProp: "filterModelPath"))
                        break
                    case "detect":
                        numRequests += 1
                        downloader!.downloadModel(RCTConvert.nsurl(wakeValue), makeCompleteForModelDownload(speechProp: "detectModelPath"))
                        break
                    case "encode":
                        numRequests += 1
                        downloader!.downloadModel(RCTConvert.nsurl(wakeValue), makeCompleteForModelDownload(speechProp: "encodeModelPath"))
                        break
                    case "activeMin":
                        speechConfig.wakeActiveMin = RCTConvert.nsInteger(wakeValue)
                        break
                    case "activeMax":
                        speechConfig.wakeActiveMax = RCTConvert.nsInteger(wakeValue)
                        break
                    case "wakewords":
                        speechConfig.wakewords = RCTConvert.nsString(wakeValue)
                        break
                    case "requestTimeout":
                        speechConfig.wakewordRequestTimeout = RCTConvert.nsInteger(wakeValue)
                        break
                    case "threshold":
                        speechConfig.wakeThreshold = RCTConvert.nsNumber(wakeValue)!.floatValue
                        break
                    case "encodeLength":
                        speechConfig.encodeLength = RCTConvert.nsInteger(wakeValue)
                        break
                    case "stateWidth":
                        speechConfig.stateWidth = RCTConvert.nsInteger(wakeValue)
                        break
                    case "rmsTarget":
                        speechConfig.rmsTarget = RCTConvert.nsNumber(wakeValue)!.floatValue
                        break
                    case "rmsAlpha":
                        speechConfig.rmsAlpha = RCTConvert.nsNumber(wakeValue)!.floatValue
                        break
                    case "fftWindowSize":
                        speechConfig.fftWindowSize = RCTConvert.nsInteger(wakeValue)
                        break
                    case "fftWindowType":
                        speechConfig.fftWindowType = SignalProcessing.FFTWindowType(rawValue: RCTConvert.nsString(wakeValue)) ?? SignalProcessing.FFTWindowType.hann
                        break
                    case "fftHopLength":
                        speechConfig.fftHopLength = RCTConvert.nsInteger(wakeValue)
                        break
                    case "preEmphasis":
                        speechConfig.preEmphasis = RCTConvert.nsNumber(wakeValue)!.floatValue
                        break
                    case "melFrameLength":
                        speechConfig.melFrameLength = RCTConvert.nsInteger(wakeValue)
                        break
                    case "melFrameWidth":
                        speechConfig.melFrameWidth = RCTConvert.nsInteger(wakeValue)
                        break
                    default:
                        break
                    }
                }
            case "pipeline":
                // All values in pipeline happen to be Int
                // so no RCTConvert calls are needed
                for (pipelineKey, pipelineValue) in value as! Dictionary<String, Int> {
                    switch pipelineKey {
                    case "profile":
                        speechPipelineBuilder = speechPipelineBuilder?.useProfile(SpeechPipelineProfiles(rawValue: pipelineValue) ?? SpeechPipelineProfiles.pushToTalkAppleSpeech)
                        break
                    case "sampleRate":
                        speechConfig.sampleRate = pipelineValue
                        break
                    case "frameWidth":
                        speechConfig.frameWidth = pipelineValue
                        break
                    case "vadMode":
                        speechConfig.vadMode = VADMode(rawValue: pipelineValue) ?? VADMode.HighlyPermissive
                        break
                    case "vadFallDelay":
                        speechConfig.vadFallDelay = pipelineValue
                        break
                    default:
                        break
                    }
                }
                break
            default:
                break
            }
        }

        // Initialize TTS
        synthesizer = TextToSpeech([self], configuration: speechConfig)
        makeClassifer = nluFiles == 3

        resolvers[RNSpokestackPromise.initialize] = resolve
        rejecters[RNSpokestackPromise.initialize] = reject
        if numRequests == 0 {
            buildPipeline()
        }
    }

    /// Start the speech pipeline
    @objc(start:withRejecter:)
    func start(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let pipeline = speechPipeline {
            resolvers[RNSpokestackPromise.start] = resolve
            rejecters[RNSpokestackPromise.start] = reject
            pipeline.start()
        }
    }

    /// Start the speech pipeline
    @objc(stop:withRejecter:)
    func stop(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let pipeline = speechPipeline {
            resolvers[RNSpokestackPromise.stop] = resolve
            rejecters[RNSpokestackPromise.stop] = reject
            pipeline.stop()
        }
    }

    /// Manually activate the speech pipeline
    @objc(activate:withRejecter:)
    func activate(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if !started {
            reject(
                "not_started",
                "Spokestack.start() must be called before Spokestack.activate()",
                RNSpokestackError.notStarted
            )
            return
        }
        if let pipeline = speechPipeline {
            resolvers[RNSpokestackPromise.activate] = resolve
            rejecters[RNSpokestackPromise.activate] = reject
            pipeline.activate()
        }
    }

    /// Manually deactivate the speech pipeline
    @objc(deactivate:withRejecter:)
    func deactivate(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let pipeline = speechPipeline {
            resolvers[RNSpokestackPromise.deactivate] = resolve
            rejecters[RNSpokestackPromise.deactivate] = reject
            pipeline.deactivate()
        } else {
            reject(
                "not_initialized",
                "The Speech Pipeline is not initialized. Call Spokestack.initialize().",
                RNSpokestackError.notInitialized
            )
        }
    }

    /// Synthesize text into speech
    /// - Parameters:
    ///   - input: String of text to synthesize into speech.
    ///   - format?: See the TTSFormat enum. One of text, ssml, or speech markdown.
    ///   - voice?: A string indicating the desired Spokestack voice. The default is the free voice: "demo-male".
    @objc(synthesize:withFormat:withVoice:withResolver:withRejecter:)
    func synthesize(input: String, format: Int, voice: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let tts = synthesizer {
            resolvers[RNSpokestackPromise.synthesize] = resolve
            rejecters[RNSpokestackPromise.synthesize] = reject
            let ttsInput = TextToSpeechInput(input, voice: voice, inputFormat: TTSInputFormat(rawValue: format) ?? TTSInputFormat.text)
            tts.synthesize(ttsInput)
        } else {
            reject(
                "not_initialized",
                "Spokestack TTS is not initialized. Call Spokestack.initialize().",
                RNSpokestackError.notInitialized
            )
        }
    }

    /// Convenience method for synthesizing text to speech and
    /// playing it immediately.
    /// Audio session handling can get very complex and we recommend
    /// using a RN library focused on audio for anything more than playing
    /// through the default audio system.
    @objc(speak:withFormat:withVoice:withResolver:withRejecter:)
    func speak(input: String, format: Int, voice: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let tts = synthesizer {
            resolvers[RNSpokestackPromise.speak] = resolve
            rejecters[RNSpokestackPromise.speak] = reject
            let ttsInput = TextToSpeechInput(input, voice: voice, inputFormat: TTSInputFormat(rawValue: format) ?? TTSInputFormat.text)
            tts.speak(ttsInput)
        } else {
            reject(
                "not_initialized",
                "Spokestack TTS is not initialized. Call Spokestack.initialize().",
                RNSpokestackError.notInitialized
            )
        }
    }

    /// Classfiy an utterance using NLUTensorflow
    /// - Parameters:
    ///   - utterance: String utterance from the user
    @objc(classify:withResolver:withRejecter:)
    func classify(utterance: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
        if let nlu = classifier {
            resolvers[RNSpokestackPromise.classify] = resolve
            rejecters[RNSpokestackPromise.classify] = reject
            nlu.classify(utterance: utterance)
        } else {
            reject(
                "not_initialized",
                "Spokestack NLU is not initialized. Call Spokestack.initialize() with NLU file locations.",
                RNSpokestackError.notInitialized
            )
        }
    }
}
