//
//  ContentView.swift
//  WaveTrack-CS4605
//
//  Created by Minhnie on 2/19/25.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    var body: some View {
        
        NavigationStack {
            VStack {
                Text("Welcome To")
                    .font(.custom("SourceSerifPro-Bold", size: 36))
                Text("WaveTrack")
                    .font(.custom("SourceSerifPro-Bold", size: 36))
                    .padding(.bottom, 10)
                
                Text("Press below to record your gesture")
                    .font(.custom("SourceSerifPro-It", size: 24))
                    .padding(.bottom, 80)
                
                NavigationLink("Record Gesture", value: "recording")
                    .font(.custom("AndadaPro-Bold", size: 20))
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 343, height: 52)
                    .background(Color.black)
                    .cornerRadius(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("Background").ignoresSafeArea())
            
            .navigationDestination(for: String.self) { destination in
                if destination == "recording" {
                    RecordingView()
                }
            }
        }
        .previewDisplayName("Home Screen")
    }
}

struct RecordingView: View {
    @State private var isRecording = false
    @State private var detectedGesture = "unknown"
    @State private var navigateToResult = false
    private let audioRecorder = AudioRecorder()
    
    var body: some View {
        VStack(spacing: 20) {
            if isRecording {
                Text("Recording Gesture...")
                    .font(.title)
                    .padding()
            }
            
            if navigateToResult {
                NavigationLink("Gesture Detected: \(detectedGesture)", value: detectedGesture)
            }
        }
        .onAppear {
            //startRecording()
        }
        .navigationDestination(for: String.self) { gesture in
            ResultView(gesture: gesture)
        }
        .previewDisplayName("Recording Screen")
    }
    
    private func startRecording() {
        isRecording = true
        audioRecorder.startRecording()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            detectedGesture = "Sample Gesture" // Placeholder for gesture detection logic
            audioRecorder.stopRecording()
            isRecording = false
            navigateToResult = true
        }
    }
}

struct ResultView: View {
    var gesture: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Gesture Detected: \(gesture)")
                .font(.title)
                .padding()
            
            NavigationLink("Back", value: "home")
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            
            NavigationLink("Record Gesture", value: "recording")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .previewDisplayName("Result Screen")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("Home Screen Preview")
            RecordingView()
                .previewDisplayName("Recording Screen Preview")
            ResultView(gesture: "Sample Gesture")
                .previewDisplayName("Result Screen Preview")
        }
    }
}

class AudioRecorder {
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine = AVAudioEngine()
    private var outputFileURL: URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("gesture_recording.wav")
        return path
    }
    
    func startRecording() {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: outputFileURL, settings: settings)
            audioRecorder?.record()
            play20kHzSignal()
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
    }
    
    private func play20kHzSignal() {
        let sampleRate = 44100
        let duration = 5.0
        let numSamples = Int(duration * Double(sampleRate))
        var signal = [Float](repeating: 0.0, count: numSamples)
        
        for i in 0..<numSamples {
            signal[i] = sin(2.0 * .pi * 20000.0 * Float(i) / Float(sampleRate))
        }
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.outputNode.outputFormat(forBus: 0), frameCapacity: AVAudioFrameCount(numSamples))!
        buffer.frameLength = buffer.frameCapacity
        
        let leftChannel = buffer.floatChannelData![0]
        for i in 0..<numSamples {
            leftChannel[i] = signal[i]
        }
        
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: buffer.format)
        
        try? audioEngine.start()
        player.scheduleBuffer(buffer, completionHandler: nil)
        player.play()
    }
}

