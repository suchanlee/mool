import AppKit
import SwiftUI

// MARK: - Keyboard Shortcut Recorder

/// NSViewRepresentable component that captures a key + modifier combo.
/// Click to begin recording, press any key+modifier, click elsewhere to cancel.
struct KeyboardShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: RecordingShortcut
    var isRecording: Bool
    var onStartRecording: () -> Void
    var onFinishedRecording: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let view = ShortcutRecorderView()
        view.onStartRecording = onStartRecording
        view.onShortcutCaptured = { newShortcut in
            shortcut = newShortcut
            onFinishedRecording()
        }
        view.onCancelled = onFinishedRecording
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRecording = isRecording
        nsView.updateDisplay()
    }
}

// MARK: - ShortcutRecorderView (NSView)

final class ShortcutRecorderView: NSView {

    var shortcut: RecordingShortcut = .init(key: "", modifiers: [])
    var isRecording: Bool = false {
        didSet { updateDisplay() }
    }

    var onStartRecording: (() -> Void)?
    var onShortcutCaptured: ((RecordingShortcut) -> Void)?
    var onCancelled: (() -> Void)?

    private let label = NSTextField(labelWithString: "")
    private let clearButton = NSButton()
    private var localMonitor: Any?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1

        // Label
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        addSubview(label)

        // Clear button (×)
        clearButton.title = "×"
        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.font = .systemFont(ofSize: 14)
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        addSubview(clearButton)

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)

        updateDisplay()
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        clearButton.frame = NSRect(x: bounds.width - h, y: 0, width: h, height: h)
        label.frame = NSRect(x: 6, y: 0, width: bounds.width - h - 6, height: h)
    }

    // MARK: - Display

    func updateDisplay() {
        if isRecording {
            label.stringValue = "Press shortcut…"
            label.textColor = .secondaryLabelColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            startLocalMonitor()
        } else {
            label.stringValue = shortcut.key.isEmpty ? "Click to record" : shortcut.displayString
            label.textColor = shortcut.key.isEmpty ? .placeholderTextColor : .labelColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            stopLocalMonitor()
        }
        clearButton.isHidden = shortcut.key.isEmpty
        needsLayout = true
    }

    // MARK: - Interaction

    @objc private func handleClick() {
        if !isRecording {
            onStartRecording?()
        }
    }

    @objc private func clearShortcut() {
        shortcut = RecordingShortcut(key: "", modifiers: [])
        onShortcutCaptured?(shortcut)
    }

    // MARK: - Local key monitor (active only while recording)

    private func startLocalMonitor() {
        guard localMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event)
            return nil  // consume the event
        }
    }

    private func stopLocalMonitor() {
        if let mon = localMonitor {
            NSEvent.removeMonitor(mon)
            localMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        // Escape cancels recording without changing the shortcut
        if event.keyCode == 53 {
            onCancelled?()
            return
        }

        // Require at least one modifier
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty else { return }

        // Build our wrapper
        var modifiers = NSEventModifierFlagsWrapper()
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift)   { modifiers.insert(.shift) }
        if flags.contains(.option)  { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }

        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        guard !key.isEmpty else { return }

        let captured = RecordingShortcut(key: key, modifiers: modifiers)
        onShortcutCaptured?(captured)
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if isRecording { onCancelled?() }
        return super.resignFirstResponder()
    }

    deinit {
        stopLocalMonitor()
    }
}

// MARK: - ShortcutField: composable SwiftUI wrapper with recording state

/// Drop-in SwiftUI field for a single RecordingShortcut binding.
struct ShortcutField: View {
    let label: String
    @Binding var shortcut: RecordingShortcut
    @State private var isRecording = false

    var body: some View {
        LabeledContent(label) {
            KeyboardShortcutRecorder(
                shortcut: $shortcut,
                isRecording: isRecording,
                onStartRecording: { isRecording = true },
                onFinishedRecording: { isRecording = false }
            )
            .frame(width: 160, height: 26)
        }
    }
}
