import ComposableArchitecture
import Foundation
import WidgetKit

private let appGroupID = "group.gridt.Gridt"
private let sharedDefaults = UserDefaults(suiteName: appGroupID)

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var activeGoal: GoalSnapshot?
        var trainingPlan: TrainingPlanSnapshot?
        var plannedWorkouts: [Date: [PlannedWorkoutSnapshot]] = [:]
        var workoutCounts: [Date: Int] = [:]
        var workoutDetails: [Date: [WorkoutEntry]] = [:]
        var selectedDate: Date?
        var isLoading = false
        var displayedMonth: Date = {
            let cal = Calendar.current
            return cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        }()
        @Presents var goalSetup: GoalSetupFeature.State?

        var daysRemaining: Int? {
            guard let goal = activeGoal else { return nil }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let raceDay = calendar.startOfDay(for: goal.raceDate)
            let days = calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0
            return max(0, days)
        }

        var totalPlannedWorkouts: Int {
            guard trainingPlan != nil else { return 0 }
            return plannedWorkouts.values.flatMap { $0 }.filter { $0.workoutType != .restDay }.count
        }

        var completedPlannedWorkouts: Int {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return plannedWorkouts.reduce(0) { count, entry in
                let (date, workouts) = entry
                let hasNonRest = workouts.contains { $0.workoutType != .restDay }
                let hasActual = (workoutCounts[date] ?? 0) > 0
                return count + (hasNonRest && hasActual && date <= today ? 1 : 0)
            }
        }

        var trainingProgress: Double? {
            let total = totalPlannedWorkouts
            guard total > 0 else { return nil }
            return Double(completedPlannedWorkouts) / Double(total)
        }

        var currentStreak: Int {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var checkDate = (workoutCounts[today] ?? 0) > 0
                ? today
                : calendar.date(byAdding: .day, value: -1, to: today)!
            var streak = 0
            while (workoutCounts[checkDate] ?? 0) > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
            return streak
        }
    }

    enum Action {
        case onAppear
        case goalLoaded(GoalSnapshot?, TrainingPlanSnapshot?)
        case plannedWorkoutsLoaded([Date: [PlannedWorkoutSnapshot]])
        case setGoalTapped
        case removeGoalTapped
        case fetchWorkouts
        case workoutsResponse([Date: Int])
        case workoutDetailsResponse([Date: [WorkoutEntry]])
        case fetchHistoricalWorkouts
        case previousMonth
        case nextMonth
        case selectDate(Date)
        case dismissDetail
        case fetchFailed
        case goalSetup(PresentationAction<GoalSetupFeature.Action>)
    }

    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    try await healthKitClient.requestAuthorization()

                    // Load goal from SwiftData
                    let goal = try await swiftDataClient.fetchActiveGoal()
                    var plan: TrainingPlanSnapshot?
                    if let goal {
                        plan = try await swiftDataClient.fetchTrainingPlan(goal.id)
                    }
                    await send(.goalLoaded(goal, plan))
                    await send(.fetchWorkouts)
                } catch: { _, send in
                    await send(.fetchFailed)
                }

            case let .goalLoaded(goal, plan):
                state.activeGoal = goal
                state.trainingPlan = plan

                if let goal {
                    // Load planned workouts for calendar range
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: now)
                    let startDate = calendar.date(byAdding: .month, value: -12, to: today)!
                    let raceDate = goal.raceDate
                    let endDate = max(
                        calendar.date(byAdding: .day, value: 1, to: today)!,
                        calendar.date(byAdding: .day, value: 1, to: raceDate)!
                    )
                    return .merge(
                        .run { send in
                            let workouts = try await swiftDataClient.fetchPlannedWorkouts(startDate, endDate)
                            await send(.plannedWorkoutsLoaded(workouts))
                        },
                        .send(.fetchHistoricalWorkouts)
                    )
                } else {
                    state.plannedWorkouts = [:]
                }

                syncToWidget(goal: state.activeGoal, workoutCounts: state.workoutCounts, plannedWorkouts: state.plannedWorkouts)
                return .none

            case let .plannedWorkoutsLoaded(workouts):
                state.plannedWorkouts = workouts
                syncToWidget(goal: state.activeGoal, workoutCounts: state.workoutCounts, plannedWorkouts: workouts)
                return .none

            case .previousMonth:
                let calendar = Calendar.current
                state.displayedMonth = calendar.date(byAdding: .month, value: -1, to: state.displayedMonth)!
                return .send(.fetchWorkouts)

            case .nextMonth:
                let calendar = Calendar.current
                state.displayedMonth = calendar.date(byAdding: .month, value: 1, to: state.displayedMonth)!
                return .send(.fetchWorkouts)

            case .fetchHistoricalWorkouts:
                guard let goal = state.activeGoal else { return .none }
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: now)
                let startDate = calendar.startOfDay(for: goal.createdAt)
                guard let endDate = calendar.date(byAdding: .day, value: 1, to: today) else { return .none }
                return .run { send in
                    async let counts = healthKitClient.fetchRunningWorkouts(startDate, endDate)
                    async let details = healthKitClient.fetchRunningWorkoutDetails(startDate, endDate)
                    await send(.workoutsResponse(try await counts))
                    await send(.workoutDetailsResponse(try await details))
                } catch: { _, send in
                    await send(.fetchFailed)
                }
                .cancellable(id: "healthKitHistory", cancelInFlight: true)

            case .fetchWorkouts:
                state.isLoading = true
                let calendar = Calendar.current
                let monthStart = state.displayedMonth
                guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                    return .none
                }
                let startDate = monthStart
                let endDate = monthEnd
                return .run { send in
                    async let counts = healthKitClient.fetchRunningWorkouts(startDate, endDate)
                    async let details = healthKitClient.fetchRunningWorkoutDetails(startDate, endDate)
                    await send(.workoutsResponse(try await counts))
                    await send(.workoutDetailsResponse(try await details))
                } catch: { _, send in
                    await send(.fetchFailed)
                }
                .cancellable(id: "healthKit")

            case let .workoutsResponse(counts):
                for (date, count) in counts {
                    state.workoutCounts[date] = count
                }
                state.isLoading = false
                syncToWidget(goal: state.activeGoal, workoutCounts: state.workoutCounts, plannedWorkouts: state.plannedWorkouts)
                return .none

            case let .workoutDetailsResponse(details):
                for (date, entries) in details {
                    state.workoutDetails[date] = entries
                }
                return .none

            case let .selectDate(date):
                state.selectedDate = date
                return .none

            case .dismissDetail:
                state.selectedDate = nil
                return .none

            case .fetchFailed:
                state.isLoading = false
                return .none

            case .setGoalTapped:
                if let goal = state.activeGoal {
                    let (hours, minutes) = secondsToTimeComponents(goal.targetTimeSeconds)
                    state.goalSetup = GoalSetupFeature.State(
                        raceDistance: goal.raceDistance,
                        raceDate: goal.raceDate,
                        targetTimeHours: hours,
                        targetTimeMinutes: minutes,
                        fitnessDescription: goal.fitnessDescription,
                        trainingDaysPerWeek: goal.trainingDaysPerWeek,
                        preferredWeekdays: goal.preferredWeekdays,
                        blockedWeekdays: goal.blockedWeekdays,
                        selectedPlanType: goal.planType,
                        existingGoalId: goal.id
                    )
                } else {
                    state.goalSetup = GoalSetupFeature.State()
                }
                return .none

            case .removeGoalTapped:
                let goalId = state.activeGoal?.id
                state.activeGoal = nil
                state.trainingPlan = nil
                state.plannedWorkouts = [:]
                syncToWidget(goal: nil, workoutCounts: state.workoutCounts, plannedWorkouts: [:])
                if let goalId {
                    return .run { _ in
                        try await swiftDataClient.deleteGoal(goalId)
                    }
                }
                return .none

            case .goalSetup(.presented(.delegate(.goalCreated(let goal, let plan)))):
                state.activeGoal = goal
                state.trainingPlan = plan
                state.goalSetup = nil

                // Build planned workouts map
                var plannedMap: [Date: [PlannedWorkoutSnapshot]] = [:]
                let calendar = Calendar.current
                for workout in plan.workouts {
                    let day = calendar.startOfDay(for: workout.date)
                    plannedMap[day, default: []].append(workout)
                }
                state.plannedWorkouts = plannedMap
                syncToWidget(goal: goal, workoutCounts: state.workoutCounts, plannedWorkouts: plannedMap)
                return .send(.fetchHistoricalWorkouts)

            case .goalSetup(.presented(.delegate(.dismissed))):
                state.goalSetup = nil
                return .none

            case .goalSetup:
                return .none
            }
        }
        .ifLet(\.$goalSetup, action: \.goalSetup) {
            GoalSetupFeature()
        }
    }
}

// MARK: - Widget Sync

private func syncToWidget(goal: GoalSnapshot?, workoutCounts: [Date: Int], plannedWorkouts: [Date: [PlannedWorkoutSnapshot]]) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = .current

    // Encode workout counts
    var encodedCounts: [String: Int] = [:]
    for (date, count) in workoutCounts {
        encodedCounts[formatter.string(from: date)] = count
    }
    if let data = try? JSONEncoder().encode(encodedCounts) {
        sharedDefaults?.set(data, forKey: "workoutCounts")
    }

    // Encode planned workout counts for next 30 days
    var encodedPlanned: [String: Int] = [:]
    for (date, workouts) in plannedWorkouts {
        let nonRestWorkouts = workouts.filter { $0.workoutType != .restDay }
        if !nonRestWorkouts.isEmpty {
            encodedPlanned[formatter.string(from: date)] = nonRestWorkouts.count
        }
    }
    if let data = try? JSONEncoder().encode(encodedPlanned) {
        sharedDefaults?.set(data, forKey: "plannedWorkoutCounts")
    }

    // Goal fields
    if let goal {
        sharedDefaults?.set(goal.raceDate.timeIntervalSince1970, forKey: "goalDate")
        sharedDefaults?.set(goal.raceDistance.rawValue, forKey: "raceDistance")
        if let targetTime = goal.targetTimeSeconds {
            sharedDefaults?.set(targetTime, forKey: "targetTime")
        } else {
            sharedDefaults?.removeObject(forKey: "targetTime")
        }
    } else {
        sharedDefaults?.removeObject(forKey: "goalDate")
        sharedDefaults?.removeObject(forKey: "raceDistance")
        sharedDefaults?.removeObject(forKey: "targetTime")
        sharedDefaults?.removeObject(forKey: "plannedWorkoutCounts")
    }

    WidgetCenter.shared.reloadAllTimelines()
}

// MARK: - Helper Functions

private func secondsToTimeComponents(_ seconds: Double?) -> (hours: Int, minutes: Int) {
    guard let seconds = seconds, seconds > 0 else { return (0, 0) }
    
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    
    return (hours, minutes)
}
