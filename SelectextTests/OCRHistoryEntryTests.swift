import XCTest
@testable import Selectext

final class OCRHistoryEntryTests: XCTestCase {
    func testDecodesLegacyHistoryWithoutSourceAsCaptured() throws {
        let json = """
        [
          {
            "id": "E621E1F8-C36C-495A-93FC-0C247A3E6F50",
            "timestamp": "2026-01-15T12:00:00Z",
            "text": "legacy clip"
          }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([OCRHistoryEntry].self, from: json)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].text, "legacy clip")
        XCTAssertEqual(entries[0].source, .captured)
    }

    func testRoundTripEncodesSource() throws {
        let entry = OCRHistoryEntry(text: "copied line", source: .copied)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([entry])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([OCRHistoryEntry].self, from: data)

        XCTAssertEqual(decoded[0].source, .copied)
        XCTAssertEqual(decoded[0].text, "copied line")
    }
}
