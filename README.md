<a href="https://www.spokestack.io/docs/react-native/getting-started" title="Getting Started with Spokestack + React Native">![React Native Spokestack](./example/react-native-spokestack.png)</a>

React Native plugin for adding voice using [Spokestack](https://www.spokestack.io). This includes speech recognition, wakeword, and natural language understanding, as well as synthesizing text to speech using Spokestack voices.

## Requirements

- _React Native_: 0.60.0+
- _Android_: Android SDK 21+
- _iOS_: iOS 13+

## Installation

[![](https://img.shields.io/npm/v/react-native-spokestack.svg)](https://www.npmjs.com/package/react-native-spokestack)

Using npm:

```sh
npm install --save react-native-spokestack
```

or using yarn:

```sh
yarn add react-native-spokestack
```

Then follow the instructions for each platform to link react-native-spokestack to your project:

## iOS installation

<details>
  <summary>iOS details</summary>

### Set deployment target

First, open XCode and go to Project -> Info to set the iOS Deployment target to 13.0 or higher.

Also, set deployment to 13.0 under Target -> General -> Deployment Info.

### Remove invalid library search path

When Flipper was introduced to React Native, some library search paths were set for Swift. There has been a longstanding issue with the default search paths in React Native projects because a search path was added for swift 5.0 which prevented any other React Native libraries from using APIs only available in Swift 5.2 or later. Spokestack-iOS, a dependency of react-native-spokestack makes use of these APIs and XCode will fail to build.

Fortunately, the fix is fairly simple. Go to your target -> Build Settings and search for "Library Search Paths".

Remove `"\"$(TOOLCHAIN_DIR)/usr/lib/swift-5.0/$(PLATFORM_NAME)\""` from the list.

### Edit Podfile

Before running `pod install`, make sure to make the following edits.

react-native-spokestack makes use of relatively new APIs only available in iOS 13+. Set the deployment target to iOS 13 at the top of your Podfile:

```ruby
platform :ios, '13.0'
```

We also need to use `use_frameworks!` in our Podfile in order to support dependencies written in Swift.

```ruby
target 'SpokestackExample' do
  use_frameworks!
  #...
```

For now, `use_frameworks!` does not work with Flipper, so we also need to disable Flipper. Remove any Flipper-related lines in your Podfile. In React Native 0.63.2+, they look like this:

```ruby
  # X Remove or comment out these lines X
  # use_flipper!
  # post_install do |installer|
  #   flipper_post_install(installer)
  # end
  # XX
```

#### Bug in React Native 0.64.0 (should be fixed in 0.64.1)

React Native 0.64.0 broke any projects using `use_frameworks!` in their Podfiles.

For more info on this bug, see https://github.com/facebook/react-native/issues/31149.

To workaround this issue, add the following to your Podfile:

```ruby
# Moves 'Generate Specs' build_phase to be first for FBReactNativeSpec
post_install do |installer|
  installer.pods_project.targets.each do |target|
    if (target.name&.eql?('FBReactNativeSpec'))
      target.build_phases.each do |build_phase|
        if (build_phase.respond_to?(:name) && build_phase.name.eql?('[CP-User] Generate Specs'))
          target.build_phases.move(build_phase, 0)
        end
      end
    end
  end
end
```

#### pod install

Remove your existing Podfile.lock and Pods folder to ensure no conflicts, then install the pods:

```sh
$ npx pod-install
```

### Edit Info.plist

Add the following to your Info.plist to enable permissions.

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app uses the microphone to hear voice commands</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to process voice commands</string>
```

#### Remove Flipper

While Flipper works on fixing their pod for `use_frameworks!`, we must disable Flipper. We already removed the Flipper dependencies from Pods above, but there remains some code in the AppDelegate.m that imports Flipper. There are two ways to fix this.

1. You can disable Flipper imports without removing any code from the AppDelegate. To do this, open your xcworkspace file in XCode. Go to your target, then Build Settings, search for "C Flags", remove `-DFB_SONARKIT_ENABLED=1` from flags.
1. Remove all Flipper-related code from your AppDelegate.m.

In our example app, we've done option 1 and left in the Flipper code in case they get it working in the future and we can add it back.

### Edit AppDelegate.m

#### Add AVFoundation to imports

```objc
#import <AVFoundation/AVFoundation.h>
```

#### AudioSession category

Set the AudioSession category. There are several configurations that work.

The following is a suggestion that should fit most use cases:

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory:AVAudioSessionCategoryPlayAndRecord
     mode:AVAudioSessionModeDefault
  options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowAirPlay | AVAudioSessionCategoryOptionAllowBluetoothA2DP | AVAudioSessionCategoryOptionAllowBluetooth
    error:nil];
  [session setActive:YES error:nil];

  // ...
```

</details>

## Android installation

<details>
  <summary>Android details</summary>

### ASR Support

The example usage uses the system-provided ASRs (`AndroidSpeechRecognizer` and `AppleSpeechRecognizer`). However, `AndroidSpeechRecognizer` is not available on 100% of devices. If your app supports a device that doesn't have built-in speech recognition, use Spokestack ASR instead by setting the `profile` to a Spokestack profile using the `profile` prop.

See our [ASR documentation](https://www.spokestack.io/docs/concepts/asr) for more information.

### Edit root build.gradle (_not_ app/build.gradle)

```groovy
// ...
  ext {
    // Minimum SDK is 21
    // React Native 0.64+ already has this set
    minSdkVersion = 21
// ...
  dependencies {
    // Minimium gradle is 3.0.1+
    // The latest React Native already has this
    classpath("com.android.tools.build:gradle:4.1.0")
```

### Edit AndroidManifest.xml

Add the necessary permissions to your `AndroidManifest.xml`. The first permission is often there already. The second is needed for using the microphone.

```xml
    <!-- For TTS -->
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- For wakeword and ASR -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <!-- For ensuring no downloads happen over cellular, unless forced -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Request RECORD_AUDIO permission

The RECORD_AUDIO permission is special in that it must be both listed in the `AndroidManifest.xml` as well as requested at runtime. There are a couple ways to handle this (react-native-spokestack does not do this for you):

1. **Recommended** Add a screen to your onboarding that explains the need for the permissions used on each platform (RECORD_AUDIO on Android and Speech Recognition on iOS). Have a look at [react-native-permissions](https://github.com/zoontek/react-native-permissions) to handle permissions in a more robust way.
2. Request the permissions only when needed, such as when a user taps on a "listen" button. Avoid asking for permission with no context or without explaining why it is needed. In other words, we do not recommend asking for permission on app launch.

While iOS will bring up permissions dialogs automatically for any permissions needed, you must do this manually in Android.

React Native already provides a module for this. See [React Native's PermissionsAndroid](https://reactnative.dev/docs/permissionsandroid) for more info.

</details>

## Usage

[Get started using Spokestack](https://www.spokestack.io/docs/React%20Native/getting-started), or check out our in-depth tutorials on [ASR](https://www.spokestack.io/docs/React%20Native/speech-pipeline), [NLU](https://www.spokestack.io/docs/React%20Native/nlu), and [TTS](https://www.spokestack.io/docs/React%20Native/tts). Also be sure to take a look at the [Cookbook](https://www.spokestack.io/docs/React%20Native/cookbook) for quick solutions to common problems.

A working example app is included in this repo in the `example/` folder.

```js
import Spokestack from 'react-native-spokestack'
import { View, Button, Text } from 'react-native'

function App() {
  const [listening, setListening] = useState(false)

  const onActivate = () => setListening(true)
  const onDeactivate = () => setListening(false)
  const onRecognize = ({ transcript }) => console.log(transcript)

  useEffect(() => {
    Spokestack.addEventListener('activate', onActivate)
    Spokestack.addEventListener('deactivate', onDeactivate)
    Spokestack.addEventListener('recognize', onRecognize)
    Spokestack.initialize(
      process.env.SPOKESTACK_CLIENT_ID,
      process.env.SPOKESTACK_CLIENT_SECRET
    )
      // This example starts the Spokestack pipeline immediately,
      // but it could be delayed until after onboarding or other
      // conditions have been met.
      .then(Spokestack.start)

    return () => {
      Spokestack.removeAllListeners()
    }
  }, [])

  return (
    <View>
      <Button onClick={() => Spokestack.activate()} title="Listen" />
      <Text>{listening ? 'Listening...' : 'Idle'}</Text>
    </View>
  )
}
```

## Including model files in your app bundle

To include model files locally in your app (rather than downloading them from a CDN), you also need to add the necessary extensions so
the files can be included by Babel. To do this, edit your [`metro.config.js`](https://facebook.github.io/metro/docs/configuration/).

```js
const defaults = require('metro-config/src/defaults/defaults')

module.exports = {
  resolver: {
    assetExts: defaults.assetExts.concat(['tflite', 'txt', 'sjson'])
  }
}
```

Then include model files using source objects:

```js
Spokestack.initialize(clientId, clientSecret, {
  wakeword: {
    filter: require('./filter.tflite'),
    detect: require('./detect.tflite'),
    encode: require('./encode.tflite')
  },
  nlu: {
    model: require('./nlu.tflite'),
    vocab: require('./vocab.txt'),
    // Be sure not to use "json" here.
    // We use a different extension (.sjson) so that the file is not
    // immediately parsed as json and instead
    // passes a require source object to Spokestack.
    // The special extension is only necessary for local files.
    metadata: require('./metadata.sjson')
  }
})
```

This is not required. Pass remote URLs to the same config options and the files will be downloaded and cached when first calling `initialize`.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

---

# API Documentation

### initialize

▸ **initialize**(`clientId`: _string_, `clientSecret`: _string_, `config?`: _[SpokestackConfig](#SpokestackConfig)_): _Promise_<void\>

Initialize the speech pipeline; required for all other methods.

The first 2 args are your Spokestack credentials
available for free from https://spokestack.io.
Avoid hardcoding these in your app.
There are several ways to include
environment variables in your code.

Using process.env:
https://babeljs.io/docs/en/babel-plugin-transform-inline-environment-variables/

Using a local .env file ignored by git:
https://github.com/goatandsheep/react-native-dotenv
https://github.com/luggit/react-native-config

See [SpokestackConfig](#SpokestackConfig) for all available options.

**`example`**

```js
import Spokestack from 'react-native-spokestack'

// ...

await Spokestack.initialize(process.env.CLIENT_ID, process.env.CLIENT_SECRET, {
  pipeline: {
    profile: Spokestack.PipelineProfile.PTT_NATIVE_ASR
  }
})
```

#### Parameters

| Name           | Type                                    |
| :------------- | :-------------------------------------- |
| `clientId`     | _string_                                |
| `clientSecret` | _string_                                |
| `config?`      | _[SpokestackConfig](#SpokestackConfig)_ |

**Returns:** _Promise_<void\>

Defined in: [index.ts:64](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L64)

### destroy

▸ **destroy**(): _Promise_<void\>

Destroys the speech pipeline, removes all listeners, and frees up all resources.
This can be called before re-initializing the pipeline.
A good place to call this is in `componentWillUnmount`.

**`example`**

```js
componentWillUnmount() {
  Spokestack.destroy()
}
```

**Returns:** _Promise_<void\>

Defined in: [index.ts:81](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L81)

### start

▸ **start**(): _Promise_<void\>

Start the speech pipeline.
The speech pipeline starts in the `deactivate` state.

**`example`**

```js
import Spokestack from 'react-native-spokestack`

// ...

Spokestack.initialize(process.env.CLIENT_ID, process.env.CLIENT_SECRET)
  .then(Spokestack.start)
```

**Returns:** _Promise_<void\>

Defined in: [index.ts:96](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L96)

### stop

▸ **stop**(): _Promise_<void\>

Stop the speech pipeline.
This effectively stops ASR, VAD, and wakeword.

**`example`**

```js
import Spokestack from 'react-native-spokestack`

// ...

await Spokestack.stop()
```

**Returns:** _Promise_<void\>

Defined in: [index.ts:110](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L110)

### activate

▸ **activate**(): _Promise_<void\>

Manually activate the speech pipeline.
This is necessary when using a PTT profile.
VAD profiles can also activate ASR without the need
to call this method.

**`example`**

```js
import Spokestack from 'react-native-spokestack`

// ...

<Button title="Listen" onClick={() => Spokestack.activate()} />
```

**Returns:** _Promise_<void\>

Defined in: [index.ts:126](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L126)

### deactivate

▸ **deactivate**(): _Promise_<void\>

Deactivate the speech pipeline.
If the profile includes wakeword, the pipeline will go back
to listening for the wakeword.
If VAD is active, the pipeline can reactivate without calling activate().

**`example`**

```js
import Spokestack from 'react-native-spokestack`

// ...

<Button title="Stop listening" onClick={() => Spokestack.deactivate()} />
```

**Returns:** _Promise_<void\>

Defined in: [index.ts:142](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L142)

### synthesize

▸ **synthesize**(`input`: _string_, `format?`: _[TTSFormat](#TTSFormat)_, `voice?`: _string_): _Promise_<string\>

Synthesize some text into speech
Returns `Promise<string>` with the string
being the URL for a playable mpeg.

There is currently only one free voice available ("demo-male").

**`example`**

```js
const url = await Spokestack.synthesize('Hello world')
play(url)
```

#### Parameters

| Name      | Type                      |
| :-------- | :------------------------ |
| `input`   | _string_                  |
| `format?` | _[TTSFormat](#TTSFormat)_ |
| `voice?`  | _string_                  |

**Returns:** _Promise_<string\>

Defined in: [index.ts:156](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L156)

### speak

▸ **speak**(`input`: _string_, `format?`: _[TTSFormat](#TTSFormat)_, `voice?`: _string_): _Promise_<void\>

Synthesize some text into speech
and then immediately play the audio through
the default audio system.
Audio session handling can get very complex and we recommend
using a RN library focused on audio for anything more than
very simple playback.

There is currently only one free voice available ("demo-male").

**`example`**

```js
await Spokestack.speak('Hello world')
```

#### Parameters

| Name      | Type                      |
| :-------- | :------------------------ |
| `input`   | _string_                  |
| `format?` | _[TTSFormat](#TTSFormat)_ |
| `voice?`  | _string_                  |

**Returns:** _Promise_<void\>

Defined in: [index.ts:172](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L172)

### classify

▸ **classify**(`utterance`: _string_): _Promise_<_SpokestackNLUResult_\>

Classify the utterance using the
intent/slot Natural Language Understanding model
passed to Spokestack.initialize().
See https://www.spokestack.io/docs/concepts/nlu for more info.

**`example`**

```js
const result = await Spokestack.classify('hello')

// Here's what the result might look like,
// depending on the NLU model
console.log(result.intent) // launch
```

#### Parameters

| Name        | Type     |
| :---------- | :------- |
| `utterance` | _string_ |

**Returns:** _Promise_<_SpokestackNLUResult_\>

Defined in: [index.ts:188](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L188)

### isInitialized

▸ **isInitialized**(): _Promise_<boolean\>

Returns whether Spokestack has been initialized

**`example`**

```js
console.log(`isInitialized: ${await Spokestack.isInitialized()}`)
```

**Returns:** _Promise_<boolean\>

Defined in: [index.ts:197](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L197)

### isStarted

▸ **isStarted**(): _Promise_<boolean\>

Returns whether the speech pipeline has been started

**`example`**

```js
console.log(`isStarted: ${await Spokestack.isStarted()}`)
```

**Returns:** _Promise_<boolean\>

Defined in: [index.ts:206](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L206)

### isActivated

▸ **isActivated**(): _Promise_<boolean\>

Returns whether the speech pipeline is currently activated

**`example`**

```js
console.log(`isActivated: ${await Spokestack.isActivated()}`)
```

**Returns:** _Promise_<boolean\>

Defined in: [index.ts:215](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L215)

## SpokestackNLUResult

### confidence

• **confidence**: _number_

A number from 0 to 1 representing the NLU model's confidence in the intent it recognized, where 1 represents absolute confidence.

Defined in: [types.ts:116](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L116)

### intent

• **intent**: _string_

The intent based on the match provided by the NLU model

Defined in: [types.ts:114](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L114)

### slots

• **slots**: _SpokestackNLUSlots_

Data associated with the intent, provided by the NLU model

Defined in: [types.ts:118](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L118)

# Interface: SpokestackNLUSlots

## Indexable

▪ [key: *string*]: _SpokestackNLUSlot_

## SpokestackNLUSlot

### rawValue

• **rawValue**: _string_

The original string value of the slot recognized in the user utterance

Defined in: [types.ts:105](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L105)

### type

• **type**: _string_

The slot's type, as defined in the model metadata

Defined in: [types.ts:101](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L101)

### value

• **value**: _any_

The parsed (typed) value of the slot recognized in the user utterance

Defined in: [types.ts:103](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L103)

### addEventListener

▸ **addEventListener**(`eventType`: _string_, `listener`: (`event`: _any_) => _void_, `context?`: Object): EmitterSubscription

Bind to any event emitted by the native libraries
The events are: "recognize", "partial_recognize", "error", "activate", "deactivate", and "timeout".
See the bottom of the README.md for descriptions of the events.

**`example`**

```js
useEffect(() => {
  const listener = Spokestack.addEventListener('recognize', onRecognize)
  // Unsubsribe by calling remove when components are unmounted
  return () => {
    listener.remove()
  }
}, [])
```

#### Parameters

| Name        | Type                       | Description                                             |
| :---------- | :------------------------- | :------------------------------------------------------ |
| `eventType` | _string_                   | name of the event for which we are registering listener |
| `listener`  | (`event`: _any_) => _void_ | the listener function                                   |
| `context?`  | Object                     | context of the listener                                 |

**Returns:** EmitterSubscription

Defined in: [index.ts:236](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L236)

### removeEventListener

▸ **removeEventListener**(`eventType`: _string_, `listener`: (...`args`: _any_[]) => _any_): _void_

Remove an event listener

**`example`**

```js
Spokestack.removeEventListener('recognize', onRecognize)
```

#### Parameters

| Name        | Type                          | Description                                            |
| :---------- | :---------------------------- | :----------------------------------------------------- |
| `eventType` | _string_                      | Name of the event to emit                              |
| `listener`  | (...`args`: _any_[]) => _any_ | Function to invoke when the specified event is emitted |

**Returns:** _void_

Defined in: [index.ts:252](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L252)

### removeAllListeners

▸ **removeAllListeners**(): _void_

Remove any existing listeners

**`example`**

```js
Spokestack.removeAllListeners()
```

**Returns:** _void_

Defined in: [index.ts:264](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/index.ts#L264)

#### TTSFormat

Three formats are supported when using Spokestack TTS.
Raw text, SSML, and Speech Markdown.
See https://www.speechmarkdown.org/ if unfamiliar with Speech Markdown.
IPA is expected when using SSML or Speech Markdown.

• **SPEECHMARKDOWN**: = 2

Defined in: [types.ts:74](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L74)

• **SSML**: = 1

Defined in: [types.ts:73](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L73)

• **TEXT**: = 0

Defined in: [types.ts:72](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L72)

---

# Events

Use `addEventListener()`, `removeEventListener()`, and `removeAllListeners()` to add and remove events handlers. All events are available in both iOS and Android.

| Name              |           Data           |                                                                   Description |
| :---------------- | :----------------------: | ----------------------------------------------------------------------------: |
| recognize         | `{ transcript: string }` |                     Fired whenever speech recognition completes successfully. |
| partial_recognize | `{ transcript: string }` |              Fired whenever the transcript changes during speech recognition. |
| timeout           |          `null`          |           Fired when an active pipeline times out due to lack of recognition. |
| activate          |          `null`          | Fired when the speech pipeline activates, either through the VAD or manually. |
| deactivate        |          `null`          |                                   Fired when the speech pipeline deactivates. |
| play              |  `{ playing: boolean }`  |         Fired when TTS playback starts and stops. See the `speak()` function. |
| error             |   `{ error: string }`    |                                    Fired when there's an error in Spokestack. |

_When an error event is triggered, any existing promises are rejected as it's difficult to know exactly from where the error originated and whether it may affect other requests._

---

## SpokestackConfig

These are the configuration options that can be passed to `Spokestack.initialize(_, _, spokestackConfig)`. No options in SpokestackConfig are required.

SpokestackConfig has the following structure:

```ts
interface SpokestackConfig {
  /**
   * This option is only used when remote URLs are passed to fields such as `wakeword.filter`.
   *
   * Set this to true to allow downloading models over cellular.
   * Note that `Spokestack.initialize()` will still reject the promise if
   * models need to be downloaded but there is no network at all.
   *
   * Ideally, the app will include network handling itself and
   * inform the user about file downloads.
   *
   * Default: false
   */
  allowCellularDownloads?: boolean
  /**
   * Wakeword, Keyword, and NLU model files are cached internally.
   * Set this to true whenever a model is changed
   * during development to refresh the internal model cache.
   *
   * This affects models passed with `require()` as well
   * as models downloaded from remote URLs.
   *
   * Default: true in dev mode, false otherwise
   *
   * **Important:** By default, apps in production will
   * cache models to avoid downloading them every time
   * the app is launched. The side-effect of this optimization
   * is that if models change on the CDN, apps will
   * not pick up those changes–unless the app were reinstalled.
   * We think this is a fair trade-off, but set this to `true`
   * if you prefer to download the models every time the app
   * is launched.
   */
  refreshModels?: boolean
  /**
   * This controls the log level for the underlying native
   * iOS and Android libraries.
   * See the TraceLevel enum for values.
   */
  traceLevel?: TraceLevel
  /**
   * Most of these options are advanced aside from "profile"
   */
  pipeline?: PipelineConfig
  /** Only needed if using Spokestack.classify */
  nlu?: NLUConfig
  /**
   * Only required for wakeword
   * Most options are advanced aside from
   * filter, encode, and decode for specifying config files.
   *
   * Keyword and wakeword should not be used together.
   * Specify one or the other.
   */
  wakeword?: WakewordConfig
  /**
   * Only required for the keyword recognizer
   * Most options are advanced aside from
   * filter, encode, decode, metadata, and classes.
   *
   * Keyword and wakeword should not be used together.
   * Specify one or the other.
   */
  keyword?: KeywordConfig
}
```

#### TraceLevel

How much logging to show
A lower number means more logs.

• **DEBUG**: = 10

Defined in: [types.ts:59](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L59)

• **INFO**: = 30

Defined in: [types.ts:61](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L61)

• **NONE**: = 100

Defined in: [types.ts:62](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L62)

• **PERF**: = 20

Defined in: [types.ts:60](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L60)

#### PipelineProfile

Pipeline profiles set up the speech pipeline based on your needs

• **PTT_NATIVE_ASR**: = 2

Apple/Android Automatic Speech Recogntion is on
when the speech pipeline is active.
This is likely the more common profile
when not using wakeword.

Defined in: [types.ts:24](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L24)

• **PTT_SPOKESTACK_ASR**: = 5

Spokestack Automatic Speech Recogntion is on
when the speech pipeline is active.
This is likely the more common profile
when not using wakeword, but Spokestack ASR is preferred.

Defined in: [types.ts:42](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L42)

• **TFLITE_WAKEWORD_KEYWORD**: = 6

VAD-sensitive TFLiteWakeword activates TFLite Keyword Recognizer
This is not yet supported on android

Defined in: [types.ts:47](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L47)

• **TFLITE_WAKEWORD_NATIVE_ASR**: = 0

Set up wakeword and use local Apple/Android ASR.
Note that wakeword.filter, wakeword.encode, and wakeword.detect
are required if any wakeword profile is used.

Defined in: [types.ts:12](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L12)

• **TFLITE_WAKEWORD_SPOKESTACK_ASR**: = 3

Set up wakeword and use remote Spokestack ASR.
Note that wakeword.filter, wakeword.encode, and wakeword.detect
are required if any wakeword profile is used.

Defined in: [types.ts:30](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L30)

• **VAD_KEYWORD_ASR**: = 7

VAD-triggered TFLite Keyword Recognizer

Defined in: [types.ts:51](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L51)

• **VAD_NATIVE_ASR**: = 1

Apple/Android Automatic Speech Recognition is on
when Voice Active Detection triggers it.

Defined in: [types.ts:17](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L17)

• **VAD_SPOKESTACK_ASR**: = 4

Spokestack Automatic Speech Recognition is on
when Voice Active Detection triggers it.

Defined in: [types.ts:35](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L35)

## Pipeline Config

### agcCompressionGainDb

• `Optional` **agcCompressionGainDb**: _number_

**`advanced`**

Android-only for AcousticGainControl

Target peak audio level, in -dB,
to maintain a peak of -9dB, configure a value of 9

Defined in: [types.ts:193](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L193)

### agcTargetLevelDbfs

• `Optional` **agcTargetLevelDbfs**: _number_

**`advanced`**

Android-only for AcousticGainControl

Dynamic range compression rate, in dBFS

Defined in: [types.ts:201](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L201)

### ansPolicy

• `Optional` **ansPolicy**: `"aggressive"` \| `"very-aggressive"` \| `"mild"` \| `"medium"`

**`advanced`**

Android-only for AcousticNoiseSuppressor

Noise policy

Defined in: [types.ts:184](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L184)

### bufferWidth

• `Optional` **bufferWidth**: _number_

**`advanced`**

Buffer width, used with frameWidth to determine the buffer size

Defined in: [types.ts:156](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L156)

### frameWidth

• `Optional` **frameWidth**: _number_

**`advanced`**

Speech frame width, in ms

Defined in: [types.ts:150](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L150)

### profile

• `Optional` **profile**: _PipelineProfile_

Profiles are collections of common configurations for Pipeline stages.

If no profile is set explicitly, Spokestack determines,
a sensible default profile based on the config
passed to `Spokestack.initialize()`:

If wakeword config files are set (and keyword config is not),
the default will be set to `TFLITE_WAKEWORD_NATIVE_ASR`.

If keyword config files are set (and wakeword config is not),
the default will be set to `VAD_KEYWORD_ASR`.

If both wakeword and keyword config files are set,
the default will be set to `TFLITE_WAKEWORD_KEYWORD`.

Otherwise, the default is `PTT_NATIVE_ASR`.

Defined in: [types.ts:140](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L140)

### sampleRate

• `Optional` **sampleRate**: _number_

Audio sampling rate, in Hz

Defined in: [types.ts:144](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L144)

### vadFallDelay

• `Optional` **vadFallDelay**: _number_

**`advanced`**

Falling-edge detection run length, in ms; this value determines
how many negative samples must be received to flip the detector to negative

Defined in: [types.ts:167](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L167)

### vadMode

• `Optional` **vadMode**: `"quality"` \| `"low-bitrate"` \| `"aggressive"` \| `"very-aggressive"`

Voice activity detector mode

Defined in: [types.ts:160](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L160)

### vadRiseDelay

• `Optional` **vadRiseDelay**: _number_

**`advanced`**

Android-only

Rising-edge detection run length, in ms; this value determines
how many positive samples must be received to flip the detector to positive

Defined in: [types.ts:176](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L176)

## NLU Config

### metadata

• **metadata**: _string_ \| _number_

The JSON file for NLU metadata. If specified, model and vocab are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `metadata: require('./metadata.sjson')`).

**IMPORTANT: a special extension is used for local metadata JSON files (`.sjson`) when using `require` or `import`
so the file is not parsed when included but instead imported as a source object. This makes it so the
file is read and parsed by the underlying native libraries instead.**

Defined in: [types.ts:224](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L224)

### model

• **model**: _string_ \| _number_

The NLU Tensorflow-Lite model. If specified, metadata and vocab are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `model: require('./nlu.tflite')`)

Defined in: [types.ts:212](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L212)

### vocab

• **vocab**: _string_ \| _number_

A txt file containing the NLU vocabulary. If specified, model and metadata are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `vocab: require('./vocab.txt')`)

Defined in: [types.ts:232](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L232)

### inputLength

• `Optional` **inputLength**: _number_

Defined in: [types.ts:245](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L245)

## Wakeword Config

### detect

• **detect**: _string_ \| _number_

The "detect" Tensorflow-Lite model. If specified, filter and encode are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `detect: require('./detect.tflite')`)

The encode model is used to perform each autoregressive step over the mel frames;
its inputs should be shaped [mel-length, mel-width], and its outputs [encode-width],
with an additional state input/output shaped [state-width]

Defined in: [types.ts:273](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L273)

### encode

• **encode**: _string_ \| _number_

The "encode" Tensorflow-Lite model. If specified, filter and detect are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `encode: require('./encode.tflite')`)

Its inputs should be shaped [encode-length, encode-width],
and its outputs

Defined in: [types.ts:284](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L284)

### filter

• **filter**: _string_ \| _number_

The "filter" Tensorflow-Lite model. If specified, detect and encode are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `filter: require('./filter.tflite')`)

The filter model is used to calculate a mel spectrogram frame from the linear STFT;
its inputs should be shaped [fft-width], and its outputs [mel-width]

Defined in: [types.ts:261](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L261)

### activeMax

• `Optional` **activeMax**: _number_

**`advanced`**

The maximum length of an activation, in milliseconds,
used to time out the activation

Defined in: [types.ts:374](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L374)

### activeMin

• `Optional` **activeMin**: _number_

**`advanced`**

The minimum length of an activation, in milliseconds,
used to ignore a VAD deactivation after the wakeword

Defined in: [types.ts:367](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L367)

### requestTimeout

• `Optional` **requestTimeout**: _number_

iOS-only

Length of time to allow an Apple ASR request to run, in milliseconds.
Apple has an undocumented limit of 60000ms per request.

Defined in: [types.ts:381](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L381)

### rmsAlpha

• `Optional` **rmsAlpha**: _number_

**`advanced`**
Android-only

The Exponentially-Weighted Moving Average (EWMA) update
rate for the current RMS signal energy (0 for no RMS normalization)

Defined in: [types.ts:398](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L398)

### rmsTarget

• `Optional` **rmsTarget**: _number_

**`advanced`**
Android-only

The desired linear Root Mean Squared (RMS) signal energy,
which is used for signal normalization and should be tuned
to the RMS target used during training

Defined in: [types.ts:390](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L390)

### wakewords

• `Optional` **wakewords**: _string_ \| _string_[]

iOS-only

An ordered array or comma-separated list of wakeword keywords
Only necessary when not passing the filter, detect, and encode paths.

Defined in: [types.ts:405](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L405)

## Keyword Config

### detect

• **detect**: _string_ \| _number_

The "detect" Tensorflow-Lite model. If specified, filter and encode are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `detect: require('./detect.tflite')`)

The encode model is used to perform each autoregressive step over the mel frames;
its inputs should be shaped [mel-length, mel-width], and its outputs [encode-width],
with an additional state input/output shaped [state-width]

Defined in: [types.ts:273](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L273)

### encode

• **encode**: _string_ \| _number_

The "encode" Tensorflow-Lite model. If specified, filter and detect are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `encode: require('./encode.tflite')`)

Its inputs should be shaped [encode-length, encode-width],
and its outputs

Defined in: [types.ts:284](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L284)

### filter

• **filter**: _string_ \| _number_

The "filter" Tensorflow-Lite model. If specified, detect and encode are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `filter: require('./filter.tflite')`)

The filter model is used to calculate a mel spectrogram frame from the linear STFT;
its inputs should be shaped [fft-width], and its outputs [mel-width]

Defined in: [types.ts:261](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L261)

Either `metadata` or `classes` is required, and they are mutually exclusive.

### metadata

• **metadata**: _string_ \| _number_

The JSON file for Keyword metadata.
Required if `keyword.classes` is not specified.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `metadata: require('./metadata.sjson')`).

**IMPORTANT: a special extension is used for local metadata JSON files (`.sjson`) when using `require` or `import`
so the file is not parsed when included but instead imported as a source object. This makes it so the
file is read and parsed by the underlying native libraries instead.**

Defined in: [types.ts:425](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L425)

### classes

• **classes**: _string_ \| _string_[]

A comma-separated list or an ordered array of class names for the keywords.
The name corresponding to the most likely class will be returned
in the transcript field when the recognition event is raised.
Required if `keyword.metadata` is not specified.

Defined in: [types.ts:435](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L435)

## Advanced Wakeword and Keyword Config

These properties can be passed to either the `wakeword` or `keyword` config object, but are not shared.

### encodeLength

• `Optional` **encodeLength**: _number_

**`advanced`**

The length of the sliding window of encoder output
used as an input to the classifier, in milliseconds

Defined in: [types.ts:294](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L294)

### encodeWidth

• `Optional` **encodeWidth**: _number_

**`advanced`**

The size of the encoder output, in vector units

Defined in: [types.ts:300](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L300)

### fftHopLength

• `Optional` **fftHopLength**: _number_

**`advanced`**

The length of time to skip each time the
overlapping STFT is calculated, in milliseconds

Defined in: [types.ts:323](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L323)

### fftWindowSize

• `Optional` **fftWindowSize**: _number_

**`advanced`**

The size of the signal window used to calculate the STFT,
in number of samples - should be a power of 2 for maximum efficiency

Defined in: [types.ts:307](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L307)

### fftWindowType

• `Optional` **fftWindowType**: _string_

**`advanced`**

Android-only

The name of the windowing function to apply to each audio frame
before calculating the STFT; currently the "hann" window is supported

Defined in: [types.ts:316](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L316)

### melFrameLength

• `Optional` **melFrameLength**: _number_

**`advanced`**

The length of time to skip each time the
overlapping STFT is calculated, in milliseconds

Defined in: [types.ts:330](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L330)

### melFrameWidth

• `Optional` **melFrameWidth**: _number_

**`advanced`**

The size of each mel spectrogram frame,
in number of filterbank components

Defined in: [types.ts:337](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L337)

### preEmphasis

• `Optional` **preEmphasis**: _number_

**`advanced`**

The pre-emphasis filter weight to apply to
the normalized audio signal (0 for no pre-emphasis)

Defined in: [types.ts:344](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L344)

### stateWidth

• `Optional` **stateWidth**: _number_

**`advanced`**

The size of the encoder state, in vector units (defaults to wake-encode-width)

Defined in: [types.ts:350](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L350)

### threshold

• `Optional` **threshold**: _number_

**`advanced`**

The threshold of the classifier's posterior output,
above which the trigger activates the pipeline, in the range [0, 1]

Defined in: [types.ts:357](https://github.com/spokestack/react-native-spokestack/blob/0da2270/src/types.ts#L357)

---

## License

Apache-2.0

Copyright 2021 Spokestack
