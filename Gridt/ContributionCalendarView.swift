import SwiftUI

// MARK: - Day Status

enum DayStatus: Hashable {
    case noData
    case planned
    case completed(count: Int)
    case missed
}

struct ContributionCalendarView: View {
    let workoutCounts: [Date: Int]
    let plannedWorkouts: [Date: [PlannedWorkoutSnapshot]]
    let dayCount: Int
    var onDayTapped: ((Date) -> Void)?

    init(
        workoutCounts: [Date: Int],
        plannedWorkouts: [Date: [PlannedWorkoutSnapshot]] = [:],
        dayCount: Int,
        onDayTapped: ((Date) -> Void)? = nil
    ) {
        self.workoutCounts = workoutCounts
        self.plannedWorkouts = plannedWorkouts
        self.dayCount = dayCount
        self.onDayTapped = onDayTapped
    }

    private let calendar = Calendar.current
    private let spacing: CGFloat = 4
    private let dayLabelWidth: CGFloat = 28

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let grid = buildGrid(endDate: today)

        VStack(alignment: .leading, spacing: 6) {
            monthLabelsRow(grid: grid, cellSize: cellSize(for: grid))
            gridView(grid: grid, today: today)
            legendRow()
        }
    }

    // MARK: - Grid Computation

    private func buildGrid(endDate: Date) -> [[DayCell]] {
        let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDate)!

        var allDays: [Date] = []
        var d = startDate
        while d <= endDate {
            allDays.append(d)
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }

        let startDOW = mondayBasedWeekday(startDate)
        var cells: [DayCell] = Array(repeating: .empty, count: startDOW)

        for date in allDays {
            let count = workoutCounts[date] ?? 0
            cells.append(.day(date: date, count: count))
        }

        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: DayCell.empty, count: 7 - remainder))
        }

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

    private func mondayBasedWeekday(_ date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date)
        return wd == 1 ? 6 : wd - 2
    }

    private func dayStatus(for date: Date, count: Int, today: Date) -> DayStatus {
        let hasPlanned = plannedWorkouts[date]?.contains(where: { $0.workoutType != .restDay }) ?? false
        let hasActual = count > 0

        if date > today && hasPlanned {
            return .planned
        } else if date <= today && hasPlanned && hasActual {
            return .completed(count: count)
        } else if date <= today && hasPlanned && !hasActual {
            return .missed
        } else if date <= today && !hasPlanned && hasActual {
            return .completed(count: count)
        }
        return .noData
    }

    private func colorForStatus(_ status: DayStatus) -> Color {
        switch status {
        case .noData:
            return Color.secondary.opacity(0.2)
        case .planned:
            return Color.gray.opacity(0.4)
        case .completed(let count):
            switch count {
            case 1: return Color.green.opacity(0.4)
            case 2: return Color.green.opacity(0.5)
            case 3: return Color.green.opacity(0.75)
            default: return Color.green
            }
        case .missed:
            return Color.red.opacity(0.5)
        }
    }

    // MARK: - Subviews

    private func cellSize(for grid: [[DayCell]]) -> CGFloat {
        36
    }

    private func gridView(grid: [[DayCell]], today: Date) -> some View {
        let size = cellSize(for: grid)
        return HStack(alignment: .top, spacing: spacing) {
            VStack(spacing: spacing) {
                ForEach(0..<7, id: \.self) { row in
                    if row == 0 || row == 2 || row == 4 {
                        Text(dayLabel(row))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: dayLabelWidth, height: size, alignment: .trailing)
                    } else {
                        Color.clear.frame(width: dayLabelWidth, height: size)
                    }
                }
            }

            ForEach(0..<grid.count, id: \.self) { weekIndex in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        cellView(grid[weekIndex][dayIndex], size: size, today: today)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: DayCell, size: CGFloat, today: Date) -> some View {
        switch cell {
        case .empty:
            Color.clear
                .frame(width: size, height: size)
        case let .day(date, count):
            let status = dayStatus(for: date, count: count, today: today)
            Button {
                onDayTapped?(date)
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorForStatus(status))
                    .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
        }
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
        HStack(spacing: 8) {
            Spacer()
            legendItem(color: .green, label: "Done")
            legendItem(color: .gray.opacity(0.4), label: "Planned")
            legendItem(color: .red.opacity(0.5), label: "Missed")
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func dayLabel(_ mondayIndex: Int) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let idx = mondayIndex == 6 ? 0 : mondayIndex + 1
        return symbols[idx]
    }

    private func monthLabel(for weekIndex: Int, in grid: [[DayCell]]) -> String? {
        guard let firstDay = grid[weekIndex].compactMap({ $0.date }).first else { return nil }
        let month = calendar.component(.month, from: firstDay)

        if weekIndex == 0 {
            return calendar.shortMonthSymbols[month - 1]
        }

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
