# Real-time AVAudioEngine Example

A quick example of using 
[AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine)
to process audio from a device's mic then send it to the output.

The processing done in this example is run a forward
[discreet cosine transform](https://developer.apple.com/documentation/accelerate/vdsp/dct)
(DCT) on samples of raw mic input, do something with the resulting
frequency domain data, then use a reverse DCT to convert it back
to time-based audio, and play it through the selected output.

## How to Run
This should run fine on an XCode simulator, or on your device.

## Compatible Devices
Note that it has only been tested on an iPhone 12 Pro, and
even on that speedy device we have to drop some raw audio with
the example of processing using a forward and reverse discrete
cosine transform.

## Authors
- [@shaabans](https://github.com/shaabans)
