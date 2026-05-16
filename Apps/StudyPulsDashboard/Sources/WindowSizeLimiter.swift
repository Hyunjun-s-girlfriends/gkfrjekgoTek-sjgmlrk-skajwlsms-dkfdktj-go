import SwiftUI
import AppKit

struct WindowSizeLimiter: NSViewRepresentable {
    let initialSize = NSSize(width: 1000, height: 700)
    let minSize = NSSize(width: 680, height: 500)
    let maxSize = NSSize(width: 1000, height: 700)

    final class Coordinator: NSObject, NSWindowDelegate {
        var didSetInitialSize = false
        private var isClamping = false
        private let maxSize = NSSize(width: 1000, height: 700)

        func windowDidResize(_ notification: Notification) {
            guard !isClamping, let window = notification.object as? NSWindow else { return }
            clamp(window)
        }

        func clamp(_ window: NSWindow) {
            guard let contentSize = window.contentView?.frame.size else { return }
            let nextWidth = min(contentSize.width, maxSize.width)
            let nextHeight = min(contentSize.height, maxSize.height)

            guard nextWidth != contentSize.width || nextHeight != contentSize.height else { return }
            isClamping = true
            window.setContentSize(NSSize(width: nextWidth, height: nextHeight))
            isClamping = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow, coordinator: Coordinator) {
        window.minSize = minSize
        window.maxSize = maxSize
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.delegate = coordinator

        if window.frame.width > maxSize.width || window.frame.height > maxSize.height {
            window.setContentSize(initialSize)
            window.center()
        }
        coordinator.clamp(window)

        if !coordinator.didSetInitialSize {
            window.setContentSize(initialSize)
            window.center()
            coordinator.didSetInitialSize = true
        }
    }
}
