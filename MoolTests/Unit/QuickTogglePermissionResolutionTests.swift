@testable import Mool
import XCTest

final class QuickTogglePermissionResolutionTests: XCTestCase {
    func testResolve_enablesToggleWhenRequestSucceeds() {
        XCTAssertEqual(
            QuickTogglePermissionResolution.resolve(previousStatus: .notDetermined, granted: true),
            .enable
        )
        XCTAssertEqual(
            QuickTogglePermissionResolution.resolve(previousStatus: .denied, granted: true),
            .enable
        )
    }

    func testResolve_keepsToggleDisabledWhenFreshRequestFails() {
        XCTAssertEqual(
            QuickTogglePermissionResolution.resolve(previousStatus: .notDetermined, granted: false),
            .keepDisabled
        )
    }

    func testResolve_opensSettingsOnlyForPreviouslyDeniedPermissions() {
        XCTAssertEqual(
            QuickTogglePermissionResolution.resolve(previousStatus: .denied, granted: false),
            .openSettings
        )
    }
}
