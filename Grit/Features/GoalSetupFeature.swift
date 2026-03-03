import ComposableArchitecture
import Foundation

@Reducer
struct GoalSetupFeature {
    @ObservableState
    struct State: Equatable {
        var raceDistance: RaceDistance = .halfMarathon
        var raceDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        var targetTimeText: String = ""
        var fitnessDescription: String = ""
        var trainingDaysPerWeek: Int = 4
        var preferredWeekdays: Set<Weekday> = []
        var blockedWeekdays: Set<Weekday> = []
        var selectedPlanType: PlanType = .simple
        var isGenerating = false
        var existingGoalId: UUID?
        var errorMessage: String?

        var isValid: Bool {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let race = calendar.startOfDay(for: raceDate)
            let days = calendar.dateComponents([.day], from: today, to: race).day ?? 0
            return days >= 21 // At least 3 weeks
        }

        var weeksUntilRace: Int {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let race = calendar.startOfDay(for: raceDate)
            let days = calendar.dateComponents([.day], from: today, to: race).day ?? 0
            return max(0, days / 7)
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case togglePreferredWeekday(Weekday)
        case toggleBlockedWeekday(Weekday)
        case createGoalTapped
        case planGenerated(GoalSnapshot, TrainingPlanSnapshot)
        case planGenerationFailed(String)
        case delegate(Delegate)

        @CasePathable
        enum Delegate {
            case goalCreated(GoalSnapshot, TrainingPlanSnapshot)
            case dismissed
        }
    }

    @Dependency(\.swiftDataClient) var swiftDataClient
    @Dependency(\.trainingPlanGenerator) var trainingPlanGenerator
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .togglePreferredWeekday(day):
                if state.preferredWeekdays.contains(day) {
                    state.preferredWeekdays.remove(day)
                } else {
                    state.preferredWeekdays.insert(day)
                    state.blockedWeekdays.remove(day)
                }
                return .none

            case let .toggleBlockedWeekday(day):
                if state.blockedWeekdays.contains(day) {
                    state.blockedWeekdays.remove(day)
                } else {
                    state.blockedWeekdays.insert(day)
                    state.preferredWeekdays.remove(day)
                }
                return .none

            case .createGoalTapped:
                state.isGenerating = true
                state.errorMessage = nil

                let goalId = state.existingGoalId ?? UUID()
                let targetTime = parseTimeString(state.targetTimeText)

                let goal = GoalSnapshot(
                    id: goalId,
                    raceDistance: state.raceDistance,
                    raceDate: state.raceDate,
                    targetTimeSeconds: targetTime,
                    fitnessDescription: state.fitnessDescription,
                    trainingDaysPerWeek: state.trainingDaysPerWeek,
                    preferredWeekdays: state.preferredWeekdays,
                    blockedWeekdays: state.blockedWeekdays,
                    planType: state.selectedPlanType,
                    createdAt: now
                )

                return .run { send in
                    try await swiftDataClient.saveGoal(goal)
                    let plan = try await trainingPlanGenerator.generatePlan(goal)
                    try await swiftDataClient.saveTrainingPlan(plan, goal.id)
                    await send(.planGenerated(goal, plan))
                } catch: { error, send in
                    await send(.planGenerationFailed(error.localizedDescription))
                }

            case let .planGenerated(goal, plan):
                state.isGenerating = false
                return .send(.delegate(.goalCreated(goal, plan)))

            case let .planGenerationFailed(message):
                state.isGenerating = false
                state.errorMessage = message
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

// MARK: - Time Parsing

private func parseTimeString(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    let parts = trimmed.split(separator: ":").compactMap { Double($0) }
    switch parts.count {
    case 1:
        return parts[0] * 60 // Assume minutes
    case 2:
        return parts[0] * 60 + parts[1] // mm:ss
    case 3:
        return parts[0] * 3600 + parts[1] * 60 + parts[2] // h:mm:ss
    default:
        return nil
    }
}
