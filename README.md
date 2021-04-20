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

---

# API Documentation

### initialize

▸ **initialize**(`clientId`: string, `clientSecret`: string, `config?`: [SpokestackConfig](#SpokestackConfig)): Promise\<void>

_Defined in [src/index.tsx:59](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L59)_

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

```js
import Spokestack from 'react-native-spokestack'

// ...

await Spokestack.initialize(process.env.CLIENT_ID, process.env.CLIENT_SECRET, {
  pipeline: {
    profile: Spokestack.PipelineProfile.PTT_NATIVE_ASR
  }
})
```

#### Parameters:

| Name           | Type                                  |
| -------------- | ------------------------------------- |
| `clientId`     | string                                |
| `clientSecret` | string                                |
| `config?`      | [SpokestackConfig](#SpokestackConfig) |

**Returns:** Promise\<void>

---

### start

▸ **start**(): Promise\<void>

_Defined in [src/index.tsx:77](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L77)_

Start the speech pipeline.
The speech pipeline starts in the `deactivate` state.

```js
import Spokestack from 'react-native-spokestack`

// ...

Spokestack.initialize(process.env.CLIENT_ID, process.env.CLIENT_SECRET)
  .then(Spokestack.start)
```

**Returns:** Promise\<void>

---

### stop

▸ **stop**(): Promise\<void>

_Defined in [src/index.tsx:90](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L90)_

Stop the speech pipeline.
This effectively stops ASR, VAD, and wakeword.

```js
import Spokestack from 'react-native-spokestack`

// ...

await Spokestack.stop()
```

**Returns:** Promise\<void>

---

### activate

▸ **activate**(): Promise\<void>

_Defined in [src/index.tsx:105](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L105)_

Manually activate the speech pipeline.
This is necessary when using a PTT profile.
VAD profiles can also activate ASR without the need
to call this method.

```js
import Spokestack from 'react-native-spokestack`

// ...

<Button title="Listen" onClick={() => Spokestack.activate()} />
```

**Returns:** Promise\<void>

---

### deactivate

▸ **deactivate**(): Promise\<void>

_Defined in [src/index.tsx:120](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L120)_

Deactivate the speech pipeline.
If the profile includes wakeword, the pipeline will go back
to listening for the wakeword.
If VAD is active, the pipeline can reactivate without calling activate().

```js
import Spokestack from 'react-native-spokestack`

// ...

<Button title="Stop listening" onClick={() => Spokestack.deactivate()} />
```

**Returns:** Promise\<void>

---

### synthesize

▸ **synthesize**(`input`: string, `format?`: [TTSFormat](#TTSFormat), `voice?`: string): Promise\<string>

_Defined in [src/index.tsx:133](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L133)_

Synthesize some text into speech
Returns `Promise<string>` with the string
being the URL for a playable mpeg.

There is currently only one free voice available ("demo-male").

```js
const url = await Spokestack.synthesize('Hello world')
play(url)
```

#### Parameters:

| Name      | Type                    |
| --------- | ----------------------- |
| `input`   | string                  |
| `format?` | [TTSFormat](#TTSFormat) |
| `voice?`  | string                  |

**Returns:** Promise\<string>

---

### speak

▸ **speak**(`input`: string, `format?`: [TTSFormat](#TTSFormat), `voice?`: string): Promise\<void>

_Defined in [src/index.tsx:148](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L148)_

Synthesize some text into speech
and then immediately play the audio through
the default audio system.
Audio session handling can get very complex and we recommend
using a RN library focused on audio for anything more than
very simple playback.

There is currently only one free voice available ("demo-male").

```js
await Spokestack.speak('Hello world')
```

#### Parameters:

| Name      | Type                    |
| --------- | ----------------------- |
| `input`   | string                  |
| `format?` | [TTSFormat](#TTSFormat) |
| `voice?`  | string                  |

**Returns:** Promise\<void>

---

### classify

▸ **classify**(`utterance`: string): Promise\<SpokestackNLUResult>

_Defined in [src/index.tsx:163](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L163)_

Classify the utterance using the
intent/slot Natural Language Understanding model
passed to Spokestack.initialize().
See https://www.spokestack.io/docs/concepts/nlu for more info.

```js
const result = await Spokestack.classify('hello')

// Here's what the result might look like,
// depending on the NLU model
console.log(result.intent) // launch
```

#### Parameters:

| Name        | Type   |
| ----------- | ------ |
| `utterance` | string |

**Returns:** Promise\<SpokestackNLUResult>

---

#### SpokestackNLUResult

##### intent

• **intent**: string

_Defined in [src/types.ts:101](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L101)_

The intent based on the match provided by the NLU model

---

##### confidence

• **confidence**: number

_Defined in [src/types.ts:103](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L103)_

A number from 0 to 1 representing the NLU model's confidence in the intent it recognized, where 1 represents absolute confidence.

---

##### slots

• **slots**: { [key:string]: SpokestackNLUSlot; }

_Defined in [src/types.ts:105](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L105)_

Data associated with the intent, provided by the NLU model

---

#### SpokestackNLUSlot

##### type

• **type**: string

_Defined in [src/types.ts:92](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L92)_

The slot's type, as defined in the model metadata

---

##### value

• **value**: any

_Defined in [src/types.ts:94](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L94)_

The parsed (typed) value of the slot recognized in the user utterance

---

##### rawValue

• **rawValue**: string

_Defined in [src/types.ts:96](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L96)_

The original string value of the slot recognized in the user utterance

### addEventListener

• **addEventListener**: _typeof_ addListener

_Defined in [src/index.tsx:203](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L203)_

Bind to any event emitted by the native libraries
The events are: "recognize", "partial_recognize", "error", "activate", "deactivate", and "timeout".
See the bottom of the README.md for descriptions of the events.

```js
useEffect(() => {
  const listener = Spokestack.addEventListener('recognize', onRecognize)
  // Unsubsribe by calling remove when components are unmounted
  return () => {
    listener.remove()
  }
}, [])
```

---

### removeEventListener

• **removeEventListener**: _typeof_ removeListener

_Defined in [src/index.tsx:211](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L211)_

Remove an event listener

```js
Spokestack.removeEventListener('recognize', onRecognize)
```

---

### removeAllListeners

• **removeAllListeners**: () => void

_Defined in [src/index.tsx:221](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/index.tsx#L221)_

Remove any existing listeners

```js
componentWillUnmount() {
  Spokestack.removeAllListeners()
}
```

---

### TTSFormat

• **SPEECHMARKDOWN**: = 2

_Defined in [src/types.ts:65](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L65)_

• **SSML**: = 1

_Defined in [src/types.ts:64](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L64)_

• **TEXT**: = 0

_Defined in [src/types.ts:63](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L63)_

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
   * Wakeword and NLU model files are cached internally.
   * Set this to true whenever a model is changed
   * during development to refresh the internal model cache.
   *
   * This affects models passed with `require()` as well
   * as models downloaded from remote URLs.
   *
   * Default: false
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
   */
  wakeword?: WakewordConfig
}
```

### TraceLevel

• **DEBUG**: = 10

_Defined in [src/types.ts:50](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L50)_

• **INFO**: = 30

_Defined in [src/types.ts:52](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L52)_

• **NONE**: = 100

_Defined in [src/types.ts:53](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L53)_

• **PERF**: = 20

_Defined in [src/types.ts:51](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L51)_

## PipelineConfig

### profile

• `Optional` **profile**: [PipelineProfile](#PipelineProfile)

_Defined in [src/types.ts:117](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L117)_

Profiles are collections of common configurations for Pipeline stages.
If Wakeword config files are specified, the default will be
`TFLITE_WAKEWORD_NATIVE_ASR`.
Otherwise, the default is `PTT_NATIVE_ASR`.

### PipelineProfile

• **PTT_NATIVE_ASR**: = 2

_Defined in [src/types.ts:24](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L24)_

Apple/Android Automatic Speech Recogntion is on
when the speech pipeline is active.
This is likely the more common profile
when not using wakeword.

• **PTT_SPOKESTACK_ASR**: = 5

_Defined in [src/types.ts:42](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L42)_

Spokestack Automatic Speech Recogntion is on
when the speech pipeline is active.
This is likely the more common profile
when not using wakeword, but Spokestack ASR is preferred.

• **TFLITE_WAKEWORD_NATIVE_ASR**: = 0

_Defined in [src/types.ts:12](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L12)_

Set up wakeword and use local Apple/Android ASR.
Note that wakeword.filter, wakeword.encode, and wakeword.detect
are required if any wakeword profile is used.

• **TFLITE_WAKEWORD_SPOKESTACK_ASR**: = 3

_Defined in [src/types.ts:30](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L30)_

Set up wakeword and use remote Spokestack ASR.
Note that wakeword.filter, wakeword.encode, and wakeword.detect
are required if any wakeword profile is used.

• **VAD_NATIVE_ASR**: = 1

_Defined in [src/types.ts:17](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L17)_

Apple/Android Automatic Speech Recognition is on
when Voice Active Detection triggers it.

• **VAD_SPOKESTACK_ASR**: = 4

_Defined in [src/types.ts:35](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L35)_

Spokestack Automatic Speech Recognition is on
when Voice Active Detection triggers it.

### sampleRate

• `Optional` **sampleRate**: number

_Defined in [src/types.ts:121](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L121)_

Audio sampling rate, in Hz

---

### frameWidth

• `Optional` **frameWidth**: number

_Defined in [src/types.ts:127](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L127)_

**`advanced`**

Speech frame width, in ms

---

### bufferWidth

• `Optional` **bufferWidth**: number

_Defined in [src/types.ts:133](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L133)_

**`advanced`**

Buffer width, used with frameWidth to determine the buffer size

---

### vadMode

• `Optional` **vadMode**: \"quality\" \| \"low-bitrate\" \| \"aggressive\" \| \"very-aggressive\"

_Defined in [src/types.ts:137](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L137)_

Voice activity detector mode

---

### vadFallDelay

• `Optional` **vadFallDelay**: number

_Defined in [src/types.ts:144](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L144)_

**`advanced`**

Falling-edge detection run length, in ms; this value determines
how many negative samples must be received to flip the detector to negative

---

### vadRiseDelay

• `Optional` **vadRiseDelay**: number

_Defined in [src/types.ts:153](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L153)_

**`advanced`**

Android-only

Rising-edge detection run length, in ms; this value determines
how many positive samples must be received to flip the detector to positive

---

### ansPolicy

• `Optional` **ansPolicy**: \"mild\" \| \"medium\" \| \"aggressive\" \| \"very-aggressive\"

_Defined in [src/types.ts:161](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L161)_

**`advanced`**

Android-only for AcousticNoiseSuppressor

Noise policy

---

### agcCompressionGainDb

• `Optional` **agcCompressionGainDb**: number

_Defined in [src/types.ts:170](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L170)_

**`advanced`**

Android-only for AcousticGainControl

Target peak audio level, in -dB,
to maintain a peak of -9dB, configure a value of 9

---

### agcTargetLevelDbfs

• `Optional` **agcTargetLevelDbfs**: number

_Defined in [src/types.ts:178](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L178)_

**`advanced`**

Android-only for AcousticGainControl

Dynamic range compression rate, in dBFS

## NLUConfig

### model

• **model**: string \| RequireSource

_Defined in [src/types.ts:189](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L189)_

The NLU Tensorflow-Lite model. If specified, metadata and vocab are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `model: require('./nlu.tflite')`)

---

### metadata

• **metadata**: string \| RequireSource

_Defined in [src/types.ts:197](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L197)_

The JSON file for NLU metadata. If specified, model and vocab are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `metadata: require('./metadata.json')`)

---

### vocab

• **vocab**: string \| RequireSource

_Defined in [src/types.ts:205](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L205)_

A txt file containing the NLU vocabulary. If specified, model and metadata are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `vocab: require('./vocab.txt')`)

---

### inputLength

• `Optional` **inputLength**: number

_Defined in [src/types.ts:215](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L215)_

## WakewordConfig

### filter

• **filter**: string \| RequireSource

_Defined in [src/types.ts:229](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L229)_

The "filter" Tensorflow-Lite model. If specified, detect and encode are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `filter: require('./filter.tflite')`)

The filter model is used to calculate a mel spectrogram frame from the linear STFT;
its inputs should be shaped [fft-width], and its outputs [mel-width]

---

### detect

• **detect**: string \| RequireSource

_Defined in [src/types.ts:241](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L241)_

The "detect" Tensorflow-Lite model. If specified, filter and encode are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `detect: require('./detect.tflite')`)

The encode model is used to perform each autoregressive step over the mel frames;
its inputs should be shaped [mel-length, mel-width], and its outputs [encode-width],
with an additional state input/output shaped [state-width]

---

### encode

• **encode**: string \| RequireSource

_Defined in [src/types.ts:252](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L252)_

The "encode" Tensorflow-Lite model. If specified, filter and detect are also required.

This field accepts 2 types of values.

1. A string representing a remote URL from which to download and cache the file (presumably from a CDN).
2. A source object retrieved by a `require` or `import` (e.g. `encode: require('./encode.tflite')`)

Its inputs should be shaped [encode-length, encode-width],
and its outputs

---

### activeMax

• `Optional` **activeMax**: number

_Defined in [src/types.ts:262](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L262)_

The maximum length of an activation, in milliseconds,
used to time out the activation

---

### activeMin

• `Optional` **activeMin**: number

_Defined in [src/types.ts:257](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L257)_

The minimum length of an activation, in milliseconds,
used to ignore a VAD deactivation after the wakeword

---

### encodeLength

• `Optional` **encodeLength**: number

_Defined in [src/types.ts:290](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L290)_

**`advanced`**

The length of the sliding window of encoder output
used as an input to the classifier, in milliseconds

---

### encodeWidth

• `Optional` **encodeWidth**: number

_Defined in [src/types.ts:296](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L296)_

**`advanced`**

The size of the encoder output, in vector units

---

### fftHopLength

• `Optional` **fftHopLength**: number

_Defined in [src/types.ts:340](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L340)_

**`advanced`**

The length of time to skip each time the
overlapping STFT is calculated, in milliseconds

---

### fftWindowSize

• `Optional` **fftWindowSize**: number

_Defined in [src/types.ts:324](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L324)_

**`advanced`**

The size of the signal window used to calculate the STFT,
in number of samples - should be a power of 2 for maximum efficiency

---

### fftWindowType

• `Optional` **fftWindowType**: string

_Defined in [src/types.ts:333](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L333)_

**`advanced`**

Android-only

The name of the windowing function to apply to each audio frame
before calculating the STFT; currently the "hann" window is supported

---

### melFrameLength

• `Optional` **melFrameLength**: number

_Defined in [src/types.ts:354](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L354)_

**`advanced`**

The length of time to skip each time the
overlapping STFT is calculated, in milliseconds

---

### melFrameWidth

• `Optional` **melFrameWidth**: number

_Defined in [src/types.ts:361](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L361)_

**`advanced`**

The size of each mel spectrogram frame,
in number of filterbank components

---

### preEmphasis

• `Optional` **preEmphasis**: number

_Defined in [src/types.ts:347](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L347)_

**`advanced`**

The pre-emphasis filter weight to apply to
the normalized audio signal (0 for no pre-emphasis)

---

### requestTimeout

• `Optional` **requestTimeout**: number

_Defined in [src/types.ts:276](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L276)_

iOS-only

Length of time to allow an Apple ASR request to run, in milliseconds.
Apple has an undocumented limit of 60000ms per request.

---

### rmsAlpha

• `Optional` **rmsAlpha**: number

_Defined in [src/types.ts:317](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L317)_

**`advanced`**

The Exponentially-Weighted Moving Average (EWMA) update
rate for the current RMS signal energy (0 for no RMS normalization)

---

### rmsTarget

• `Optional` **rmsTarget**: number

_Defined in [src/types.ts:310](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L310)_

**`advanced`**

The desired linear Root Mean Squared (RMS) signal energy,
which is used for signal normalization and should be tuned
to the RMS target used during training

---

### stateWidth

• `Optional` **stateWidth**: number

_Defined in [src/types.ts:302](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L302)_

**`advanced`**

The size of the encoder state, in vector units (defaults to wake-encode-width)

---

### threshold

• `Optional` **threshold**: number

_Defined in [src/types.ts:283](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L283)_

**`advanced`**

The threshold of the classifier's posterior output,
above which the trigger activates the pipeline, in the range [0, 1]

---

### wakewords

• `Optional` **wakewords**: string

_Defined in [src/types.ts:269](https://github.com/spokestack/react-native-spokestack/blob/f0ba05b/src/types.ts#L269)_

iOS-only

A comma-separated list of wakeword keywords
Only necessary when not passing the filter, detect, and encode paths.

---

## License

Apache-2.0

Copyright 2021 Spokestack
