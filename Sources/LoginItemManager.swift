import ServiceManagement

/// Wraps the modern SMAppService login-item API (macOS 13+).
/// No helper app or legacy SMLoginItemSetEnabled needed.
enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("MouseJiggler: failed to update login item — \(error.localizedDescription)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
