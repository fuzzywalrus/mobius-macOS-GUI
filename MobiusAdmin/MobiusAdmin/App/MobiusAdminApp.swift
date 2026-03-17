import SwiftUI

@main
struct MobiusAdminApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        }
        .defaultSize(width: 1050, height: 650)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MobiusAdmin") {
                    appDelegate.showAboutWindow()
                }
            }

            CommandMenu("Server") {
                Button("Start Server") {
                    appState.startServer()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appState.serverStatus.isRunning)

                Button("Stop Server") {
                    appState.stopServer()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!appState.serverStatus.isRunning)

                Button("Restart Server") {
                    appState.restartServer()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!appState.hasBinary)

                Divider()

                Button("Reload Configuration") {
                    appState.reloadServerConfig()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(!appState.serverStatus.isRunning)

                Divider()

                Button("Setup Wizard...") {
                    appState.showSetupWizard = true
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?
    private var aboutWindow: NSWindow?

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopServer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func showAboutWindow() {
        if let existing = aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About MobiusAdmin"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: AboutView())
        window.makeKeyAndOrderFront(nil)
        aboutWindow = window
    }
}
