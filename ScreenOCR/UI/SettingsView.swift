import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.title.bold())
                Text("Shortcut, permissions, clipboard and OCR")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Form {
            Section {
                LabeledContent("Capture text:") {
                    CaptureShortcutRecorder(appModel: appModel)
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Click the field and press a new key combination. Use at least one of ⌘, ⌥ or ⌃.")
            }

            Section {
                permissionRow
            } header: {
                Text("Permissions")
            } footer: {
                if !appModel.screenCaptureGranted {
                    Text("After turning it on in System Settings, quit and reopen Selectext.")
                }
            }

            Section("After capture") {
                Toggle("Show preview window", isOn: $appModel.showPreviewAfterCapture)
            }

            Section {
                Toggle("Save text I copy in other apps", isOn: $appModel.saveCopiedText)
            } header: {
                Text("Clipboard history")
            } footer: {
                Text("Text you copy with ⌘C is kept in Clipboard History on this Mac. Passwords from password managers are skipped.")
            }

            Section {
                TextField("Languages", text: languagesBinding, prompt: Text("en-US"))
            } header: {
                Text("OCR languages")
            } footer: {
                Text("Comma-separated codes in priority order, e.g. en-US, fr-FR, de-DE.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            appModel.syncPermissionsAfterSystemChange()
        }
        }
    }

    private var permissionRow: some View {
        let granted = appModel.screenCaptureGranted
        return Group {
            if granted {
                Label {
                    HStack {
                        Text("Screen Recording")
                        Spacer()
                        Text("Allowed")
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Screen Recording")
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Button("Grant Access…") {
                        appModel.ensureScreenCaptureAccess()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    private var languagesBinding: Binding<String> {
        Binding(
            get: { appModel.recognitionLanguages.joined(separator: ", ") },
            set: { value in
                appModel.recognitionLanguages = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}

/// Capture shortcut field plus reset; used in Settings, the menu bar panel and the tutorial.
struct CaptureShortcutRecorder: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 6) {
            KeyboardShortcuts.Recorder(for: .captureText) { _ in
                appModel.refreshShortcutDisplay()
            }
            Button {
                ShortcutManager.resetToDefault()
                appModel.refreshShortcutDisplay()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("Reset to \(ShortcutManager.defaultDisplayString)")
            .disabled(appModel.shortcutDisplay == ShortcutManager.defaultDisplayString)
        }
    }
}
