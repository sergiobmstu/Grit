import Foundation

// MARK: - Race Distance

enum RaceDistance: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case fiveK = "5K"
    case tenK = "10K"
    case halfMarathon = "21K"
    case marathon = "42K"

    var meters: Double {
        switch self {
        case .fiveK: 5_000
        case .tenK: 10_000
        case .halfMarathon: 21_097.5
        case .marathon: 42_195
        }
    }

    var displayName: String {
        switch self {
        case .fiveK: "5K"
        case .tenK: "10K"
        case .halfMarathon: "Half Marathon"
        case .marathon: "Marathon"
        }
    }
}

// MARK: - Weekday

enum Weekday: Int, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    var singleLetter: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
    }
}

// MARK: - Plan Type

enum PlanType: String, Codable, Sendable, Equatable, Hashable {
    case simple
    case aiAssisted
}

// MARK: - Planned Workout Type

enum PlannedWorkoutType: String, CaseIterable, Codable, Sendable, Equatable, Hashable {
    case easyRun
    case longRun
    case tempo
    case intervals
    case restDay

    var displayName: String {
        switch self {
        case .easyRun: "Easy Run"
        case .longRun: "Long Run"
        case .tempo: "Tempo"
        case .intervals: "Intervals"
        case .restDay: "Rest Day"
        }
    }

    var iconName: String {
        switch self {
        case .easyRun: "figure.run"
        case .longRun: "figure.run.circle"
        case .tempo: "gauge.with.dots.needle.33percent"
        case .intervals: "bolt.fill"
        case .restDay: "bed.double.fill"
        }
    }

    var color: String {
        switch self {
        case .easyRun: "green"
        case .longRun: "blue"
        case .tempo: "orange"
        case .intervals: "red"
        case .restDay: "gray"
        }
    }
}

// MARK: - Goal Snapshot

struct GoalSnapshot: Sendable, Equatable, Identifiable {
    var id: UUID
    var raceDistance: RaceDistance
    var raceDate: Date
    var targetTimeSeconds: Double?
    var fitnessDescription: String
    var trainingDaysPerWeek: Int
    var preferredWeekdays: Set<Weekday>
    var blockedWeekdays: Set<Weekday>
    var planType: PlanType
    var createdAt: Date

    var targetTimeFormatted: String? {
        guard let seconds = targetTimeSeconds else { return nil }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Planned Workout Snapshot

struct PlannedWorkoutSnapshot: Sendable, Equatable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    var workoutType: PlannedWorkoutType
    var descriptionText: String
    var targetDistanceMeters: Double?
    var targetPaceSecondsPerKm: Double?

    var targetPaceFormatted: String? {
        guard let pace = targetPaceSecondsPerKm else { return nil }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var targetDistanceFormatted: String? {
        guard let distance = targetDistanceMeters else { return nil }
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }
}

// MARK: - Training Plan Snapshot

struct TrainingPlanSnapshot: Sendable, Equatable, Identifiable {
    var id: UUID
    var goalId: UUID
    var workouts: [PlannedWorkoutSnapshot]
    var createdAt: Date
}
