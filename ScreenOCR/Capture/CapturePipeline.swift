import CoreGraphics
import Foundation

/// Runs screen capture and OCR off the main thread so the menu bar app stays responsive.
enum CapturePipeline {
    static func extractText(from rect: CGRect, languages: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let image = try await ScreenCaptureManager().captureRegion(rect)
            return try await TextRecognitionService().recognizeText(in: image, languages: languages)
        }.value
    }
}
