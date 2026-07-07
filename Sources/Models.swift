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
}
