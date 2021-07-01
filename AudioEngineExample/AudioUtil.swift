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
  var format = AVAudioFormat()
  
  let dataProcessingDispatchQueue = DispatchQueue(label: "data.processing")
  var rawAudioQueue = Queue<Float>()
  var processedAudioQueue = Queue<Float>()
  let sampleSize = 1024
  
  // typealias AVAudioSourceNodeRenderBlock =
  // (UnsafeMutablePointer<ObjCBool>, UnsafePointer<AudioTimeStamp>, AVAudioFrameCount,
  //  UnsafeMutablePointer<AudioBufferList>) -> OSStatus
  private lazy var srcNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
    let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
    self.dataProcessingDispatchQueue.async {
      for frame in 0..<Int(frameCount) {
        let value = self.processedAudioQueue.dequeue()
        for buffer in ablPointer {
          let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
          buf[frame] = value ?? 0.0
          print("Value: \(value)")
        }
      }
    }
    return noErr
  }
  
  func initializeAudioEngine() {
    engine.stop()
    engine.reset()
    
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
    self.format = input.inputFormat(forBus: 0)
    
    engine.attach(srcNode)
    engine.connect(srcNode,
                   to: engine.mainMixerNode,
                   format: format)
    engine.connect(engine.mainMixerNode,
                   to: engine.outputNode,
                   format: format)
    engine.mainMixerNode.outputVolume = 0.5
    
    print("AudioEngine initialized")
  }
  
  func startRecording() {
    let mixer = engine.mainMixerNode
    
    mixer.installTap(onBus: 0, bufferSize: AVAudioFrameCount(self.sampleSize),
                     format: self.format, block:
                      { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
                        
                        // Grab first channel (there are 2 channels coming in)
                        let channel0Buffer: UnsafeMutablePointer<Float> = buffer.floatChannelData!.pointee
                    
                        // Throw this frame into the raw audio data queue
                        var audioFrame = [Float](repeating: 0.0, count: Int(buffer.frameLength))
                        for index in 0 ..< buffer.frameLength {
                          let value = channel0Buffer.advanced(by: Int(index)).pointee
                          audioFrame[Int(index)] = value
                        }
                        self.rawAudioQueue.enqueue(audioFrame)
                        
                        // Process the data on a serial queue
                        self.dataProcessingDispatchQueue.async {
                          self.processData()
                        }
                      })
    engine.prepare()
    try! engine.start()
  }
  
  func stopRecording() {
    engine.mainMixerNode.removeTap(onBus: 0)
    //engine.stop()
  }
  
  // Convert raw audio data to spectrogram output and processed audio output
  // and place on their respective queues
  func processData() {
    while rawAudioQueue.count >= self.sampleSize {
      
      let audioFrame = rawAudioQueue.dequeue(samples: self.sampleSize) ??
        [Float](repeating: 0.0, count: self.sampleSize)
      for index in 0 ..< audioFrame.count {
        // Just copy data over for example
        processedAudioQueue.enqueue(audioFrame[index])
      }
      print("raw audio size: \(rawAudioQueue.count)")
      print("processed audio size: \(processedAudioQueue.count)")
    }
    
  }
  
  class Queue<T> {
    private var elements: [T] = []
    
    func enqueue(_ value: T) {
      self.elements.append(value)
    }
    
    func enqueue(_ arrayValue: [T]) {
      for value in arrayValue {
        self.elements.append(value)
      }
    }
    
    func dequeue() -> T? {
      var output: T? = nil
      if !self.elements.isEmpty {
        output = self.elements.removeFirst()
      }
      return output
    }
    
    func dequeue(samples: Int) -> [T]? {
      var output: [T]? = nil
      if !self.elements.isEmpty && self.elements.count > samples {
        output = Array(self.elements[0 ..< samples])
        self.elements.removeFirst(samples)
      }
      return output
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
