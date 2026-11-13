import XCTest
@testable import Selectext

final class SafeContinuationTests: XCTestCase {
    func testSecondResumeIsIgnored() async {
        let value = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            let safe = SafeContinuation(continuation)
            safe.resume(returning: 1)
            safe.resume(returning: 2)
        }
        XCTAssertEqual(value, 1)
    }

    func testSecondThrowingResumeIsIgnored() async {
        enum SampleError: Error, Equatable { case first, second }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let safe = SafeContinuation(continuation)
                safe.resume(throwing: SampleError.first)
                safe.resume(throwing: SampleError.second)
            }
            XCTFail("Expected throw")
        } catch let error as SampleError {
            XCTAssertEqual(error, .first)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
