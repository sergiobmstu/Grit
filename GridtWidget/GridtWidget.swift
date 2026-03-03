import WidgetKit
import SwiftUI

// MARK: - App Group

private let appGroupID = "group.gridt.Gridt"

// MARK: - Timeline Entry

struct GridtWidgetEntry: TimelineEntry {
    let date: Date
    let daysRemaining: Int?
    let goalDate: Date?
    let raceDistance: String?
    let workoutCounts: [Date: Int]
}

// MARK: - Timeline Provider

struct GridtWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GridtWidgetEntry {
        GridtWidgetEntry(date: Date(), daysRemaining: 42, goalDate: nil, raceDistance: "42K", workoutCounts: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (GridtWidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GridtWidgetEntry>) -> Void) {
        let entry = readEntry()
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func readEntry() -> GridtWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupID)

        var goalDate: Date?
        if let interval = defaults?.object(forKey: "goalDate") as? Double {
            goalDate = Date(timeIntervalSince1970: interval)
        }

        let raceDistance = defaults?.string(forKey: "raceDistance")

        var workoutCounts: [Date: Int] = [:]
        if let data = defaults?.data(forKey: "workoutCounts"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current
            for (key, value) in decoded {
                if let date = formatter.date(from: key) {
                    workoutCounts[Calendar.current.startOfDay(for: date)] = value
                }
            }
        }

        var daysRemaining: Int?
        if let goalDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let goal = calendar.startOfDay(for: goalDate)
            daysRemaining = max(0, calendar.dateComponents([.day], from: today, to: goal).day ?? 0)
        }

        return GridtWidgetEntry(
            date: Date(),
            daysRemaining: daysRemaining,
            goalDate: goalDate,
            raceDistance: raceDistance,
            workoutCounts: workoutCounts
        )
    }
}

// MARK: - Widget Views

struct GridtWidgetEntryView: View {
    let entry: GridtWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let days = entry.daysRemaining {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    if let distance = entry.raceDistance {
                        Text(distance)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
                Text("days left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Gridt")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            Spacer()
            MiniCalendarView(workoutCounts: entry.workoutCounts)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let days = entry.daysRemaining {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(days)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        if let distance = entry.raceDistance {
                            Text(distance)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                    Text("days left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Gridt")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                }
                Spacer()
                if let goal = entry.goalDate {
                    Text(goal, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MiniCalendarView(workoutCounts: entry.workoutCounts)
        }
    }
}

// MARK: - Mini Calendar (compact month view for widgets)

struct MiniCalendarView: View {
    let workoutCounts: [Date: Int]

    private let calendar = Calendar.current
    private let spacing: CGFloat = 2

    private let colors: [Color] = [
        Color.secondary.opacity(0.15),
        Color.green.opacity(0.3),
        Color.green.opacity(0.5),
        Color.green.opacity(0.75),
        Color.green,
    ]

    var body: some View {
        let cells = buildMonthCells()
        let rows = stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }

        VStack(spacing: spacing) {
            ForEach(0..<rows.count, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<rows[row].count, id: \.self) { col in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(rows[row][col]))
                            .frame(width: 9, height: 9)
                    }
                }
            }
        }
    }

    private func colorFor(_ cell: MiniDayCell) -> Color {
        switch cell {
        case .empty: return .clear
        case let .day(_, count): return colors[min(count, colors.count - 1)]
        }
    }

    private func buildMonthCells() -> [MiniDayCell] {
        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count

        let wd = calendar.component(.weekday, from: monthStart)
        let leadingEmpties = wd == 1 ? 6 : wd - 2
        var cells: [MiniDayCell] = Array(repeating: .empty, count: leadingEmpties)

        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            cells.append(.day(date: date, count: workoutCounts[date] ?? 0))
        }

        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: MiniDayCell.empty, count: 7 - remainder))
        }

        return cells
    }
}

private enum MiniDayCell {
    case empty
    case day(date: Date, count: Int)
}

// MARK: - Widget Configuration

struct GridtWidget: Widget {
    let kind: String = "GridtWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GridtWidgetProvider()) { entry in
            GridtWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Gridt")
        .description("Track your running streak and goal countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
