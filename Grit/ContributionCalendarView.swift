import SwiftUI

struct ContributionCalendarView: View {
    let workoutCounts: [Date: Int]
    let dayCount: Int

    private let calendar = Calendar.current
    private let spacing: CGFloat = 4
    private let dayLabelWidth: CGFloat = 28

    private let levelColors: [Color] = [
        Color.secondary.opacity(0.2),
        Color.green.opacity(0.3),
        Color.green.opacity(0.5),
        Color.green.opacity(0.75),
        Color.green,
    ]

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let grid = buildGrid(endDate: today)

        VStack(alignment: .leading, spacing: 6) {
            monthLabelsRow(grid: grid, cellSize: cellSize(for: grid))
            gridView(grid: grid)
            legendRow()
        }
    }

    // MARK: - Grid Computation

    /// Each inner array = one week (column), containing 7 DayCell values (Mon–Sun).
    private func buildGrid(endDate: Date) -> [[DayCell]] {
        let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDate)!

        // Build flat list of all days in range
        var allDays: [Date] = []
        var d = startDate
        while d <= endDate {
            allDays.append(d)
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }

        // Pad start to align to Monday (dayOfWeek: Mon=0 ... Sun=6)
        let startDOW = mondayBasedWeekday(startDate)
        var cells: [DayCell] = Array(repeating: .empty, count: startDOW)

        for date in allDays {
            let count = workoutCounts[date] ?? 0
            cells.append(.day(date: date, count: count))
        }

        // Pad end to complete last week
        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: DayCell.empty, count: 7 - remainder))
        }

        // Reshape into weeks (each week = 7 consecutive cells)
        let weekCount = cells.count / 7
        var weeks: [[DayCell]] = []
        for w in 0..<weekCount {
            var week: [DayCell] = []
            for day in 0..<7 {
                week.append(cells[w * 7 + day])
            }
            weeks.append(week)
        }
        return weeks
    }

    /// Monday = 0, Tuesday = 1, ... Sunday = 6
    private func mondayBasedWeekday(_ date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date) // Sun=1, Mon=2, ..., Sat=7
        return wd == 1 ? 6 : wd - 2
    }

    // MARK: - Subviews

    private func cellSize(for grid: [[DayCell]]) -> CGFloat {
        // Use a reasonable fixed size; the grid won't be too wide for 30 days (~5 cols)
        36
    }

    private func gridView(grid: [[DayCell]]) -> some View {
        let size = cellSize(for: grid)
        return HStack(alignment: .top, spacing: spacing) {
            // Day-of-week labels
            VStack(spacing: spacing) {
                ForEach(0..<7, id: \.self) { row in
                    if row == 0 || row == 2 || row == 4 {
                        // Mon, Wed, Fri
                        Text(dayLabel(row))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: dayLabelWidth, height: size, alignment: .trailing)
                    } else {
                        Color.clear.frame(width: dayLabelWidth, height: size)
                    }
                }
            }

            // Week columns
            ForEach(0..<grid.count, id: \.self) { weekIndex in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        cellView(grid[weekIndex][dayIndex], size: size)
                    }
                }
            }
        }
    }

    private func cellView(_ cell: DayCell, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color(for: cell))
            .frame(width: size, height: size)
    }

    private func monthLabelsRow(grid: [[DayCell]], cellSize: CGFloat) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: dayLabelWidth, height: 14)

            ForEach(0..<grid.count, id: \.self) { weekIndex in
                let label = monthLabel(for: weekIndex, in: grid)
                Group {
                    if let label {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: cellSize, height: 14, alignment: .leading)
            }
        }
    }

    private func legendRow() -> some View {
        HStack(spacing: 4) {
            Spacer()
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(0..<levelColors.count, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(levelColors[level])
                    .frame(width: 14, height: 14)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func color(for cell: DayCell) -> Color {
        switch cell {
        case .empty:
            return .clear
        case let .day(_, count):
            let level = min(count, levelColors.count - 1)
            return levelColors[level]
        }
    }

    private func dayLabel(_ mondayIndex: Int) -> String {
        // shortWeekdaySymbols: [Sun, Mon, Tue, Wed, Thu, Fri, Sat] (indices 0–6)
        // mondayIndex: Mon=0, Tue=1, ..., Sat=5, Sun=6
        let symbols = calendar.shortWeekdaySymbols
        let idx = mondayIndex == 6 ? 0 : mondayIndex + 1
        return symbols[idx]
    }

    private func monthLabel(for weekIndex: Int, in grid: [[DayCell]]) -> String? {
        // Find first actual day in this week
        guard let firstDay = grid[weekIndex].compactMap({ $0.date }).first else { return nil }
        let month = calendar.component(.month, from: firstDay)

        if weekIndex == 0 {
            return calendar.shortMonthSymbols[month - 1]
        }

        // Check previous week's first day
        guard let prevFirstDay = grid[weekIndex - 1].compactMap({ $0.date }).first else {
            return calendar.shortMonthSymbols[month - 1]
        }
        let prevMonth = calendar.component(.month, from: prevFirstDay)
        return month != prevMonth ? calendar.shortMonthSymbols[month - 1] : nil
    }
}

// MARK: - DayCell

enum DayCell: Hashable {
    case empty
    case day(date: Date, count: Int)

    var date: Date? {
        if case let .day(date, _) = self { return date }
        return nil
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var mockData: [Date: Int] = [:]
    for i in 0..<30 {
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        if Bool.random() {
            mockData[date] = Int.random(in: 1...4)
        }
    }

    return ContributionCalendarView(workoutCounts: mockData, dayCount: 30)
        .padding()
}
