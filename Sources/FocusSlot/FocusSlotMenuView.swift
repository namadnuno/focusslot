import AppKit
import FocusSlotCore
import SwiftUI

struct FocusSlotMenuView: View {
    @EnvironmentObject private var calendarController: CalendarController
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var selectedDate = Date()
    @State private var taskTitle = ""
    @State private var selectedCategory: TaskCategory = .cs
    @State private var durationMinutes = 15
    @State private var statusMessage: StatusMessage?
    @State private var showsSettings = false
    @State private var editingEventID: String?
    @State private var editTitle = ""
    @State private var editCategory: TaskCategory = .cs
    @State private var editStartDate = Date()
    @State private var editDurationMinutes = 15

    private let durations = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(spacing: 16) {
            header

            switch calendarController.accessState {
            case .unknown, .requesting:
                ProgressView("Requesting calendar access...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .denied(let message):
                CalendarAccessView(
                    message: message,
                    onRetry: {
                        Task {
                            await calendarController.start(
                                settings: settingsStore.settings,
                                selectedDate: selectedDate
                            )
                        }
                    },
                    onOpenSettings: openCalendarSettings
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .granted:
                if showsSettings {
                    SettingsView()
                } else {
                    mainContent
                }
            }
        }
        .padding(18)
        .background {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .task {
            await calendarController.start(settings: settingsStore.settings, selectedDate: selectedDate)

            if settingsStore.settings.calendarIdentifier == nil,
               let identifier = calendarController.defaultCalendarIdentifier() {
                settingsStore.updateCalendarIdentifier(identifier)
                await calendarController.loadEvents(for: selectedDate, settings: settingsStore.settings)
            }
        }
        .onChange(of: selectedDate) { newDate in
            Task {
                await calendarController.loadEvents(for: newDate, settings: settingsStore.settings)
            }
        }
        .onChange(of: settingsStore.settings) { newSettings in
            Task {
                await calendarController.loadEvents(for: selectedDate, settings: newSettings)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FocusSlot")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("\(calendarController.taskEvents.count) tasks on \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            DatePicker("Day", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(width: 130)

            Button {
                showsSettings.toggle()
            } label: {
                Image(systemName: showsSettings ? "checkmark" : "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .background(.regularMaterial, in: Circle())
            .help(showsSettings ? "Done" : "Settings")
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            taskList

            if editingEventID == nil {
                newTaskForm
            } else {
                editTaskForm
            }

            if let statusMessage {
                Text(statusMessage.text)
                    .font(.caption)
                    .foregroundStyle(statusMessage.isError ? .red : .green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tasks")
                    .font(.headline)
                Spacer()
                if calendarController.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if calendarController.taskEvents.isEmpty {
                EmptyStateView(
                    title: "No Tasks",
                    systemImage: "calendar",
                    message: "No [Task] events for this day."
                )
                .frame(height: 210)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(calendarController.taskEvents) { event in
                            TaskRow(event: event) { action in
                                Task {
                                    await handleTaskAction(action, event: event)
                                }
                            }
                        }
                    }
                }
                .frame(height: 275)
            }
        }
    }

    private var newTaskForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            formHeader(title: "New task", systemImage: "plus.circle")

            TextField("Task title", text: $taskTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)

            HStack {
                Text("Category")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Category", selection: $selectedCategory) {
                    ForEach(TaskCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            HStack {
                Picker("Duration", selection: $durationMinutes) {
                    ForEach(durations, id: \.self) { minutes in
                        Text("\(minutes)m").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                Spacer()

                Button {
                    addTask()
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private var editTaskForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            formHeader(title: "Edit task", systemImage: "slider.horizontal.3")

            TextField("Task title", text: $editTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(saveEditedTask)

            HStack {
                Text("Category")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Category", selection: $editCategory) {
                    ForEach(TaskCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 160)
            }

            HStack {
                DatePicker("Start", selection: $editStartDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)

                Picker("Duration", selection: $editDurationMinutes) {
                    ForEach(durations, id: \.self) { minutes in
                        Text("\(minutes)m").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 105)
            }

            HStack {
                Button("Cancel") {
                    clearEditing()
                }

                Spacer()

                Button {
                    saveEditedTask()
                } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private func formHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
    }

    private func addTask() {
        let draft = TaskDraft(
            title: taskTitle,
            category: selectedCategory,
            durationMinutes: durationMinutes,
            selectedDate: selectedDate
        )

        Task {
            do {
                let slot = try await calendarController.addTask(draft, settings: settingsStore.settings)
                taskTitle = ""
                statusMessage = StatusMessage(
                    text: "Added at \(slot.start.formatted(date: .omitted, time: .shortened))",
                    isError: false
                )
            } catch {
                statusMessage = StatusMessage(text: error.localizedDescription, isError: true)
            }
        }
    }

    private func handleTaskAction(_ action: TaskRow.Action, event: CalendarEvent) async {
        do {
            switch action {
            case .edit:
                startEditing(event)
            case .markDone:
                try await calendarController.markDone(
                    eventID: event.id,
                    selectedDate: selectedDate,
                    settings: settingsStore.settings
                )
                statusMessage = StatusMessage(text: "Marked done", isError: false)
            case .moveNext:
                let slot = try await calendarController.moveToNextAvailableSlot(
                    eventID: event.id,
                    selectedDate: selectedDate,
                    settings: settingsStore.settings
                )
                statusMessage = StatusMessage(
                    text: "Moved to \(slot.start.formatted(date: .omitted, time: .shortened))",
                    isError: false
                )
            case .delete:
                try await calendarController.delete(
                    eventID: event.id,
                    selectedDate: selectedDate,
                    settings: settingsStore.settings
                )
                statusMessage = StatusMessage(text: "Deleted task", isError: false)
            }
        } catch {
            statusMessage = StatusMessage(text: error.localizedDescription, isError: true)
        }
    }

    private func startEditing(_ event: CalendarEvent) {
        editingEventID = event.id
        editTitle = TaskTitleFormatter.displayTitle(for: event.title)
        editCategory = TaskTitleFormatter.category(for: event.title) ?? .cs
        editStartDate = event.startDate
        editDurationMinutes = max(5, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
        statusMessage = nil
    }

    private func clearEditing() {
        editingEventID = nil
        editTitle = ""
        editCategory = .cs
        editStartDate = Date()
        editDurationMinutes = 15
    }

    private func saveEditedTask() {
        guard let editingEventID else { return }

        Task {
            do {
                try await calendarController.updateTask(
                    eventID: editingEventID,
                    title: editTitle,
                    category: editCategory,
                    startDate: editStartDate,
                    durationMinutes: editDurationMinutes,
                    settings: settingsStore.settings
                )
                selectedDate = editStartDate
                clearEditing()
                statusMessage = StatusMessage(text: "Updated task", isError: false)
            } catch {
                statusMessage = StatusMessage(text: error.localizedDescription, isError: true)
            }
        }
    }

    private func openCalendarSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct StatusMessage {
    let text: String
    let isError: Bool
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}

private struct CalendarAccessView: View {
    let message: String
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            EmptyStateView(
                title: "Calendar Access Needed",
                systemImage: "calendar.badge.exclamationmark",
                message: message
            )

            HStack(spacing: 10) {
                Button("Try Again") {
                    onRetry()
                }

                Button {
                    onOpenSettings()
                } label: {
                    Label("Open Settings", systemImage: "gearshape")
                }
            }
        }
    }
}
