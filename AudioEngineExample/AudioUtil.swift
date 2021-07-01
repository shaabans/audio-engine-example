//
//  AudioUtil.swift
//  AudioEngineExample
//
//  Created by Sami Shaaban on 6/28/21.
//

import AVFoundation

class AudioUtil {
  var engine = AVAudioEngine()
  //var distortion = AVAudioUnitDistortion()
  //var reverb = AVAudioUnitReverb()
  //var delay = AVAudioUnitDelay()
  //var audioBuffer: AVAudioPCMBuffer?
  var format: AVAudioFormat?
  
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
      print("Sending \(frameCount) frames to mixer")
      for frame in 0 ..< Int(frameCount) {
        let value = self.processedAudioQueue.dequeue()
        for buffer in ablPointer {
          let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
          let bufCount = buf.count
          if frame < bufCount {
            buf[frame] = value ?? 0.0
          }
          //print("Value: \(value ?? 0.0)")
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
      try session.setCategory(AVAudioSession.Category.playAndRecord,
                              mode: AVAudioSession.Mode.voiceChat,
                              options: [.allowBluetooth])
      try session.setPreferredIOBufferDuration(4096.0 / 44100.0)
      try session.setActive(true)
    } catch {
      assertionFailure("AVAudioSession setup error: \(error)")
    }
    
    self.format = self.engine.outputNode.outputFormat(forBus: 0)
    
    self.engine.attach(srcNode)
    self.engine.connect(srcNode,
                        to: self.engine.mainMixerNode,
                        format: self.format)
    self.engine.connect(self.engine.mainMixerNode,
                        to: self.engine.outputNode,
                        format: self.format)
    self.engine.mainMixerNode.outputVolume = 1.0

    print("AudioEngine initialized")
  }
  
  func startRecording() {
    let input = self.engine.inputNode
    
    input.installTap(
      onBus: 0, bufferSize: AVAudioFrameCount(self.sampleSize * 4),
      format: input.inputFormat(forBus: 0),
      block: { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
        // Grab first channel (there are 2 channels coming in)
        let channel0Buffer: UnsafeMutablePointer<Float> = buffer!.floatChannelData!.pointee
        
        // Throw this frame into the raw audio data queue
        var audioFrame = [Float](repeating: 0.0, count: Int(buffer.frameLength))
        print("Buffer frameLength: \(buffer!.frameLength)")
        for index in 0 ..< buffer!.frameLength {
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
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
  }
  
  // Convert raw audio data to spectrogram output and processed audio output
  // and place on their respective queues
  func processData() {
    while rawAudioQueue.count > 0 {
      // Just copy data over for example
      processedAudioQueue.enqueue(rawAudioQueue.dequeue() ?? 0.0)
    }
    print("raw audio size: \(rawAudioQueue.count)")
    print("processed audio size: \(processedAudioQueue.count)")
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
