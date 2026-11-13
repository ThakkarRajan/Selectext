import CoreGraphics
import Foundation
@preconcurrency import Vision

enum OCRError: LocalizedError {
    case invalidImage
    case noResults
    case visionFailure(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The captured image could not be processed."
        case .noResults:
            return "No text was recognized in the selection."
        case .visionFailure(let error):
            return error.localizedDescription
        }
    }
}

struct TextRecognitionService {
    func recognizeText(in image: CGImage, languages: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let safe = SafeContinuation(continuation)

            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    safe.resume(throwing: OCRError.visionFailure(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    safe.resume(throwing: OCRError.noResults)
                    return
                }

                let sorted = observations.sorted { lhs, rhs in
                    let yDelta = lhs.boundingBox.midY - rhs.boundingBox.midY
                    if abs(yDelta) > 0.015 {
                        return yDelta > 0
                    }
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }

                var lines: [String] = []
                var previousMidY: CGFloat?

                for observation in sorted {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }

                    if let previousMidY, abs(observation.boundingBox.midY - previousMidY) > 0.02 {
                        lines.append("")
                    }
                    lines.append(text)
                    previousMidY = observation.boundingBox.midY
                }

                let result = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if result.isEmpty {
                    safe.resume(throwing: OCRError.noResults)
                } else {
                    safe.resume(returning: result)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let langs = languages.isEmpty ? ["en-US"] : languages
            request.recognitionLanguages = langs
            request.minimumTextHeight = 0.01

            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    safe.resume(throwing: OCRError.visionFailure(error))
                }
            }
        }
    }
}

typealias OCRManager = TextRecognitionService
