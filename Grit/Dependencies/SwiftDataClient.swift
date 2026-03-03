import ComposableArchitecture
import Foundation
import SwiftData

@DependencyClient
struct SwiftDataClient: Sendable {
    var saveGoal: @Sendable (_ goal: GoalSnapshot) async throws -> Void
    var fetchActiveGoal: @Sendable () async throws -> GoalSnapshot?
    var deleteGoal: @Sendable (_ id: UUID) async throws -> Void
    var saveTrainingPlan: @Sendable (_ plan: TrainingPlanSnapshot, _ goalId: UUID) async throws -> Void
    var fetchTrainingPlan: @Sendable (_ goalId: UUID) async throws -> TrainingPlanSnapshot?
    var fetchPlannedWorkouts: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [Date: [PlannedWorkoutSnapshot]]
}

extension SwiftDataClient: DependencyKey {
    static let liveValue = SwiftDataClient()

    static func live(container: ModelContainer) -> SwiftDataClient {
        let context = ModelContext(container)

        return SwiftDataClient(
            saveGoal: { snapshot in
                await MainActor.run {
                    let ctx = ModelContext(container)
                    // Delete existing goals first
                    let existing = try? ctx.fetch(FetchDescriptor<RunningGoal>())
                    for goal in existing ?? [] {
                        ctx.delete(goal)
                    }

                    let goal = RunningGoal(
                        id: snapshot.id,
                        raceDistance: snapshot.raceDistance,
                        raceDate: snapshot.raceDate,
                        targetTimeSeconds: snapshot.targetTimeSeconds,
                        fitnessDescription: snapshot.fitnessDescription,
                        trainingDaysPerWeek: snapshot.trainingDaysPerWeek,
                        preferredWeekdays: snapshot.preferredWeekdays,
                        blockedWeekdays: snapshot.blockedWeekdays,
                        planType: snapshot.planType,
                        createdAt: snapshot.createdAt
                    )
                    ctx.insert(goal)
                    try? ctx.save()
                }
            },
            fetchActiveGoal: {
                await MainActor.run {
                    let ctx = ModelContext(container)
                    var descriptor = FetchDescriptor<RunningGoal>(
                        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                    )
                    descriptor.fetchLimit = 1
                    let goals = try? ctx.fetch(descriptor)
                    return goals?.first?.toSnapshot()
                }
            },
            deleteGoal: { id in
                await MainActor.run {
                    let ctx = ModelContext(container)
                    let goals = try? ctx.fetch(FetchDescriptor<RunningGoal>())
                    if let goal = goals?.first(where: { $0.id == id }) {
                        ctx.delete(goal)
                        try? ctx.save()
                    }
                }
            },
            saveTrainingPlan: { planSnapshot, goalId in
                await MainActor.run {
                    let ctx = ModelContext(container)
                    let goals = try? ctx.fetch(FetchDescriptor<RunningGoal>())
                    guard let goal = goals?.first(where: { $0.id == goalId }) else { return }

                    // Delete existing plans for this goal
                    if let existingPlan = goal.trainingPlan {
                        ctx.delete(existingPlan)
                    }

                    let plan = TrainingPlan(id: planSnapshot.id, createdAt: planSnapshot.createdAt, goal: goal)
                    ctx.insert(plan)

                    for (index, workoutSnapshot) in planSnapshot.workouts.enumerated() {
                        let workout = PlannedWorkout(
                            id: workoutSnapshot.id,
                            date: workoutSnapshot.date,
                            workoutType: workoutSnapshot.workoutType,
                            descriptionText: workoutSnapshot.descriptionText,
                            targetDistanceMeters: workoutSnapshot.targetDistanceMeters,
                            targetPaceSecondsPerKm: workoutSnapshot.targetPaceSecondsPerKm,
                            sortOrder: index,
                            plan: plan
                        )
                        ctx.insert(workout)
                    }
                    try? ctx.save()
                }
            },
            fetchTrainingPlan: { goalId in
                await MainActor.run {
                    let ctx = ModelContext(container)
                    let goals = try? ctx.fetch(FetchDescriptor<RunningGoal>())
                    return goals?.first(where: { $0.id == goalId })?.trainingPlan?.toSnapshot()
                }
            },
            fetchPlannedWorkouts: { startDate, endDate in
                await MainActor.run {
                    let ctx = ModelContext(container)
                    let calendar = Calendar.current
                    let start = calendar.startOfDay(for: startDate)
                    let end = calendar.startOfDay(for: endDate)

                    let descriptor = FetchDescriptor<PlannedWorkout>(
                        predicate: #Predicate { workout in
                            workout.date >= start && workout.date <= end
                        },
                        sortBy: [SortDescriptor(\.sortOrder)]
                    )

                    let workouts = (try? ctx.fetch(descriptor)) ?? []
                    var result: [Date: [PlannedWorkoutSnapshot]] = [:]
                    for workout in workouts {
                        let day = calendar.startOfDay(for: workout.date)
                        result[day, default: []].append(workout.toSnapshot())
                    }
                    return result
                }
            }
        )
    }

    static let previewValue = SwiftDataClient(
        saveGoal: { _ in },
        fetchActiveGoal: { nil },
        deleteGoal: { _ in },
        saveTrainingPlan: { _, _ in },
        fetchTrainingPlan: { _ in nil },
        fetchPlannedWorkouts: { _, _ in [:] }
    )
}

extension DependencyValues {
    var swiftDataClient: SwiftDataClient {
        get { self[SwiftDataClient.self] }
        set { self[SwiftDataClient.self] = newValue }
    }
}
