import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureText = Self("captureText", default: .init(.t, modifiers: [.command, .shift]))
}

@MainActor
final class ShortcutManager {
    static let shared = ShortcutManager()
    private weak var appModel: AppModel?

    private init() {}

    /// Current capture shortcut for UI copy, e.g. "⇧⌘T".
    static var displayString: String {
        KeyboardShortcuts.getShortcut(for: .captureText)?.description ?? "No shortcut"
    }

    static var defaultDisplayString: String {
        KeyboardShortcuts.Name.captureText.defaultShortcut?.description ?? "No shortcut"
    }

    static func resetToDefault() {
        KeyboardShortcuts.reset(.captureText)
    }

    func configure(appModel: AppModel) {
        self.appModel = appModel
        migrateToCommandShiftTIfNeeded()
        KeyboardShortcuts.enable(.captureText)
        KeyboardShortcuts.onKeyUp(for: .captureText) { [weak appModel] in
            Task { @MainActor in
                appModel?.beginCaptureFromShortcut()
            }
        }
    }

    private func migrateToCommandShiftTIfNeeded() {
        let migrationKey = "captureShortcutMigratedToCommandShiftT_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        let target = KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .shift])
        KeyboardShortcuts.setShortcut(target, for: .captureText)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
