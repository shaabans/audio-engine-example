//
//  ContentView.swift
//  AudioEngineExample
//
//  Created by Sami Shaaban on 6/28/21.
//

import SwiftUI

struct ContentView: View {
  var audioUtil: AudioUtil
  
  var body: some View {
    VStack {
      Button(action: {audioUtil.startRecording()}) {
        HStack {
          Image(systemName: "record.circle")
            .font(.title)
          Text("Listen")
            .fontWeight(.semibold)
            .font(.title)
        }
        .padding()
        .frame(width: 200.0)
        .foregroundColor(.white)
        .background(Color.green)
        .cornerRadius(40)
      }
      Button(action: {audioUtil.stopRecording()}) {
        HStack {
          Image(systemName: "stop.circle")
            .font(.title)
          Text("Stop")
            .fontWeight(.semibold)
            .font(.title)
        }
        .padding()
        .frame(width: 200.0)
        .foregroundColor(.white)
        .background(Color.red)
        .cornerRadius(40)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(audioUtil: AudioUtil())
  }
}
