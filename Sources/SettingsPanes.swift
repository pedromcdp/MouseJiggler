import SwiftUI

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var engine: JiggleEngine

    private let intervalOptions: [(String, TimeInterval)] = [
        ("20 seconds", 20), ("30 seconds", 30), ("1 minute", 60),
        ("2 minutes", 120), ("5 minutes", 300)
    ]

    private let thresholdOptions: [(String, TimeInterval)] = [
        ("2 seconds", 2), ("5 seconds", 5), ("10 seconds", 10), ("30 seconds", 30)
    ]

    var body: some View {
        Form {
            Section("Functionality") {
                LabeledContent {
                    Toggle("", isOn: Binding(
                        get: { store.settings.launchAtLogin },
                        set: { newValue in
                            store.settings.launchAtLogin = newValue
                            LoginItemManager.setEnabled(newValue)
                        }
                    )).labelsHidden()
                } label: {
                    RowLabel(icon: "power", tint: .gray, title: "Launch at login")
                }
                .help("Starts MouseJiggler automatically when you log in.")

                LabeledContent {
                    Picker("", selection: $store.settings.interval) {
                        ForEach(intervalOptions, id: \.1) { label, value in
                            Text(label).tag(value)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                } label: {
                    RowLabel(icon: "timer", tint: .orange, title: "Jiggle interval")
                }
                .help("How often the cursor nudges while active.")
            }

            Section {
                LabeledContent {
                    Toggle("", isOn: $store.settings.pauseWhenUserActive).labelsHidden()
                } label: {
                    RowLabel(icon: "hand.tap.fill", tint: .purple, title: "Skip if you're already active")
                }
                .help("Won't nudge the mouse if you've used it or the keyboard more recently than the threshold below.")

                if store.settings.pauseWhenUserActive {
                    LabeledContent {
                        Picker("", selection: $store.settings.activityThreshold) {
                            ForEach(thresholdOptions, id: \.1) { label, value in
                                Text(label).tag(value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    } label: {
                        RowLabel(icon: "gauge", tint: .purple, title: "Activity threshold")
                    }
                }
            } footer: {
                Text("Checks real system idle time — the same signal macOS uses for the screen saver — so it never nudges the mouse while you're already at the keyboard.")
            }

            Section("Status") {
                LabeledContent {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusTitle)
                            .foregroundColor(.secondary)
                    }
                } label: {
                    RowLabel(
                        icon: engine.activityState == .jiggling ? "bolt.fill" : "bolt.slash",
                        tint: statusColor,
                        title: "Current state"
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private var statusTitle: String {
        switch engine.activityState {
        case .stopped: return "Stopped"
        case .waitingForConditions: return "Waiting for schedule / app match"
        case .skippingUserActive: return "Skipping — you're already active"
        case .jiggling: return "Currently jiggling"
        }
    }

    private var statusColor: Color {
        switch engine.activityState {
        case .stopped, .waitingForConditions: return .secondary
        case .skippingUserActive: return .yellow
        case .jiggling: return Palette.accent
        }
    }
}

// MARK: - Schedule

struct SchedulePane: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Toggle("", isOn: $store.settings.schedule.enabled).labelsHidden()
                } label: {
                    RowLabel(icon: "clock.fill", tint: .blue, title: "Only run during set hours")
                }
            } footer: {
                if !store.settings.schedule.enabled {
                    Text("Off means MouseJiggler runs any time it's started, with no day/hour restriction.")
                }
            }

            if store.settings.schedule.enabled {
                Section("Hours") {
                    LabeledContent {
                        DatePicker("", selection: startBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    } label: {
                        RowLabel(icon: "sunrise.fill", tint: .orange, title: "Start time")
                    }

                    LabeledContent {
                        DatePicker("", selection: endBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    } label: {
                        RowLabel(icon: "sunset.fill", tint: .indigo, title: "End time")
                    }
                }

                Section("Days") {
                    LabeledContent {
                        WeekdayPicker(selectedDays: $store.settings.schedule.activeDays)
                    } label: {
                        RowLabel(icon: "calendar", tint: .red, title: "Active days")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { store.settings.schedule.startTime.asDate },
            set: { store.settings.schedule.startTime = TimeOfDay(date: $0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { store.settings.schedule.endTime.asDate },
            set: { store.settings.schedule.endTime = TimeOfDay(date: $0) }
        )
    }
}

// MARK: - Detection

struct DetectionPane: View {
    @ObservedObject var store: SettingsStore
    @State private var newBundleID: String = ""

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Toggle("", isOn: $store.settings.onlyWhenTargetAppsRunning).labelsHidden()
                } label: {
                    RowLabel(icon: "eye.fill", tint: .teal, title: "Only jiggle while a target app is running")
                }
            } footer: {
                Text("Checked every 15 seconds against the list below.")
            }

            Section {
                ForEach(Array(store.settings.targetBundleIDs).sorted(), id: \.self) { bundleID in
                    LabeledContent {
                        Button(role: .destructive) {
                            store.settings.targetBundleIDs.remove(bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red.opacity(0.85))
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(systemName: "app.badge.fill", tint: .gray)
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }

                HStack {
                    TextField("com.example.app (bundle ID)", text: $newBundleID)
                    Button("Add") {
                        let trimmed = newBundleID.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        store.settings.targetBundleIDs.insert(trimmed)
                        newBundleID = ""
                    }
                }
            } header: {
                Text("Target Apps")
            } footer: {
                Text("Tip: find a running app's bundle ID with `osascript -e 'id of app \"Teams\"'` in Terminal.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 20)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.accent.gradient)
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "cursorarrow.motionlines")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                )
                .shadow(color: Palette.accent.opacity(0.35), radius: 12, y: 4)

            Text("MouseJiggler")
                .font(.title2).bold()

            Text("Version 1.2")
                .font(.callout)
                .foregroundColor(.secondary)

            Text("A small, native menu bar utility that keeps your status active on Teams, Slack, or anything else that watches for mouse activity.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
