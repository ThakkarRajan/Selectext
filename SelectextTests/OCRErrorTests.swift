import XCTest
@testable import Selectext

final class OCRErrorTests: XCTestCase {
    func testLocalizedDescriptions() {
        XCTAssertEqual(OCRError.invalidImage.errorDescription, "The captured image could not be processed.")
        XCTAssertEqual(OCRError.noResults.errorDescription, "No text was recognized in the selection.")
        XCTAssertEqual(
            OCRError.visionFailure(NSError(domain: "test", code: 1)).errorDescription,
            "The operation couldn’t be completed. (test error 1.)"
        )
    }
}
