import EventKit
import FocusSlotCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var calendarController: CalendarController
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings")
                    .font(.subheadline.weight(.semibold))

                Picker("Task calendar", selection: calendarIdentifierBinding) {
                    Text("Default writable calendar").tag("")

                    ForEach(calendarController.writableCalendars, id: \.calendarIdentifier) { calendar in
                        Text("\(calendar.title) (\(calendar.source.title))")
                            .tag(calendar.calendarIdentifier)
                    }
                }
                .pickerStyle(.menu)

                Divider()

                SettingsTimeRow(
                    title: "Workday start",
                    hour: intBinding(\.workdayStartHour),
                    minute: intBinding(\.workdayStartMinute)
                )

                SettingsTimeRow(
                    title: "Workday end",
                    hour: intBinding(\.workdayEndHour),
                    minute: intBinding(\.workdayEndMinute)
                )

                SettingsTimeRow(
                    title: "Lunch start",
                    hour: intBinding(\.lunchStartHour),
                    minute: intBinding(\.lunchStartMinute)
                )

                SettingsTimeRow(
                    title: "Lunch end",
                    hour: intBinding(\.lunchEndHour),
                    minute: intBinding(\.lunchEndMinute)
                )

                Divider()

                Stepper(
                    "Buffer: \(settingsStore.settings.bufferMinutes)m",
                    value: intBinding(\.bufferMinutes),
                    in: 0...60,
                    step: 5
                )

                Stepper(
                    "Slot granularity: \(settingsStore.settings.slotGranularityMinutes)m",
                    value: intBinding(\.slotGranularityMinutes),
                    in: 1...30,
                    step: 1
                )

                Toggle("Auto-rebalance tasks", isOn: boolBinding(\.autoRebalance))

                Text("Calendar accounts are configured in macOS Calendar. FocusSlot only stores the selected calendar identifier on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Quit FocusSlot") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var calendarIdentifierBinding: Binding<String> {
        Binding {
            settingsStore.settings.calendarIdentifier ?? ""
        } set: { newValue in
            settingsStore.updateCalendarIdentifier(newValue.isEmpty ? nil : newValue)
        }
    }

    private func intBinding(_ keyPath: WritableKeyPath<SchedulingSettings, Int>) -> Binding<Int> {
        Binding {
            settingsStore.settings[keyPath: keyPath]
        } set: { newValue in
            settingsStore.settings[keyPath: keyPath] = newValue
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<SchedulingSettings, Bool>) -> Binding<Bool> {
        Binding {
            settingsStore.settings[keyPath: keyPath]
        } set: { newValue in
            settingsStore.settings[keyPath: keyPath] = newValue
        }
    }
}

private struct SettingsTimeRow: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: $hour, in: 0...23) {
                Text(Self.format(hour: hour, minute: minute))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            Picker("", selection: $minute) {
                ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(width: 64)
        }
    }

    private static func format(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
