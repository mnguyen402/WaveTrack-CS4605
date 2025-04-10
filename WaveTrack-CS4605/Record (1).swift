//
//  Record.swift
//  WaveTrack-CS4605
//
//  Created by Minhnie on 3/6/25.
//
import AVFoundation
import Accelerate
import Foundation

class Record: NSObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?   // Handle recording audio
    var audioEngine = AVAudioEngine()        // Handle audio processing
    var player = AVAudioPlayerNode()         // Play the ultrasound tone
    var recordingURL: URL?                   // Store the recording URL

    // MARK: - Recording Methods
    
    /// Starts emitting a 20 kHz ultrasound tone and begins recording.
    func startRecording() {
        playUltrasound()  // Emit ultrasound tone during recording
        
        recordingURL = getNewRecordingURL()  // Generate a unique URL for the recording
        print("Recording will be saved at: \(recordingURL!.path)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            if audioRecorder?.prepareToRecord() == true {
                audioRecorder?.record()
                print("Recording started")
            } else {
                print("Failed to prepare recorder")
            }
        } catch {
            print("Recording failed: \(error.localizedDescription)")
        }
    }
    
    /// Stops recording, processes the audio to generate a spectrogram, and classifies the gesture.
    /// - Parameter completion: Completion handler passing the detected gesture.
    func stopRecording(completion: @escaping (String) -> Void) {
        audioRecorder?.stop()
        audioRecorder = nil
        audioEngine.stop()
        
        if let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
            print("Recording successfully saved at \(url.path)")
            // Generate the spectrogram image from the recorded file.
            let generator = SpectrogramGenerator()
            if let spectrogramImage = generator.generateSpectrogram(from: url) {
                // Classify the gesture using the generated spectrogram.
                let classifier = GestureClassifier()
                let gesture = classifier.classifyGesture(from: spectrogramImage)
                completion(gesture)
            } else {
                completion("Error generating spectrogram")
            }
        } else {
            print("Failed to save recording. File does not exist at \(recordingURL?.path ?? "unknown path")")
            completion("Unknown")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Emits a 20 kHz ultrasound tone for 5 seconds.
    private func playUltrasound() {
        let sampleRate: Double = 44100
        let frequency: Double = 20000  // 20 kHz ultrasound
        let frameCount = AVAudioFrameCount(sampleRate * 5) // 5 seconds duration
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let channels = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * .pi * frequency * Double(i) / sampleRate)
            channels[i] = Float(sample)
        }
        
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: audioFormat)
        do {
            try audioEngine.start()
            print("Audio engine started")
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
        print("Ultrasound playback started")
    }
    
    /// Generates a unique file URL for storing the recording.
    /// - Returns: A URL in the app's Documents/Recordings folder.
    private func getNewRecordingURL() -> URL {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderPath = documentsPath.appendingPathComponent("Recordings")
        
        if !fileManager.fileExists(atPath: folderPath.path) {
            do {
                try fileManager.createDirectory(at: folderPath, withIntermediateDirectories: true, attributes: nil)
                print("Created directory at \(folderPath.path)")
            } catch {
                print("Failed to create directory: \(error.localizedDescription)")
            }
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileURL = folderPath.appendingPathComponent("recording_\(timestamp).wav")
        print("Generated file path: \(fileURL.path)")
        return fileURL
    }
}
