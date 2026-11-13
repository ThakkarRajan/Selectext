import Foundation

struct OCRHistoryEntry: Identifiable, Codable, Equatable {
    enum Source: String, Codable {
        /// Recognized from a screen region.
        case captured
        /// Copied as text in any app (⌘C).
        case copied
    }

    let id: UUID
    let timestamp: Date
    var text: String
    var source: Source

    init(id: UUID = UUID(), timestamp: Date = Date(), text: String, source: Source = .captured) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        text = try container.decode(String.self, forKey: .text)
        // History saved before `source` existed only contains captures.
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .captured
    }
}
