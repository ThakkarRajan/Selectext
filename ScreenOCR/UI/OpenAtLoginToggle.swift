import SwiftUI

/// Login item toggle shared by Settings and Getting Started.
struct OpenAtLoginToggle: View {
    @State private var openAtLogin = LoginItemManager.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Open at login", isOn: openAtLoginBinding)
            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Start Selectext when you sign in to this Mac. You can change this anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            openAtLogin = LoginItemManager.isEnabled
            loginItemError = nil
        }
    }

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { openAtLogin },
            set: { enabled in
                do {
                    try LoginItemManager.setEnabled(enabled)
                    openAtLogin = LoginItemManager.isEnabled
                    loginItemError = nil
                } catch {
                    openAtLogin = LoginItemManager.isEnabled
                    loginItemError = error.localizedDescription
                }
            }
        )
    }
}
