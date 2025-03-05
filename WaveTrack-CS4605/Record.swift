//
//  Record.swift
//  WaveTrack-CS4605
//
//  Created by Student_User on 3/4/25.
//

import AVFoundation

class Record: NSObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder?
    var audioEngine = AVAudioEngine()
    var player = AVAudioPlayerNode()
    
    func startRecording() {
        let url = getNewRecordingURL()
        print("Recording will be saved at: \(url.path)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            playUltrasound()
        } catch {
            print("Recording failed: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        audioEngine.stop()
        
        let url = getNewRecordingURL()
        if FileManager.default.fileExists(atPath: url.path) {
            print("Recording successfully saved at \(url.path)")
        } else {
            print("Failed to save recording.")
        }
    }
    
    private func playUltrasound() {
        let sampleRate: Double = 44100
        let frequency: Double = 20000  // 20kHz ultrasound
        let duration: Double = 5       // 5 seconds
        
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: frameCount)!
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
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
    
    private func getNewRecordingURL() -> URL {
        let fileManager = FileManager.default
        let desktopPath = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let folderPath = desktopPath.appendingPathComponent("Recordings")
        
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

