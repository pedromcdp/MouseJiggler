import Cocoa
import Combine

final class JiggleEngine: ObservableObject {
    /// Whether the user has toggled the app "on" via the menu/UI.
    @Published var isRunning = false

    /// Whether it is *actually* jiggling right now, factoring in schedule + app-awareness.
    @Published var isActiveNow = false

    private var jiggleTimer: Timer?
    private var evaluationTimer: Timer?
    private let store: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(store: SettingsStore) {
        self.store = store
        store.$settings
            .sink { [weak self] _ in
                self?.restartJiggleTimer()
                self?.evaluateActivity()
            }
            .store(in: &cancellables)
    }

    func start() {
        isRunning = true
        restartJiggleTimer()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.evaluateActivity()
        }
        evaluateActivity()
    }

    func stop() {
        isRunning = false
        jiggleTimer?.invalidate(); jiggleTimer = nil
        evaluationTimer?.invalidate(); evaluationTimer = nil
        isActiveNow = false
    }

    private func restartJiggleTimer() {
        jiggleTimer?.invalidate()
        guard isRunning else { return }
        jiggleTimer = Timer.scheduledTimer(withTimeInterval: store.settings.interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        evaluateActivity()
        guard isActiveNow else { return }
        jiggle()
    }

    private func evaluateActivity() {
        isActiveNow = isRunning && withinSchedule() && targetAppsSatisfied()
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
