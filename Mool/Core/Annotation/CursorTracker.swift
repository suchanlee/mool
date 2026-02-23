import AppKit
import CoreGraphics
import Combine

// MARK: - Cursor Event

struct CursorEvent {
    var position: CGPoint       // in screen coordinates
    var isClick: Bool
    var isRightClick: Bool
}

// MARK: - Cursor Tracker

/// Uses a passive CGEvent tap to monitor global mouse position and clicks.
/// Requires Accessibility permission (does NOT block events).
@MainActor
final class CursorTracker {

    // Published events — subscribe to update cursor effects
    let eventPublisher = PassthroughSubject<CursorEvent, Never>()

    nonisolated(unsafe) private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var isActive: Bool = false

    // Retain self reference so the C callback can bridge back
    private var selfPtr: UnsafeMutableRawPointer?

    // MARK: - Start / Stop

    func startTracking() {
        guard !isActive else { return }

        let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)

        // Use a nonisolated callback bridged via userInfo pointer
        let tracker = Unmanaged.passRetained(self)
        selfPtr = tracker.toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let ptr = userInfo else { return Unmanaged.passRetained(event) }
                let tracker = Unmanaged<CursorTracker>.fromOpaque(ptr).takeUnretainedValue()
                let pos = event.location
                let isClick = type == .leftMouseDown
                let isRight = type == .rightMouseDown
                Task { @MainActor in
                    tracker.eventPublisher.send(CursorEvent(
                        position: pos,
                        isClick: isClick,
                        isRightClick: isRight
                    ))
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )

        guard let tap else {
            print("[CursorTracker] Failed to create event tap — check Accessibility permission")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        isActive = true
    }

    func stopTracking() {
        guard isActive else { return }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        if let ptr = selfPtr {
            Unmanaged<CursorTracker>.fromOpaque(ptr).release()
            selfPtr = nil
        }
        eventTap = nil
        runLoopSource = nil
        isActive = false
    }

    deinit {
        // Cannot call @MainActor methods in deinit; best effort cleanup
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
