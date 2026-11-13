import XCTest
@testable import Selectext

@MainActor
final class OCRHistoryManagerTests: XCTestCase {
    private var tempFolder: URL!

    override func setUpWithError() throws {
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SelectextTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempFolder)
        tempFolder = nil
    }

    private func historyURL() -> URL {
        tempFolder.appendingPathComponent("history.json")
    }

    private func waitForPersistence() {
        let exp = expectation(description: "history write")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { exp.fulfill() }
        wait(for: [exp], timeout: 1)
    }

    func testDeduplicatesIdenticalBackToBackText() {
        let manager = OCRHistoryManager(storageFileURL: historyURL())
        manager.add(text: "duplicate")
        manager.add(text: "duplicate")

        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries[0].text, "duplicate")
    }

    func testPersistsEntriesToDisk() {
        let url = historyURL()
        let manager = OCRHistoryManager(storageFileURL: url)
        manager.add(text: "persist me", source: .captured)
        waitForPersistence()

        let reloaded = OCRHistoryManager(storageFileURL: url)
        XCTAssertEqual(reloaded.entries.first?.text, "persist me")
        XCTAssertEqual(reloaded.entries.first?.source, .captured)
    }

    func testClearAllRemovesEntries() {
        let manager = OCRHistoryManager(storageFileURL: historyURL())
        manager.add(text: "one")
        manager.clearAll()
        XCTAssertTrue(manager.entries.isEmpty)
    }
}
