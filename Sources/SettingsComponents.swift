import SwiftUI

enum Palette {
    static let accent = Color(red: 0.20, green: 0.82, blue: 0.42) // matches app icon green
}

// MARK: - Colored icon tile (System Settings / Liquid Glass style)
// Each settings row gets a small rounded, gradient-filled square with a white
// glyph — the same visual language macOS 26's System Settings uses instead
// of plain monochrome SF Symbols.

struct SettingsIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

// A row label combining the icon tile with a title, for use inside
// LabeledContent so every row reads the same way System Settings rows do.
struct RowLabel: View {
    let icon: String
    let tint: Color
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(systemName: icon, tint: tint)
            // title arrives as a String value (not a literal at this call
            // site), so SwiftUI's automatic literal-to-LocalizedStringKey
            // inference doesn't apply here — it has to be explicit.
            Text(LocalizedStringKey(title))
        }
    }
}

// MARK: - Weekday picker
// Native macOS button-toggle style (same family of control System Settings
// uses for day-of-week style pickers), rather than a custom-drawn chip.

struct WeekdayPicker: View {
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases) { day in
                Toggle(LocalizedStringKey(day.shortLabel), isOn: Binding(
                    get: { selectedDays.contains(day) },
                    set: { isOn in
                        if isOn {
                            selectedDays.insert(day)
                        } else {
                            selectedDays.remove(day)
                        }
                    }
                ))
                .toggleStyle(.button)
                .controlSize(.small)
            }
        }
    }
}
