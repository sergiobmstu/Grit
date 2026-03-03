import Foundation
import SwiftData

@Model
final class TrainingPlan {
    var id: UUID
    var createdAt: Date
    var goal: RunningGoal?

    @Relationship(deleteRule: .cascade, inverse: \PlannedWorkout.plan)
    var workouts: [PlannedWorkout]

    init(id: UUID = UUID(), createdAt: Date = Date(), goal: RunningGoal? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.goal = goal
        self.workouts = []
    }

    func toSnapshot() -> TrainingPlanSnapshot {
        let sortedWorkouts = workouts.sorted { $0.sortOrder < $1.sortOrder }
        return TrainingPlanSnapshot(
            id: id,
            goalId: goal?.id ?? UUID(),
            workouts: sortedWorkouts.map { $0.toSnapshot() },
            createdAt: createdAt
        )
    }
}

@Model
final class PlannedWorkout {
    var id: UUID
    var date: Date
    var workoutTypeRaw: String
    var descriptionText: String
    var targetDistanceMeters: Double?
    var targetPaceSecondsPerKm: Double?
    var sortOrder: Int
    var plan: TrainingPlan?

    var workoutType: PlannedWorkoutType {
        get { PlannedWorkoutType(rawValue: workoutTypeRaw) ?? .easyRun }
        set { workoutTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        workoutType: PlannedWorkoutType,
        descriptionText: String = "",
        targetDistanceMeters: Double? = nil,
        targetPaceSecondsPerKm: Double? = nil,
        sortOrder: Int = 0,
        plan: TrainingPlan? = nil
    ) {
        self.id = id
        self.date = date
        self.workoutTypeRaw = workoutType.rawValue
        self.descriptionText = descriptionText
        self.targetDistanceMeters = targetDistanceMeters
        self.targetPaceSecondsPerKm = targetPaceSecondsPerKm
        self.sortOrder = sortOrder
        self.plan = plan
    }

    func toSnapshot() -> PlannedWorkoutSnapshot {
        PlannedWorkoutSnapshot(
            id: id,
            date: date,
            workoutType: workoutType,
            descriptionText: descriptionText,
            targetDistanceMeters: targetDistanceMeters,
            targetPaceSecondsPerKm: targetPaceSecondsPerKm
        )
    }
}
