import WidgetKit
import SwiftUI

// MARK: - App Group

private let appGroupID = "group.grit.Grit"

// MARK: - Timeline Entry

struct GritWidgetEntry: TimelineEntry {
    let date: Date
    let daysRemaining: Int?
    let goalDate: Date?
    let workoutCounts: [Date: Int]
}

// MARK: - Timeline Provider

struct GritWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GritWidgetEntry {
        GritWidgetEntry(date: Date(), daysRemaining: 42, goalDate: nil, workoutCounts: [:])
    }

    func getSnapshot(in context: Context, completion: @escaping (GritWidgetEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GritWidgetEntry>) -> Void) {
        let entry = readEntry()
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func readEntry() -> GritWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupID)

        var goalDate: Date?
        if let interval = defaults?.object(forKey: "goalDate") as? Double {
            goalDate = Date(timeIntervalSince1970: interval)
        }

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

        return GritWidgetEntry(
            date: Date(),
            daysRemaining: daysRemaining,
            goalDate: goalDate,
            workoutCounts: workoutCounts
        )
    }
}

// MARK: - Widget Views

struct GritWidgetEntryView: View {
    let entry: GritWidgetEntry
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
                Text("\(days)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                Text("days left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Grit")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            Spacer()
            MiniCalendarView(workoutCounts: entry.workoutCounts, dayCount: 30)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if let days = entry.daysRemaining {
                    Text("\(days)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("days left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Grit")
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

            MiniCalendarView(workoutCounts: entry.workoutCounts, dayCount: 30)
        }
    }
}

// MARK: - Mini Calendar (compact version for widgets)

struct MiniCalendarView: View {
    let workoutCounts: [Date: Int]
    let dayCount: Int

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
        let today = calendar.startOfDay(for: Date())
        let grid = buildGrid(endDate: today)

        HStack(spacing: spacing) {
            ForEach(0..<grid.count, id: \.self) { weekIndex in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let cell = grid[weekIndex][dayIndex]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorFor(cell))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }

    private func colorFor(_ cell: MiniDayCell) -> Color {
        switch cell {
        case .empty:
            return .clear
        case let .day(_, count):
            return colors[min(count, colors.count - 1)]
        }
    }

    private func buildGrid(endDate: Date) -> [[MiniDayCell]] {
        let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDate)!

        var allDays: [Date] = []
        var d = startDate
        while d <= endDate {
            allDays.append(d)
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }

        let wd = calendar.component(.weekday, from: startDate)
        let startDOW = wd == 1 ? 6 : wd - 2
        var cells: [MiniDayCell] = Array(repeating: .empty, count: startDOW)

        for date in allDays {
            cells.append(.day(date: date, count: workoutCounts[date] ?? 0))
        }

        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: MiniDayCell.empty, count: 7 - remainder))
        }

        let weekCount = cells.count / 7
        var weeks: [[MiniDayCell]] = []
        for w in 0..<weekCount {
            var week: [MiniDayCell] = []
            for day in 0..<7 {
                week.append(cells[w * 7 + day])
            }
            weeks.append(week)
        }
        return weeks
    }
}

private enum MiniDayCell {
    case empty
    case day(date: Date, count: Int)
}

// MARK: - Widget Configuration

struct GritWidget: Widget {
    let kind: String = "GritWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GritWidgetProvider()) { entry in
            GritWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Grit")
        .description("Track your workout streak and goal countdown.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
