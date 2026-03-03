import SwiftUI

// MARK: - Day Status

enum DayStatus: Hashable {
    case noData
    case planned
    case completed(count: Int)
    case missed
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

// MARK: - Month Calendar View

struct ContributionCalendarView: View {
    let month: Date
    let workoutCounts: [Date: Int]
    let plannedWorkouts: [Date: [PlannedWorkoutSnapshot]]
    var onDayTapped: ((Date) -> Void)?
    var onPreviousMonth: (() -> Void)?
    var onNextMonth: (() -> Void)?

    private let calendar = Calendar.current
    private let cellSpacing: CGFloat = 5

    var body: some View {
        let today = calendar.startOfDay(for: Date())
        let cells = buildMonthCells()

        VStack(spacing: 8) {
            navigationHeader
            weekdayHeader
            monthGrid(cells: cells, today: today)
            legendRow
        }
    }

    // MARK: - Navigation Header

    private var navigationHeader: some View {
        HStack {
            Button {
                onPreviousMonth?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)

            Spacer()

            Button {
                onNextMonth?()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: cellSpacing) {
            ForEach(mondayFirstSymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var mondayFirstSymbols: [String] {
        var symbols = calendar.veryShortWeekdaySymbols // Sun Mon … Sat
        let sun = symbols.removeFirst()
        symbols.append(sun) // Mon … Sat Sun
        return symbols
    }

    // MARK: - Grid

    private func monthGrid(cells: [DayCell], today: Date) -> some View {
        let rows = stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }

        return VStack(spacing: cellSpacing) {
            ForEach(0..<rows.count, id: \.self) { rowIndex in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                        cellView(rows[rowIndex][colIndex], today: today)
                    }
                }
            }
        }
    }

    // MARK: - Build Cells

    private func buildMonthCells() -> [DayCell] {
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: month)
        )!
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)!.count

        let leadingEmpties = mondayBasedWeekday(monthStart)
        var cells: [DayCell] = Array(repeating: .empty, count: leadingEmpties)

        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            let count = workoutCounts[date] ?? 0
            cells.append(.day(date: date, count: count))
        }

        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: .empty, count: 7 - remainder))
        }

        return cells
    }

    private func mondayBasedWeekday(_ date: Date) -> Int {
        let wd = calendar.component(.weekday, from: date)
        return wd == 1 ? 6 : wd - 2
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(_ cell: DayCell, today: Date) -> some View {
        switch cell {
        case .empty:
            Color.clear
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)

        case let .day(date, count):
            let status = dayStatus(for: date, count: count, today: today)
            let isToday = calendar.isDateInToday(date)
            let dayNumber = calendar.component(.day, from: date)

            Button {
                onDayTapped?(date)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorForStatus(status))

                    if isToday {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.primary, lineWidth: 1.5)
                    }

                    Text("\(dayNumber)")
                        .font(.system(size: 13, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Color.primary : Color.primary.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status Logic

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
            return Color.secondary.opacity(0.12)
        case .planned:
            return Color.secondary.opacity(0.3)
        case .completed(let count):
            switch count {
            case 1: return Color.green.opacity(0.4)
            case 2: return Color.green.opacity(0.6)
            case 3: return Color.green.opacity(0.8)
            default: return Color.green
            }
        case .missed:
            return Color.secondary.opacity(0.5)
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 12) {
            Spacer()
            legendItem(color: .green.opacity(0.6), label: "Done")
            legendItem(color: .secondary.opacity(0.3), label: "Planned")
            legendItem(color: .secondary.opacity(0.5), label: "Missed")
            Spacer()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!

    var mockCounts: [Date: Int] = [:]
    for i in 0..<28 {
        let date = calendar.date(byAdding: .day, value: i - 20, to: today)!
        let dayStart = calendar.startOfDay(for: date)
        if Bool.random() { mockCounts[dayStart] = Int.random(in: 1...3) }
    }

    return ContributionCalendarView(
        month: monthStart,
        workoutCounts: mockCounts,
        plannedWorkouts: [:]
    )
    .padding()
}
