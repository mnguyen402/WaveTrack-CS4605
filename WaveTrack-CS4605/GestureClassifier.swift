//
//  GestureClassifier.swift
//  WaveTrack-CS4605
//
//  Created by [Your Name] on [Date].
//
import UIKit
import Accelerate

class GestureClassifier {
    // Constants (matching the original Python settings)
    let CROP_TOP: Int = 40
    let CROP_BOTTOM: Int = 40
    let CROP_LEFT: Int = 60
    let CROP_RIGHT: Int = 360
    let TOTAL_TIME: Double = 3.0
    let SMOOTHING_WINDOW: Int = 25
    let PEAK_HEIGHT: Float = 30.0
    let PEAK_DISTANCE: Int = 20

    /// Classifies a gesture from a spectrogram image.
    /// - Parameter spectrogram: UIImage representing the spectrogram.
    /// - Returns: A string label ("Gesture_1" through "Gesture_5").
    func classifyGesture(from spectrogram: UIImage) -> String {
        guard let cgImage = spectrogram.cgImage else {
            return "Unknown"
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixelData = [UInt8](repeating: 0, count: width * height)
        let bytesPerRow = width
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return "Unknown"
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Crop the image as specified.
        let cropX = CROP_LEFT
        let cropY = CROP_TOP
        let cropWidth = min(width - CROP_LEFT - CROP_RIGHT, width)
        let cropHeight = min(height - CROP_TOP - CROP_BOTTOM, height)
        var croppedPixels = [UInt8]()
        for row in cropY..<cropY+cropHeight {
            let start = row * width + cropX
            let end = start + cropWidth
            croppedPixels.append(contentsOf: pixelData[start..<end])
        }
        
        // Reshape into a 2D array.
        var cropped2D: [[UInt8]] = []
        for row in 0..<cropHeight {
            let start = row * cropWidth
            let rowData = Array(croppedPixels[start..<start+cropWidth])
            cropped2D.append(rowData)
        }
        
        // Apply simple thresholding (fixed threshold).
        let threshold: UInt8 = 128
        for i in 0..<cropHeight {
            for j in 0..<cropWidth {
                cropped2D[i][j] = (cropped2D[i][j] > threshold) ? 255 : 0
            }
        }
        
        // Collapse the cropped image along the frequency axis (sum each column).
        var timeSignal = [Float](repeating: 0, count: cropWidth)
        for col in 0..<cropWidth {
            var colSum: Float = 0.0
            for row in 0..<cropHeight {
                colSum += Float(cropped2D[row][col])
            }
            timeSignal[col] = colSum
        }
        
        // Smooth the time signal using a moving average.
        var smoothedSignal = [Float](repeating: 0, count: cropWidth)
        let windowSize = SMOOTHING_WINDOW
        let window = [Float](repeating: 1.0 / Float(windowSize), count: windowSize)
        vDSP_conv(timeSignal, 1, window, 1, &smoothedSignal, 1, vDSP_Length(cropWidth), vDSP_Length(windowSize))
        
        // Simple peak detection: look for local maxima above PEAK_HEIGHT.
        var peaks: [Int] = []
        for i in 1..<cropWidth-1 {
            if smoothedSignal[i] > PEAK_HEIGHT &&
               smoothedSignal[i] > smoothedSignal[i-1] &&
               smoothedSignal[i] >= smoothedSignal[i+1] {
                if let last = peaks.last, i - last < PEAK_DISTANCE {
                    // If two peaks are too close, retain the higher.
                    if smoothedSignal[i] > smoothedSignal[last] {
                        peaks[peaks.count - 1] = i
                    }
                } else {
                    peaks.append(i)
                }
            }
        }
        
        let numPeaks = peaks.count
        var meanGap: Float = 0.0
        var stdGap: Float = 0.0
        if numPeaks >= 2 {
            var intervals: [Float] = []
            for i in 1..<numPeaks {
                intervals.append(Float(peaks[i] - peaks[i-1]))
            }
            let sum = intervals.reduce(0, +)
            meanGap = sum / Float(intervals.count)
            var squaredDiffs = intervals.map { ($0 - meanGap) * ($0 - meanGap) }
            stdGap = sqrt(squaredDiffs.reduce(0, +) / Float(intervals.count))
        }
        
        // Calculate the average peak amplitude.
        var peakAmps: [Float] = []
        for peak in peaks {
            peakAmps.append(smoothedSignal[peak])
        }
        let avgPeakAmp = peakAmps.reduce(0, +) / Float(max(peakAmps.count, 1))
        
        // Compute combined score: score = num_peaks + 10*meanGap + 5*stdGap.
        let score = Float(numPeaks) + 10 * meanGap + 5 * stdGap
        
        // Return gesture based on thresholds.
        if score < 12.0 {
            return "Gesture_1"
        } else if score < 12.75 {
            return "Gesture_2"
        } else if score < 13.25 {
            return "Gesture_3"
        } else if score < 13.75 {
            return "Gesture_4"
        } else {
            return "Gesture_5"
        }
    }
}
