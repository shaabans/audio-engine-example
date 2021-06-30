//
//  AudioEngineExampleApp.swift
//  AudioEngineExample
//
//  Created by Sami Shaaban on 6/28/21.
//

import SwiftUI

@main
struct AudioEngineExampleApp: App {
  let audioUtil = AudioUtil()
  
  var body: some Scene {
    WindowGroup {
      ContentView(audioUtil: audioUtil)
        .onAppear(perform: {
          audioUtil.initializeAudioEngine()
        })
    }
  }
}
