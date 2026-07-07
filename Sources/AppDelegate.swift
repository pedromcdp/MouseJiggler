import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    private let store = SettingsStore()
    private lazy var engine = JiggleEngine(store: store)
    private var cancellables = Set<AnyCancellable>()

    private let intervalOptions: [(String, TimeInterval)] = [
        ("20 seconds", 20), ("30 seconds", 30), ("1 minute", 60),
        ("2 minutes", 120), ("5 minutes", 300)
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        menu.delegate = self // menuNeedsUpdate rebuilds it fresh every time it's opened
        statusItem.menu = menu

        if store.settings.launchAtLogin {
            LoginItemManager.setEnabled(true)
        }

        engine.start()

        engine.$isActiveNow
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.statusItem.button?.title = active ? "🟢" : "⚪️"
            }
            .store(in: &cancellables)
    }

    /// Called by AppKit right before the menu is shown, so the Start/Stop
    /// label and interval checkmarks can never go stale — they're rebuilt
    /// from current state every single time, instead of being set once.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let statusHeader = NSMenuItem(title: statusDescription, action: nil, keyEquivalent: "")
        statusHeader.isEnabled = false
        menu.addItem(statusHeader)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(
            title: engine.isRunning ? "Stop" : "Start",
            action: #selector(toggleRunning),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let intervalHeader = NSMenuItem(title: "Jiggle Interval", action: nil, keyEquivalent: "")
        intervalHeader.isEnabled = false
        menu.addItem(intervalHeader)

        for (label, seconds) in intervalOptions {
            let item = NSMenuItem(title: label, action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds
            item.state = (seconds == store.settings.interval) ? .on : .off
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openSettings), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// Distinguishes "engine is on" (isRunning, controlled by Start/Stop) from
    /// "actually jiggling right now" (isActiveNow, controlled by schedule and
    /// app-detection). Without this line, "Stop" staying put while a schedule
    /// pauses the actual jiggling looks like a bug rather than two separate
    /// states doing exactly what they're supposed to.
    private var statusDescription: String {
        if !engine.isRunning { return "⚪️ Stopped" }
        return engine.isActiveNow ? "🟢 Currently jiggling" : "⏸️ Paused — outside schedule or app not running"
    }

    @objc private func toggleRunning() {
        engine.isRunning ? engine.stop() : engine.start()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        store.settings.interval = seconds
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(store: store, engine: engine)
            let hosting = NSHostingController(rootView: view)
            hosting.sizingOptions = []

            // Built with the designated initializer so .fullSizeContentView is
            // part of the style mask from the moment the window is created.
            // Setting window.styleMask *after* NSWindow(contentViewController:)
            // has already run its layout pass can leave the content view sized
            // as if the title bar were still a separate strip — a fixed
            // ~28-32pt shortfall, which matches the gap we were chasing.
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hosting
            window.title = "MouseJiggler Preferences"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 640, height: 460))
            window.contentMinSize = NSSize(width: 640, height: 460)
            window.contentMaxSize = NSSize(width: 640, height: 460)
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
