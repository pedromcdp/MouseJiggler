import Foundation

enum Weekday: Int, CaseIterable, Codable, Identifiable {
    // Raw values match Foundation's Calendar weekday component (1 = Sunday ... 7 = Saturday)
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Su"
        case .monday: return "Mo"
        case .tuesday: return "Tu"
        case .wednesday: return "We"
        case .thursday: return "Th"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        }
    }
}

struct TimeOfDay: Codable, Equatable {
    var hour: Int
    var minute: Int

    var minutesFromMidnight: Int { hour * 60 + minute }
}

struct Schedule: Codable, Equatable {
    var enabled: Bool = false
    var activeDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    var startTime: TimeOfDay = TimeOfDay(hour: 9, minute: 0)
    var endTime: TimeOfDay = TimeOfDay(hour: 18, minute: 0)
}

extension TimeOfDay {
    init(date: Date) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        self.hour = comps.hour ?? 0
        self.minute = comps.minute ?? 0
    }

    var asDate: Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}

struct AppSettings: Codable, Equatable {
    var interval: TimeInterval = 60
    var schedule: Schedule = Schedule()
    var onlyWhenTargetAppsRunning: Bool = false
    var targetBundleIDs: Set<String> = [
        "com.microsoft.teams2",   // new Teams
        "com.microsoft.teams",    // classic Teams
        "com.tinyspeck.slackmacgap" // Slack
    ]
    var launchAtLogin: Bool = false
    var pauseWhenUserActive: Bool = true
    var activityThreshold: TimeInterval = 5
    var checkLessOftenOnBattery: Bool = true
}

extension AppSettings {
    /// Decodes key-by-key so settings saved by an older version (missing any
    /// newly added key) keep the user's values, instead of the whole decode
    /// failing and silently resetting everything to defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        interval = try c.decodeIfPresent(TimeInterval.self, forKey: .interval) ?? d.interval
        schedule = try c.decodeIfPresent(Schedule.self, forKey: .schedule) ?? d.schedule
        onlyWhenTargetAppsRunning = try c.decodeIfPresent(Bool.self, forKey: .onlyWhenTargetAppsRunning) ?? d.onlyWhenTargetAppsRunning
        targetBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .targetBundleIDs) ?? d.targetBundleIDs
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        pauseWhenUserActive = try c.decodeIfPresent(Bool.self, forKey: .pauseWhenUserActive) ?? d.pauseWhenUserActive
        activityThreshold = try c.decodeIfPresent(TimeInterval.self, forKey: .activityThreshold) ?? d.activityThreshold
        checkLessOftenOnBattery = try c.decodeIfPresent(Bool.self, forKey: .checkLessOftenOnBattery) ?? d.checkLessOftenOnBattery
    }
}
