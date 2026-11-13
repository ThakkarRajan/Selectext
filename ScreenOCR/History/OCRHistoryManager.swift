import Foundation

@MainActor
final class OCRHistoryManager: ObservableObject {
    @Published private(set) var entries: [OCRHistoryEntry] = []

    private let fileURL: URL
    private let maxEntries = 200
    private let ioQueue = DispatchQueue(label: "Selectext.history", qos: .utility)

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = support.appendingPathComponent("Selectext", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("history.json")
        load()
    }

    func add(text: String, source: OCRHistoryEntry.Source = .captured) {
        // Copying the same text twice in a row would only add noise.
        if let latest = entries.first, latest.text == text {
            entries[0] = OCRHistoryEntry(text: text, source: latest.source)
            save()
            return
        }
        let entry = OCRHistoryEntry(text: text, source: source)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save()
    }

    func delete(_ entry: OCRHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([OCRHistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        let url = fileURL
        ioQueue.async {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("Selectext history save failed: \(error)")
            }
        }
    }
}
