//
//  SpectrogramGenerator.swift
//  WaveTrack-CS4605
//
//  Created by [Your Name] on [Date].
//
import Foundation
import AVFoundation
import Accelerate
import UIKit

class SpectrogramGenerator {
    // Spectrogram parameters (similar to the Python version)
    let nperseg: Int = 2048
    let noverlap: Int = 1024
    
    /// Generates a spectrogram image from the input WAV file.
    /// - Parameter recordingURL: URL of the .wav file.
    /// - Returns: A grayscale UIImage representing the spectrogram, or nil if an error occurs.
    func generateSpectrogram(from recordingURL: URL) -> UIImage? {
        // Open the audio file.
        guard let file = try? AVAudioFile(forReading: recordingURL) else {
            print("Failed to open audio file.")
            return nil
        }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: file.fileFormat.sampleRate,
                                         channels: file.fileFormat.channelCount,
                                         interleaved: false) else {
            return nil
        }
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        do {
            try file.read(into: buffer)
        } catch {
            print("Error reading audio file: \(error)")
            return nil
        }
        
        // Use only the first channel.
        let sampleCount = Int(buffer.frameLength)
        let channelData = buffer.floatChannelData![0]
        let samples = Array(UnsafeBufferPointer(start: channelData, count: sampleCount))
        
        // Prepare for FFT using sliding windows.
        let hop = nperseg - noverlap
        let numSegments = (sampleCount - nperseg) / hop
        var spectrogram: [[Float]] = []
        
        let log2n = vDSP_Length(log2(Float(nperseg)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        
        // For each segment, compute the FFT magnitude.
        for i in 0..<numSegments {
            let start = i * hop
            let windowSegment = Array(samples[start..<start+nperseg])
            
            // Apply a Hann window.
            var windowed = [Float](repeating: 0, count: nperseg)
            var hann = [Float](repeating: 0, count: nperseg)
            vDSP_hann_window(&hann, vDSP_Length(nperseg), Int32(vDSP_HANN_NORM))
            vDSP_vmul(windowSegment, 1, hann, 1, &windowed, 1, vDSP_Length(nperseg))
            
            // Prepare the complex buffer.
            var realp = [Float](repeating: 0, count: nperseg/2)
            var imagp = [Float](repeating: 0, count: nperseg/2)
            windowed.withUnsafeBufferPointer { pointer in
                pointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: nperseg/2) { typeConvertedBuffer in
                    var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
                    vDSP_ctoz(typeConvertedBuffer, 2, &splitComplex, 1, vDSP_Length(nperseg/2))
                    
                    // Compute FFT.
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Compute magnitude.
                    var magnitudes = [Float](repeating: 0.0, count: nperseg/2)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(nperseg/2))
                    var amplitudes = [Float](repeating: 0.0, count: nperseg/2)
                    vvsqrtf(&amplitudes, magnitudes, [Int32(nperseg/2)])
                    
                    // Convert to decibel scale: 10 * log10(amplitude)
                    var dbValues = [Float](repeating: 0.0, count: nperseg/2)
                    var scale: Float = 10.0
                    vDSP_vdbcon(amplitudes, 1, [1.0], &dbValues, 1, vDSP_Length(nperseg/2), 1)
                    vDSP_vsmul(dbValues, 1, &scale, &dbValues, 1, vDSP_Length(nperseg/2))
                    
                    spectrogram.append(dbValues)
                }
            }
        }
        vDSP_destroy_fftsetup(fftSetup)
        
        // Convert the spectrogram (2D array) into a grayscale image.
        // Dimensions: width = numSegments, height = nperseg/2.
        let width = numSegments
        let height = nperseg/2
        var flatData = [UInt8](repeating: 0, count: width * height)
        
        let allValues = spectrogram.flatMap { $0 }
        guard let minVal = allValues.min(), let maxVal = allValues.max(), maxVal > minVal else {
            return nil
        }
        
        // Normalize each value to a 0–255 scale.
        for x in 0..<width {
            let column = spectrogram[x]
            for y in 0..<height {
                let value = column[y]
                let norm = (value - minVal) / (maxVal - minVal)
                let pixel = UInt8(norm * 255)
                // Invert the vertical axis to display low frequencies at the bottom.
                flatData[(height - y - 1) * width + x] = pixel
            }
        }
        
        // Create a CGImage from the grayscale pixel data.
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitsPerComponent = 8
        let bytesPerRow = width * 1
        guard let providerRef = CGDataProvider(data: Data(flatData) as CFData) else {
            return nil
        }
        guard let cgImage = CGImage(width: width,
                                    height: height,
                                    bitsPerComponent: bitsPerComponent,
                                    bitsPerPixel: bitsPerComponent,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                    provider: providerRef,
                                    decode: nil,
                                    shouldInterpolate: true,
                                    intent: .defaultIntent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
