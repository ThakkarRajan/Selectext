import SwiftUI

struct HistoryView: View {
    @ObservedObject var history: OCRHistoryManager
    var title = "OCR History"
    private let clipboard = ClipboardManager()
    @State private var confirmingClear = false
    @State private var searchText = ""
    @State private var sourceFilter: OCRHistoryEntry.Source?

    private var filteredEntries: [OCRHistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return history.entries.filter { entry in
            (sourceFilter == nil || entry.source == sourceFilter)
                && (query.isEmpty || entry.text.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar

            if history.entries.isEmpty {
                ContentUnavailableView {
                    Label("No clips yet", systemImage: "doc.on.clipboard")
                } description: {
                    Text("Captured and copied text appears here, stored only on your Mac.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEntries.isEmpty {
                ContentUnavailableView("No matches", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        entryRow(entry)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title.bold())

            HStack(spacing: 10) {
                Picker("Show", selection: $sourceFilter) {
                    Text("All").tag(OCRHistoryEntry.Source?.none)
                    Text("Captured").tag(OCRHistoryEntry.Source?.some(.captured))
                    Text("Copied").tag(OCRHistoryEntry.Source?.some(.copied))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(history.entries.isEmpty)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .disabled(history.entries.isEmpty)

                Spacer()

                Button("Clear All", role: .destructive) {
                    confirmingClear = true
                }
                .disabled(history.entries.isEmpty)
                .confirmationDialog("Delete all history?", isPresented: $confirmingClear) {
                    Button("Delete All", role: .destructive) { history.clearAll() }
                } message: {
                    Text("This removes every saved capture and copied text and can't be undone.")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func entryRow(_ entry: OCRHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SourceBadge(source: entry.source)
                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(entry.text)
                .font(.body)
                .lineLimit(5)
                .textSelection(.enabled)
            HStack(spacing: 16) {
                Button {
                    _ = clipboard.copy(text: entry.text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    history.delete(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
            .font(.callout)
        }
        .screenOCRCard()
    }
}
