import SwiftUI

struct WelcomeView: View {
    @ObservedObject var appModel: AppModel
    let onFinish: () -> Void
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @AppStorage("showTutorialOnLaunch") private var showTutorialOnLaunch = false

    @State private var page = 0
    @State private var captureCountAtTryStart: Int?
    @State private var pasteTest = ""

    private let pageCount = 4
    static let sampleText = "Hello from ScreenOCR! Capture me."

    private var triedCapture: Bool {
        guard let start = captureCountAtTryStart else { return false }
        return appModel.captureCount > start
    }

    private var currentPageTitle: String {
        switch page {
        case 0: "Welcome"
        case 1: "How it works"
        case 2: "Try a capture"
        case 3: "You're ready"
        default: ""
        }
    }

    private var usesScroll: Bool { page == 1 || page == 2 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if usesScroll {
                    ScrollView {
                        pageContent
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 20)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    pageContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .frame(minHeight: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0: introPage
        case 1: workflowPage
        case 2: tryPage
        case 3: readyPage
        default: EmptyView()
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(ScreenOCRDesign.brandGradient)
                    .padding(10)
                    .background(ScreenOCRDesign.brandGradient.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Getting Started")
                        .font(.title2.weight(.semibold))
                    Text(currentPageTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.interpolate)
                        .animation(.easeInOut(duration: 0.2), value: page)
                }
                Spacer()
                Text("Step \(page + 1) of \(pageCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            WelcomeProgressBar(page: page, pageCount: pageCount)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Pages

    private var introPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeading(
                "Copy text from your screen",
                detail: "ScreenOCR lives in the menu bar. OCR runs on your Mac only — nothing is uploaded."
            )

            VStack(spacing: 0) {
                featureRowCompact(icon: "text.viewfinder", title: "Select a region", detail: "Drag over any text on screen.")
                Divider().padding(.leading, 44)
                featureRowCompact(icon: "doc.on.clipboard", title: "Clipboard history", detail: "Captures and copies from other apps.")
                Divider().padding(.leading, 44)
                featureRowCompact(icon: "lock.shield", title: "Private", detail: "Vision OCR stays on this Mac.")
            }
            .screenOCRCard()
        }
    }

    private var workflowPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeading(
                "How to capture",
                detail: "Three steps. You can also open the menu bar icon for your clip list."
            )

            VStack(alignment: .leading, spacing: 10) {
                step(1, "Press **\(appModel.shortcutDisplay)** or choose **Capture Text** in the menu bar popover")
                step(2, "Drag over the text you want")
                step(3, "Paste with **⌘V** anywhere")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Capture shortcut")
                    .font(.subheadline.weight(.semibold))
                CaptureShortcutRecorder(appModel: appModel)
            }
            .screenOCRCard()

            permissionStatus
        }
    }

    private var tryPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeading(
                "Try it now",
                detail: "Press **Try a Capture**, then drag a box around the sample text below."
            )

            VStack(spacing: 10) {
                Image(systemName: "viewfinder")
                    .font(.title2)
                    .foregroundStyle(ScreenOCRDesign.brandGradient)
                Text(Self.sampleText)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .screenOCRCard()
            .overlay(
                RoundedRectangle(cornerRadius: ScreenOCRDesign.cornerRadius)
                    .strokeBorder(ScreenOCRDesign.brandGradient, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )

            if !appModel.screenCaptureGranted {
                permissionStatus
            } else if triedCapture {
                tryResult.screenOCRCard()
            } else {
                Button {
                    captureCountAtTryStart = appModel.captureCount
                    appModel.startRegionSelection()
                } label: {
                    Label("Try a Capture", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ScreenOCRDesign.accent)
                .controlSize(.large)
                .disabled(appModel.isSelectingRegion)
            }
        }
    }

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeading(
                "You're set",
                detail: "Use the menu bar icon anytime for quick access to your clipboard."
            )

            VStack(alignment: .leading, spacing: 12) {
                checklistRow("Capture with \(appModel.shortcutDisplay)")
                checklistRow("Click the menu bar icon for recent clips")
                checklistRow("Open this window for full history and settings")
            }
            .screenOCRCard()

            Toggle("Show Getting Started when I open ScreenOCR", isOn: $showTutorialOnLaunch)
                .toggleStyle(.switch)
        }
    }

    // MARK: - Components

    private func pageHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func featureRowCompact(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(ScreenOCRDesign.accent)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func checklistRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(text)
                .font(.callout)
        }
    }

    private var tryResult: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Copied to your clipboard", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout.weight(.semibold))
            Text(appModel.lastExtractedText)
                .font(.callout)
                .lineLimit(3)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("Click here and press ⌘V to paste", text: $pasteTest)
                    .textFieldStyle(.roundedBorder)
                if !pasteTest.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button("Back") { page -= 1 }
                    .controlSize(.large)
            }
            Spacer()
            if page < pageCount - 1 {
                Button(page == 2 && !triedCapture ? "Skip" : "Continue") { page += 1 }
                    .buttonStyle(.borderedProminent)
                    .tint(ScreenOCRDesign.accent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Get Started") { completeTutorial() }
                    .buttonStyle(.borderedProminent)
                    .tint(ScreenOCRDesign.accent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var permissionStatus: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: appModel.screenCaptureGranted ? "checkmark.circle.fill" : "lock.circle")
                .foregroundStyle(appModel.screenCaptureGranted ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 6) {
                Text(appModel.screenCaptureGranted ? "Screen Recording is allowed" : "Screen Recording is required")
                    .font(.callout.weight(.semibold))
                if !appModel.screenCaptureGranted {
                    Text("macOS asks once. It is used only to read the region you select.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Grant Access…") {
                        appModel.ensureScreenCaptureAccess()
                    }
                    .controlSize(.small)
                }
            }
        }
        .screenOCRCard()
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StepNumberBadge(number: number)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private func completeTutorial() {
        hasCompletedWelcome = true
        appModel.notifyWelcomeCompleted()
        onFinish()
    }
}
