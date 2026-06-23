import FocusSlotCore
import SwiftUI

struct TaskRow: View {
    enum Action {
        case markDone
        case moveNext
        case delete
    }

    let event: CalendarEvent
    let onAction: (Action) -> Void

    private var durationMinutes: Int {
        Int(event.endDate.timeIntervalSince(event.startDate) / 60)
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(TaskTitleFormatter.isDone(event.title) ? Color.green : Color.accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(TaskTitleFormatter.displayTitle(for: event.title))
                    .font(.callout)
                    .lineLimit(1)

                Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(durationMinutes)m")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Menu {
                Button("Mark Done") {
                    onAction(.markDone)
                }
                .disabled(TaskTitleFormatter.isDone(event.title))

                Button("Move to Next Available Slot") {
                    onAction(.moveNext)
                }

                Divider()

                Button("Delete", role: .destructive) {
                    onAction(.delete)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .frame(width: 24)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
