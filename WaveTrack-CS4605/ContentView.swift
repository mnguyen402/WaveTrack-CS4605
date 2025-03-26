//
//  ContentView.swift
//  WaveTrack-CS4605
//
//  Created by Minhnie on 2/19/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @State private var currentScreen: Screen = .home
    @State private var detectedGesture: String = "Unknown"
    private let recorder = Record()
    
    enum Screen {
        case home, recording, processing, result
    }
    
    init() {
        configureAudioSession()
    }
    
    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()
            
            VStack {
                if currentScreen == .home {
                    homeView
                }
                else if currentScreen == .recording {
                    recordingView
                }
                else if currentScreen == .processing {
                    processingView
                }
                else if currentScreen == .result {
                    resultView
                }
            }
        }
    }
    
    private var homeView: some View {
        VStack {
            Text("Welcome To")
                .font(.custom("SourceSerifPro-Bold", size: 36))
            Text("WaveTrack")
                .font(.custom("SourceSerifPro-Bold", size: 36))
                .padding(.bottom, 10)
            Text("Press below to record your gesture")
                .font(.custom("SourceSerifPro-It", size: 24))
                .padding(.bottom, 80)
            Button {
                recorder.startRecording() // call startRecording function when button is pressed
                currentScreen = .recording // transition to recordview
            } label: {
                Text("Record Gesture")
                    .font(.custom("AndadaPro-Bold", size: 20))
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 343, height: 52)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
        }
    }
    
    private var recordingView: some View {
        VStack {
            Image(systemName: "waveform")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.black)
                .padding(.bottom, 20)
            
            Text("Ultrasound is being emitted.....\n(auto close in 5s)")
                .font(.custom("SourceSerifPro-It", size: 22))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            // appear for 5s then move to processing screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                recorder.stopRecording { gesture in
                    detectedGesture = gesture
                    currentScreen = .processing
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack {
            Image(systemName: "arrow.triangle.2.circlepath")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.black)
                .padding(.bottom, 20)
            
            Text("We are processing your gesture...")
                .font(.custom("SourceSerifPro-It", size: 22))
                .multilineTextAlignment(.center)
        }
        .onAppear {
            // appear for 3s then move to processing screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                currentScreen = .result
            }
        }
    }
    
    // this is being hardcoded so far, will need other screen for other gestures
    private var resultView: some View {
        VStack {
            Button(action: { currentScreen = .home }) {
                Image(systemName: "arrow.left")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.black)
                    .padding(.leading, -150)
            }
            
            Spacer()
            
            Image(systemName: "hand.point.up")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.black)
                .padding(.bottom, 20)
            
            Text("Detected Gesture: \(detectedGesture)")
                .font(.custom("SourceSerifPro-It", size: 22))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    // allow the app to play audio and record at the same time
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
