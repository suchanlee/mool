import AppKit
import SwiftUI

@Observable
final class CountdownOverlayModel {
    var secondsRemaining: Int

    init(secondsRemaining: Int) {
        self.secondsRemaining = secondsRemaining
    }
}

/// Full-screen, click-through overlay for pre-recording countdown.
final class CountdownOverlayWindow: NSWindow {
    private let model: CountdownOverlayModel

    init(screen: NSScreen, secondsRemaining: Int) {
        self.model = CountdownOverlayModel(secondsRemaining: secondsRemaining)
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true

        let root = CountdownOverlayView(model: model)
        contentView = NSHostingView(rootView: root)
    }

    func update(secondsRemaining: Int) {
        model.secondsRemaining = secondsRemaining
    }
}

private struct CountdownOverlayView: View {
    @Bindable var model: CountdownOverlayModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Starting In")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))

                Text("\(model.secondsRemaining)")
                    .font(.system(size: 180, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }
}
