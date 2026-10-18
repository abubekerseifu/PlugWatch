import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var hosting: NSHostingView<HistoryView>?

    func show(model: AppModel) {
        if let window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let root = HistoryView(model: model)
        let hostingView = NSHostingView(rootView: root)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 520)

        let newWindow = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "PlugWatch History"
        newWindow.contentView = hostingView
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.center()
        newWindow.setFrameAutosaveName("PlugWatchHistory")
        newWindow.minSize = NSSize(width: 520, height: 400)

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
