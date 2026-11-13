import SwiftUI

@main
struct ScreenOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        // The menu bar icon is an NSStatusItem owned by AppDelegate. Auxiliary windows
        // (main window, preview) are AppKit windows owned by MainWindowController /
        // FeatureWindowController, not SwiftUI WindowGroups.
        Settings {
            SettingsView(appModel: appModel)
        }
    }
}
