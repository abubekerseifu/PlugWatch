import AppKit
import SwiftUI

/// AppKit-owned settings window. SwiftUI `Settings` / `SettingsLink` are unreliable
/// for LSUIElement menu-bar apps (often no window appears at all).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hosting: NSHostingView<SettingsView>?

    func show(model: AppModel) {
        if let window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let root = SettingsView(model: model)
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(x: 0, y: 0, width: 440, height: 400)

        let newWindow = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "PlugWatch Settings"
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()
        newWindow.setFrameAutosaveName("PlugWatchSettings")

        window = newWindow
        hosting = hostingView

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        hosting = nil
        let stillHasRegularWindow = NSApp.windows.contains {
            $0.isVisible && $0.canBecomeKey && $0.level.rawValue < NSWindow.Level.statusBar.rawValue
        }
        if !stillHasRegularWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
