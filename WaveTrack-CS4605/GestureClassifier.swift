import UIKit
import Accelerate

class GestureClassifier {
    let CROP_TOP = 10
    let CROP_BOTTOM = 10
    let CROP_LEFT = 10
    let CROP_RIGHT = 10

    let SMOOTHING_WINDOW = 15
    let PEAK_DISTANCE = 10
    let zScoreThreshold: Float = 0.8  // Standard deviation threshold

    func classifyGesture(from spectrogram: UIImage) -> String {
        guard let cgImage = spectrogram.cgImage else { return "Unknown" }

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

        let cropX = CROP_LEFT
        let cropY = CROP_TOP
        let effectiveCropWidth = width - CROP_LEFT - CROP_RIGHT
        let effectiveCropHeight = height - CROP_TOP - CROP_BOTTOM

        guard effectiveCropWidth > 0, effectiveCropHeight > 0 else { return "Unknown" }

        var croppedPixels = [UInt8]()
        for row in cropY..<cropY + effectiveCropHeight {
            let start = row * width + cropX
            let end = start + effectiveCropWidth
            croppedPixels.append(contentsOf: pixelData[start..<end])
        }

        var cropped2D: [[UInt8]] = []
        for row in 0..<effectiveCropHeight {
            let start = row * effectiveCropWidth
            let rowData = Array(croppedPixels[start..<start + effectiveCropWidth])
            cropped2D.append(rowData)
        }

        // Binarize
        for i in 0..<effectiveCropHeight {
            for j in 0..<effectiveCropWidth {
                cropped2D[i][j] = (cropped2D[i][j] > 128) ? 255 : 0
            }
        }

        // Collapse to 1D
        var timeSignal = [Float](repeating: 0, count: effectiveCropWidth)
        for col in 0..<effectiveCropWidth {
            var sum: Float = 0.0
            for row in 0..<effectiveCropHeight {
                sum += Float(cropped2D[row][col])
            }
            timeSignal[col] = sum
        }

        // Smooth
        var smoothedSignal = [Float](repeating: 0, count: effectiveCropWidth)
        let window = [Float](repeating: 1.0 / Float(SMOOTHING_WINDOW), count: SMOOTHING_WINDOW)
        vDSP_conv(timeSignal, 1, window, 1, &smoothedSignal, 1, vDSP_Length(effectiveCropWidth), vDSP_Length(SMOOTHING_WINDOW))

        // Standardize (z-score)
        let mean = smoothedSignal.reduce(0, +) / Float(smoothedSignal.count)
        let variance = smoothedSignal.map { pow($0 - mean, 2) }.reduce(0, +) / Float(smoothedSignal.count)
        let std = sqrt(variance)

        guard std > 0 else {
            print("Flat signal — cannot standardize")
            return "No gestures detected"
        }

        let standardized = smoothedSignal.map { ($0 - mean) / std }

        // Peak detection using z-score threshold
        var peaks: [Int] = []
        for i in 1..<standardized.count - 1 {
            if standardized[i] > zScoreThreshold &&
                standardized[i] > standardized[i - 1] &&
                standardized[i] >= standardized[i + 1] {
                if let last = peaks.last, i - last < PEAK_DISTANCE {
                    if standardized[i] > standardized[last] {
                        peaks[peaks.count - 1] = i
                    }
                } else {
                    peaks.append(i)
                }
            }
        }

        print("Detected peaks: \(peaks)")
        let numPeaks = peaks.count

        // Median gap between peaks
        var medianGap: Float = 0.0
        if numPeaks >= 2 {
            let gaps = zip(peaks.dropFirst(), peaks).map { Float($0 - $1) }.sorted()
            if gaps.count % 2 == 0 {
                medianGap = (gaps[gaps.count / 2 - 1] + gaps[gaps.count / 2]) / 2
            } else {
                medianGap = gaps[gaps.count / 2]
            }
        }

        let score = Float(numPeaks) + 2.0 * medianGap
        print("Score: \(score)")

        // Classification
        if score < 2.0 {
            return "No gestures detected"
        } else if score < 3.0 {
            return "Vertical"
        } else if score < 6.0 {
            return "Horizontal"
        } else if score < 7.0 {
            return "In and Out"
        } else if score < 8.0 {
            return "Turn Around"
        } else if score < 9.0 {
            return "Opposite"
        } else {
            return "Unknown"
        }
    }
}
