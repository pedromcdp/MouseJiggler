import Cocoa
import Combine
import IOKit.ps

/// The four states the engine can be in, used to drive both the Preferences
/// status row and the menu bar dropdown from one place instead of two
/// separately-maintained string computations.
enum ActivityState {
    case stopped
    case needsPermission        // running, but macOS is dropping our synthetic mouse events
    case waitingForConditions   // schedule or app-detection not satisfied
    case skippingUserActive     // conditions met, but you're already at the mouse/keyboard
    case jiggling
}

final class JiggleEngine: ObservableObject {
    /// Whether the user has toggled the app "on" via the menu/UI.
    @Published var isRunning = false

    /// Whether schedule + app-awareness conditions are currently satisfied.
    @Published var isActiveNow = false

    /// True when conditions are satisfied but the last tick skipped the
    /// actual jiggle because you were already using the mouse/keyboard.
    @Published var isSkippingDueToActivity = false

    /// Whether macOS will actually deliver the events jiggle() posts. Without
    /// Accessibility permission they're dropped silently, so this is the only
    /// way to tell "running" apart from "running and actually working".
    @Published var canPostEvents = true

    var activityState: ActivityState {
        if !isRunning { return .stopped }
        if !canPostEvents { return .needsPermission }
        if !isActiveNow { return .waitingForConditions }
        if isSkippingDueToActivity { return .skippingUserActive }
        return .jiggling
    }

    private var jiggleTimer: Timer?
    private var evaluationTimer: Timer?
    private var evaluationInterval: TimeInterval = 0
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var appNapActivity: NSObjectProtocol?
    private let store: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: SettingsStore) {
        self.store = store
        store.$settings
            .sink { [weak self] _ in
                // @Published emits before the new value is stored, so hop to
                // the next run loop pass to read the updated settings.
                DispatchQueue.main.async {
                    self?.restartJiggleTimer()
                    self?.updateEvaluationTimer()
                    self?.evaluateActivity()
                }
            }
            .store(in: &cancellables)

        // React to target apps launching/quitting immediately instead of
        // waiting for the next evaluation tick.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            workspaceCenter.publisher(for: name)
                .sink { [weak self] _ in self?.evaluateActivity() }
                .store(in: &cancellables)
        }

        observePowerSource()
    }

    deinit {
        if let source = powerSourceRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        // A menu bar app with no visible window is a prime App Nap candidate,
        // and App Nap can defer timers by minutes — long enough for Teams to
        // flip to Away while everything here still looks "on".
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Keeping the jiggle timer on schedule"
        )
        restartJiggleTimer()
        updateEvaluationTimer()
        evaluateActivity()
    }

    func stop() {
        isRunning = false
        jiggleTimer?.invalidate(); jiggleTimer = nil
        evaluationTimer?.invalidate(); evaluationTimer = nil
        if let activity = appNapActivity {
            ProcessInfo.processInfo.endActivity(activity)
            appNapActivity = nil
        }
        isActiveNow = false
        isSkippingDueToActivity = false
    }

    private func restartJiggleTimer() {
        jiggleTimer?.invalidate()
        guard isRunning else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: store.settings.interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 1
        jiggleTimer = timer
    }

    /// The evaluation timer only keeps the displayed status fresh — every
    /// jiggle tick re-evaluates on its own — so it's safe to slow it down on
    /// battery. The jiggle interval itself is never touched by power source.
    private func updateEvaluationTimer() {
        guard isRunning else { return }
        let interval: TimeInterval = (store.settings.checkLessOftenOnBattery && isOnBattery()) ? 180 : 15
        // Power-source notifications also fire on every battery percentage
        // change, so only rebuild when the interval actually changes —
        // otherwise a long timer would keep getting reset and never fire.
        guard evaluationTimer == nil || interval != evaluationInterval else { return }

        evaluationTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.evaluateActivity()
        }
        timer.tolerance = interval * 0.1
        evaluationTimer = timer
        evaluationInterval = interval
    }

    private func isOnBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else {
            return false
        }
        return (type as String) == kIOPSBatteryPowerValue
    }

    /// Subscribes to plug/unplug events rather than polling power state.
    private func observePowerSource() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            Unmanaged<JiggleEngine>.fromOpaque(context).takeUnretainedValue().updateEvaluationTimer()
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        powerSourceRunLoopSource = source
    }

    private func tick() {
        evaluateActivity()
        guard isActiveNow, canPostEvents else { return }

        let idle = systemIdleSeconds()
        if store.settings.pauseWhenUserActive && idle < store.settings.activityThreshold {
            isSkippingDueToActivity = true
            // Your input just reset the system idle clock, so the next nudge is
            // due one interval after *that input* — not one interval after this
            // tick. Without re-aligning, the idle gap could reach
            // interval + threshold (e.g. 5m30s), past Teams' 5-minute Away cutoff.
            jiggleTimer?.fireDate = Date().addingTimeInterval(max(store.settings.interval - idle, 1))
            return
        }

        isSkippingDueToActivity = false
        jiggle()
    }

    private func evaluateActivity() {
        canPostEvents = CGPreflightPostEventAccess()
        isActiveNow = isRunning && withinSchedule() && targetAppsSatisfied()
        if !isActiveNow {
            isSkippingDueToActivity = false
        }
    }

    private func withinSchedule() -> Bool {
        let schedule = store.settings.schedule
        guard schedule.enabled else { return true }

        let cal = Calendar.current
        let now = Date()

        guard let weekdayNum = Optional(cal.component(.weekday, from: now)),
              let weekday = Weekday(rawValue: weekdayNum),
              schedule.activeDays.contains(weekday) else {
            return false
        }

        let comps = cal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let start = schedule.startTime.minutesFromMidnight
        let end = schedule.endTime.minutesFromMidnight

        if start <= end {
            return nowMinutes >= start && nowMinutes <= end
        } else {
            // Overnight window, e.g. 22:00 - 06:00
            return nowMinutes >= start || nowMinutes <= end
        }
    }

    private func targetAppsSatisfied() -> Bool {
        guard store.settings.onlyWhenTargetAppsRunning else { return true }
        let runningIDs = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        return !runningIDs.isDisjoint(with: store.settings.targetBundleIDs)
    }

    /// Seconds since the last real mouse or keyboard input, system-wide —
    /// the same mechanism macOS itself uses to decide when to dim the
    /// display or trigger the screen saver.
    private func systemIdleSeconds() -> TimeInterval {
        let anyInputEventType = CGEventType(rawValue: ~UInt32(0))!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInputEventType)
    }

    /// Nudges the cursor 1px and back — enough to reset the OS/Teams idle
    /// timer without visibly moving the cursor or interrupting anything.
    private func jiggle() {
        guard let current = CGEvent(source: nil)?.location else { return }
        let nudged = CGPoint(x: current.x + 1, y: current.y)

        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: nudged, mouseButton: .left)?
            .post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: current, mouseButton: .left)?
                .post(tap: .cghidEventTap)
        }
    }
}
