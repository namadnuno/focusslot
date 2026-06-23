import FocusSlotCore
import SwiftUI

struct TaskRow: View {
    enum Action {
        case edit
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
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(categoryColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let category = TaskTitleFormatter.category(for: event.title) {
                        CategoryBadge(category: category)
                    }

                    Text(TaskTitleFormatter.displayTitle(for: event.title))
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                }

                Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(durationMinutes)m")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Menu {
                Button("Edit") {
                    onAction(.edit)
                }

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
                    .font(.system(size: 15))
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .frame(width: 24)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06))
        }
    }

    private var categoryColor: Color {
        if TaskTitleFormatter.isDone(event.title) {
            return .green
        }

        switch TaskTitleFormatter.category(for: event.title) {
        case .cs:
            return .blue
        case .bugs:
            return .red
        case .feature:
            return .purple
        case .pair:
            return .orange
        case .investigation:
            return .teal
        case nil:
            return .accentColor
        }
    }
}

struct CategoryBadge: View {
    let category: TaskCategory

    var body: some View {
        Text(category.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var color: Color {
        switch category {
        case .cs:
            return .blue
        case .bugs:
            return .red
        case .feature:
            return .purple
        case .pair:
            return .orange
        case .investigation:
            return .teal
        }
    }
}
