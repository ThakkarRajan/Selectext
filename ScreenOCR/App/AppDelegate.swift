import AppKit

enum MenuBarLaunchSupport {
    /// Control Center can hide menu bar items; on macOS 26 that can terminate accessory-only apps.
    static var menuBarItemHiddenBySystem: Bool {
        let defaults = UserDefaults.standard
        return defaults.dictionaryRepresentation().keys.contains { key in
            key.hasPrefix("NSStatusItem Visible")
                && (defaults.object(forKey: key) as? NSNumber)?.boolValue == false
        }
    }

    static func applyLaunchPolicy() {
        let wantsAccessory = true
        let policy: NSApplication.ActivationPolicy =
            wantsAccessory && !menuBarItemHiddenBySystem ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        ProcessInfo.processInfo.disableAutomaticTermination("ScreenOCR menu bar utility")
        MenuBarLaunchSupport.applyLaunchPolicy()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installStatusItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MenuBarLaunchSupport.applyLaunchPolicy()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppModelRef.current?.syncPermissionsAfterSystemChange()
    }

    /// Opening the app again from Finder, Launchpad or Spotlight while it runs.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppModelRef.current?.showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// An older copy (e.g. a stale build) would also receive the global shortcut and,
    /// lacking the current Screen Recording grant, show the permission alert.
    private func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ownPID }
            .forEach { $0.terminate() }
    }

    // MARK: - Menu bar icon

    private func installStatusItem() {
        let autosaveName = "ScreenOCRStatusItem"
        // New icons are added at the far left of the extras, which on notched displays is
        // often hidden behind the notch. Until the user drags it, keep it near the right.
        let positionKey = "NSStatusItem Preferred Position \(autosaveName)"
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(120, forKey: positionKey)
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = autosaveName
        if let button = item.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "ScreenOCR clipboard"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let appModel = AppModelRef.current else { return }
        MenuBarPopoverController.shared.toggle(from: sender, appModel: appModel)
    }
}
