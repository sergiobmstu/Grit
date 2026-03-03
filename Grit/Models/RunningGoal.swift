import Foundation
import SwiftData

@Model
final class RunningGoal {
    var id: UUID
    var raceDistanceRaw: String
    var raceDate: Date
    var targetTimeSeconds: Double?
    var fitnessDescription: String
    var trainingDaysPerWeek: Int
    var preferredWeekdaysRaw: [Int]
    var blockedWeekdaysRaw: [Int]
    var planTypeRaw: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TrainingPlan.goal)
    var trainingPlan: TrainingPlan?

    var raceDistance: RaceDistance {
        get { RaceDistance(rawValue: raceDistanceRaw) ?? .fiveK }
        set { raceDistanceRaw = newValue.rawValue }
    }

    var planType: PlanType {
        get { PlanType(rawValue: planTypeRaw) ?? .simple }
        set { planTypeRaw = newValue.rawValue }
    }

    var preferredWeekdays: Set<Weekday> {
        get { Set(preferredWeekdaysRaw.compactMap { Weekday(rawValue: $0) }) }
        set { preferredWeekdaysRaw = newValue.map(\.rawValue).sorted() }
    }

    var blockedWeekdays: Set<Weekday> {
        get { Set(blockedWeekdaysRaw.compactMap { Weekday(rawValue: $0) }) }
        set { blockedWeekdaysRaw = newValue.map(\.rawValue).sorted() }
    }

    init(
        id: UUID = UUID(),
        raceDistance: RaceDistance,
        raceDate: Date,
        targetTimeSeconds: Double? = nil,
        fitnessDescription: String = "",
        trainingDaysPerWeek: Int = 4,
        preferredWeekdays: Set<Weekday> = [],
        blockedWeekdays: Set<Weekday> = [],
        planType: PlanType = .simple,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.raceDistanceRaw = raceDistance.rawValue
        self.raceDate = raceDate
        self.targetTimeSeconds = targetTimeSeconds
        self.fitnessDescription = fitnessDescription
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.preferredWeekdaysRaw = preferredWeekdays.map(\.rawValue).sorted()
        self.blockedWeekdaysRaw = blockedWeekdays.map(\.rawValue).sorted()
        self.planTypeRaw = planType.rawValue
        self.createdAt = createdAt
    }

    func toSnapshot() -> GoalSnapshot {
        GoalSnapshot(
            id: id,
            raceDistance: raceDistance,
            raceDate: raceDate,
            targetTimeSeconds: targetTimeSeconds,
            fitnessDescription: fitnessDescription,
            trainingDaysPerWeek: trainingDaysPerWeek,
            preferredWeekdays: preferredWeekdays,
            blockedWeekdays: blockedWeekdays,
            planType: planType,
            createdAt: createdAt
        )
    }
}
