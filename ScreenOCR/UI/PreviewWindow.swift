import SwiftUI

struct PreviewWindow: View {
    @ObservedObject var appModel: AppModel
    var onClose: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Extracted Text")
                    .font(.headline)
                Spacer()
                Text("\(appModel.previewDraftText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            TextEditor(text: $appModel.previewDraftText)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25))
                }

            HStack {
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    appModel.copyPreviewDraft()
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appModel.previewDraftText.isEmpty)
            }
        }
        .padding(16)
        .onChange(of: appModel.previewDraftText) { _, _ in
            copied = false
        }
    }
}
