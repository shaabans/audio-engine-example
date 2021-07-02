//
//  AudioUtil.swift
//  AudioEngineExample
//
//  Created by Sami Shaaban on 6/28/21.
//

import AVFoundation

class AudioUtil {
  var engine = AVAudioEngine()
  var format: AVAudioFormat?
  var isListening = false
  
  let dataProcessingDispatchQueue = DispatchQueue(label: "data.processing")
  var rawAudioQueue = Queue<Float>()
  var processedAudioQueue = Queue<Float>()
  let sampleSize = 1024
  
  // typealias AVAudioSourceNodeRenderBlock =
  // (UnsafeMutablePointer<ObjCBool>, UnsafePointer<AudioTimeStamp>, AVAudioFrameCount,
  //  UnsafeMutablePointer<AudioBufferList>) -> OSStatus
  private lazy var srcNode = AVAudioSourceNode(format: self.format!, renderBlock:
    { _, _, frameCount, audioBufferList -> OSStatus in
      let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
      self.dataProcessingDispatchQueue.async {
        //print("Sending \(frameCount) frames to mixer")
        for frame in 0 ..< Int(frameCount) {
          let value = self.processedAudioQueue.dequeue()
          for buffer in ablPointer {
            let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
            let bufCount = buf.count
            if frame < bufCount && self.isListening {
              buf[frame] = value ?? 0.0
            }
          }
        }
      }
      return noErr
    })
  
  func initializeAudioEngine() {
    engine.stop()
    engine.reset()
    let session = AVAudioSession.sharedInstance()
    
    do {
      try session.setCategory(AVAudioSession.Category.playAndRecord,
                              mode: AVAudioSession.Mode.default,
                              options: [.allowBluetooth])
      //try session.setPreferredIOBufferDuration(256.0 / 44100.0) // About 6ms
      if let phoneMicIndex = AVAudioSession.sharedInstance().availableInputs?.firstIndex(where: { $0.portType == .builtInMic }) {
        try AVAudioSession.sharedInstance().setPreferredInput(AVAudioSession.sharedInstance().availableInputs?[phoneMicIndex])
      }
      try session.setInputGain(1.0)
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
    
    print("Available Inputs")
    let inputs = session.availableInputs
    for input in inputs! {
      print(input)
    }
  }
  
  func startRecording() {
    let input = self.engine.inputNode
    
    input.installTap(
      onBus: 0, bufferSize: AVAudioFrameCount(self.sampleSize),
      format: self.format,
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
    
    //self.initializeAudioEngine()
    self.engine.prepare()
    try! engine.start()
    self.isListening = true
  }
  
  func stopRecording() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    self.isListening = false
  }
  
  // Convert raw audio data to spectrogram output and processed audio output
  // and place on their respective queues
  func processData() {
    while rawAudioQueue.count > 0 {
      // Just copy data over for example
      processedAudioQueue.enqueue(rawAudioQueue.dequeue() ?? 0.0)
    }
    print("processed audio beyind by: \(processedAudioQueue.enqueueCounter - processedAudioQueue.dequeueCounter)")
  }
  
  struct Queue<T> {
    private var elements: [T] = []
    public var enqueueCounter: Int = 0
    public var dequeueCounter: Int = 0
    
    mutating func enqueue(_ value: T) {
      self.elements.append(value)
      self.enqueueCounter += 1
    }
    
    mutating func enqueue(_ arrayValue: [T]) {
      for value in arrayValue {
        self.enqueue(value)
      }
    }
    
    mutating func dequeue() -> T? {
      if !self.elements.isEmpty {
        self.dequeueCounter += 1
        return self.elements.removeFirst()
      } else {
        return nil
      }
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
