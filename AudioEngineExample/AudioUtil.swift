//
//  AudioUtil.swift
//  AudioEngineExample
//
//  Created by Sami Shaaban on 6/28/21.
//

import AVFoundation

class AudioUtil {
  var engine = AVAudioEngine()
  var distortion = AVAudioUnitDistortion()
  var reverb = AVAudioUnitReverb()
  var audioBuffer = AVAudioPCMBuffer()
  var outputFile = AVAudioFile()
  var delay = AVAudioUnitDelay()
  
  let dataProcessingDispatchQueue = DispatchQueue(label: "data.processing")
  var rawAudioQueue: Queue = Queue<Float>()
  var processedAudioQueue: Queue = Queue<Float>()
  let sampleSize = 1024
  
  func initializeAudioEngine() {
    engine.stop()
    engine.reset()
    engine = AVAudioEngine()
    
    do {
      let session = AVAudioSession.sharedInstance()
      let ioBufferDuration = 128.0 / 44100.0
      try session.setCategory(AVAudioSession.Category.playAndRecord,
                              mode: AVAudioSession.Mode.default,
                              options: [.allowBluetooth])
      try session.setPreferredIOBufferDuration(ioBufferDuration)
      try session.setActive(true)
    } catch {
      assertionFailure("AVAudioSession setup error: \(error)")
    }
    
    let input = engine.inputNode
    let format = input.inputFormat(forBus: 0)
    
    //settings for reverb
    reverb.loadFactoryPreset(.mediumChamber)
    reverb.wetDryMix = 40 //0-100 range
    engine.attach(reverb)
    
    delay.delayTime = 0.2 // 0-2 range
    engine.attach(delay)
    
    //settings for distortion
    distortion.loadFactoryPreset(.drumsBitBrush)
    distortion.wetDryMix = 20 //0-100 range
    engine.attach(distortion)
    
    
    engine.connect(input, to: reverb, format: format)
    engine.connect(reverb, to: distortion, format: format)
    engine.connect(distortion, to: delay, format: format)
    engine.connect(delay, to: engine.mainMixerNode, format: format)
    
    try! engine.start()
  }
  
  func startRecording() {
    let mixer = engine.mainMixerNode
    let format = mixer.outputFormat(forBus: 0)
    
    mixer.installTap(onBus: 0, bufferSize: 1024, format: format, block:
                      { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                        
                        // Grab first channel (there are 2 channels coming in)
                        let channel0Buffer: UnsafeMutablePointer<Float> = buffer.floatChannelData!.pointee

                        // Throw this frame into the raw audio data queue
                        for index in 0 ..< buffer.frameLength {
                          let value = channel0Buffer.advanced(by: Int(index)).pointee
                          self.rawAudioQueue.enqueue(value)
                        }
                        
                        // Process the data on a serial queue ... will this gum up the main thread?
                        self.dataProcessingDispatchQueue.async {
                          self.processData()
                        }
                      })
  }
  
  func stopRecording() {
    engine.mainMixerNode.removeTap(onBus: 0)
    //engine.stop()
  }
  
  // Convert raw audio data to spectrogram output and processed audio output
  func processData() {
    while rawAudioQueue.count >= self.sampleSize {
      for _ in 0 ..< self.sampleSize {
        // Just copy data over for example
        processedAudioQueue.enqueue(rawAudioQueue.dequeue()!)
      }
      print("raw audio size: \(rawAudioQueue.count)")
      print("processed audio size: \(processedAudioQueue.count)")
    }
  }
  
  struct Queue<T> {
    private var elements: [T] = []
    
    mutating func enqueue(_ value: T) {
      elements.append(value)
    }
    
    mutating func dequeue() -> T? {
      guard !elements.isEmpty else {
        return nil
      }
      return elements.removeFirst()
    }
    
    var count: Int {
      return elements.count
    }
    
    var head: T? {
      return elements.first
    }
    
    var tail: T? {
      return elements.last
    }
  }
  
}
