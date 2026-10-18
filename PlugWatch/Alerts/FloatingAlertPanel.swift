import AppKit
import SwiftUI

/// Focus/DND-resistant floating panel with Dismiss / Snooze actions.
@MainActor
final class FloatingAlertPanelController {
    private var panel: NSPanel?
    private var hosting: NSHostingView<FloatingAlertContent>?

    var onDismiss: (() -> Void)?
    var onSnooze: (() -> Void)?

    func show() {
        if panel != nil {
            panel?.orderFrontRegardless()
            return
        }

        let content = FloatingAlertContent(
            onDismiss: { [weak self] in
                self?.onDismiss?()
                self?.close()
            },
            onSnooze: { [weak self] in
                self?.onSnooze?()
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 160)

        let newPanel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "PlugWatch"
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.contentView = hostingView
        newPanel.center()
        newPanel.orderFrontRegardless()

        panel = newPanel
        hosting = hostingView
    }

    func close() {
        panel?.close()
        panel = nil
        hosting = nil
    }
}

private struct FloatingAlertContent: View {
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Still on Battery")
                .font(.headline)
            Text("Your Mac has been running on battery past your threshold. Plug in when you can.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Dismiss") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Snooze (30 min)") { onSnooze() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 360)
    }
}
