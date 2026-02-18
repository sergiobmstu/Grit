import ComposableArchitecture
import Foundation
import WidgetKit

private let appGroupID = "group.grit.Grit"
private let sharedDefaults = UserDefaults(suiteName: appGroupID)

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var goalDate: Date?
        var workoutCounts: [Date: Int] = [:]
        var workoutDetails: [Date: [WorkoutEntry]] = [:]
        var selectedDate: Date?
        var isDatePickerPresented = false
        var isLoading = false

        var daysRemaining: Int? {
            guard let goalDate else { return nil }
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let goal = calendar.startOfDay(for: goalDate)
            let days = calendar.dateComponents([.day], from: today, to: goal).day ?? 0
            return max(0, days)
        }
    }

    enum Action {
        case onAppear
        case setGoalDate(Date)
        case removeGoal
        case setDatePickerPresented(Bool)
        case fetchWorkouts
        case workoutsResponse([Date: Int])
        case workoutDetailsResponse([Date: [WorkoutEntry]])
        case selectDate(Date)
        case dismissDetail
        case fetchFailed
    }

    @Dependency(\.healthKitClient) var healthKitClient
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                if let interval = sharedDefaults?.object(forKey: "goalDate") as? Double {
                    state.goalDate = Date(timeIntervalSince1970: interval)
                }
                state.isLoading = true
                return .run { send in
                    try await healthKitClient.requestAuthorization()
                    await send(.fetchWorkouts)
                } catch: { _, send in
                    await send(.fetchFailed)
                }

            case .fetchWorkouts:
                state.isLoading = true
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: now)
                guard let startDate = calendar.date(byAdding: .day, value: -29, to: today),
                      let endDate = calendar.date(byAdding: .day, value: 1, to: today) else {
                    return .none
                }
                return .run { send in
                    async let counts = healthKitClient.fetchWorkouts(startDate, endDate)
                    async let details = healthKitClient.fetchWorkoutDetails(startDate, endDate)
                    await send(.workoutsResponse(try await counts))
                    await send(.workoutDetailsResponse(try await details))
                } catch: { _, send in
                    await send(.fetchFailed)
                }
                .cancellable(id: "healthKit")

            case let .workoutsResponse(counts):
                state.workoutCounts = counts
                state.isLoading = false
                syncToWidget(goalDate: state.goalDate, workoutCounts: counts)
                return .none

            case let .workoutDetailsResponse(details):
                state.workoutDetails = details
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

            case let .setGoalDate(date):
                state.goalDate = date
                state.isDatePickerPresented = false
                sharedDefaults?.set(date.timeIntervalSince1970, forKey: "goalDate")
                syncToWidget(goalDate: date, workoutCounts: state.workoutCounts)
                return .none

            case .removeGoal:
                state.goalDate = nil
                sharedDefaults?.removeObject(forKey: "goalDate")
                syncToWidget(goalDate: nil, workoutCounts: state.workoutCounts)
                return .none

            case let .setDatePickerPresented(presented):
                state.isDatePickerPresented = presented
                return .none
            }
        }
    }
}

// MARK: - Widget Sync

private func syncToWidget(goalDate: Date?, workoutCounts: [Date: Int]) {
    // Encode workout counts with string keys for JSON compatibility
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = .current

    var encoded: [String: Int] = [:]
    for (date, count) in workoutCounts {
        encoded[formatter.string(from: date)] = count
    }

    if let data = try? JSONEncoder().encode(encoded) {
        sharedDefaults?.set(data, forKey: "workoutCounts")
    }

    if let goalDate {
        sharedDefaults?.set(goalDate.timeIntervalSince1970, forKey: "goalDate")
    }

    WidgetCenter.shared.reloadAllTimelines()
}
