//
//  RecordGesture.swift
//  WaveTrack-CS4605
//
//  Created by Minhnie on 3/6/25.
//
import AVFoundation // framework for working with audio and video
import Accelerate // for high performance math operations like FFT

class RecordGesture: NSObject, AVAudioRecorderDelegate {
    var audioRecorder: AVAudioRecorder? // handle recording audio
    var audioEngine = AVAudioEngine() // handle audio processing
    var player = AVAudioPlayerNode() // play the ultrasound
    var recordingURL: URL? // store the recording URL
    
    // Start emitting ultrasound and recording reflected sound
    func startRecording() {
        
        playUltrasound() // record and play sound at same time
        
        recordingURL = getNewRecordingURL() // Store the recording URL
        print("Recording will be saved at: \(recordingURL!.path)")
        
        // recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM), // Uncompressed audio format
            AVSampleRateKey: 44100, // 44.1 kHz sample rate
            AVNumberOfChannelsKey: 1, // Mono audio
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue // High quality
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            if audioRecorder?.prepareToRecord() == true {
                audioRecorder?.record() // start the recording
                print("Recording started")
            } else {
                print("Failed to prepare recorder")
            }
        } catch {
            print("Recording failed: \(error.localizedDescription)")
        }
    }
    
    // Stop recording and analyze the reflected sound
    func stopRecording(completion: @escaping (String) -> Void) {
        audioRecorder?.stop()
        audioRecorder = nil
        audioEngine.stop()
        
        if let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
            print("Recording successfully saved at \(url.path)")
            analyzeRecording(url: url, completion: completion) // call analyzeRecording function on the saved file
        } else {
            print("Failed to save recording. File does not exist at \(recordingURL?.path ?? "unknown path")")
            completion("Unknown")
        }
    }
    
    // Emit a 20 kHz ultrasound tone, setting for the ultrasound
    private func playUltrasound() {
        let sampleRate: Double = 44100
        let frequency: Double = 20000  // 20 kHz ultrasound
        let frameCount = AVAudioFrameCount(sampleRate * 5) // 5 seconds
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        let channels = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * .pi * frequency * Double(i) / sampleRate) // generate sine wave at 20kHz over interval
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
    
    // Generate a unique file path for the recording
    private func getNewRecordingURL() -> URL {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderPath = documentsPath.appendingPathComponent("Recordings")

        // Create the Recordings directory if it doesn't exist
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
    
    // Analyze the recorded audio to detect frequency changes
    private func analyzeRecording(url: URL, completion: @escaping (String) -> Void) {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: UInt32(file.length)) else {
            completion("Unknown")
            return
        }
        
        try? file.read(into: buffer)
        
        // Perform FFT to analyze frequency shifts
        let frameCount = Int(buffer.frameLength)
        let log2n = vDSP_Length(log2(Float(frameCount)))
        let radix = FFTRadix(kFFTRadix2)
        guard let weights = vDSP_create_fftsetup(log2n, radix) else {
            completion("Unknown")
            return
        }
        
        // Allocate memory for real and imaginary parts
        var realp = [Float](repeating: 0, count: frameCount / 2)
        var imagp = [Float](repeating: 0, count: frameCount / 2)
        
        // Create a DSPSplitComplex structure using pointers
        realp.withUnsafeMutableBufferPointer { realBuffer in
            imagp.withUnsafeMutableBufferPointer { imagBuffer in
                var splitComplex = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imagBuffer.baseAddress!)
                
                // Convert interleaved complex data to split complex format
                buffer.floatChannelData!.withMemoryRebound(to: DSPComplex.self, capacity: frameCount) { ptr in
                    vDSP_ctoz(ptr, 2, &splitComplex, 1, vDSP_Length(frameCount / 2))
                }
                
                // Perform forward FFT
                vDSP_fft_zrip(weights, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Analyze the FFT output to detect gestures
                let gesture = detectGestureFromFFT(output: splitComplex, frameCount: frameCount / 2)
                completion(gesture)
            }
        }
        
        // Release the FFT setup
        vDSP_destroy_fftsetup(weights)
    }
    
    // Detect gestures based on frequency changes
    private func detectGestureFromFFT(output: DSPSplitComplex, frameCount: Int) -> String {
        // Implement gesture detection logic here
        // For example, analyze frequency shifts or amplitude changes
        return "Swipe Up" // Placeholder
    }
}
