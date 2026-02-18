import ComposableArchitecture
import HealthKit

// MARK: - WorkoutEntry

struct WorkoutEntry: Sendable, Equatable, Identifiable {
    let id: UUID
    let activityType: String
    let duration: TimeInterval
    let calories: Double
    let startDate: Date
    let endDate: Date
}

// MARK: - Activity Type Display Names

private func displayName(for activityType: HKWorkoutActivityType) -> String {
    switch activityType {
    case .running: "Running"
    case .walking: "Walking"
    case .cycling: "Cycling"
    case .swimming: "Swimming"
    case .hiking: "Hiking"
    case .yoga: "Yoga"
    case .functionalStrengthTraining: "Strength Training"
    case .traditionalStrengthTraining: "Strength Training"
    case .coreTraining: "Core Training"
    case .highIntensityIntervalTraining: "HIIT"
    case .dance: "Dance"
    case .cooldown: "Cooldown"
    case .elliptical: "Elliptical"
    case .rowing: "Rowing"
    case .stairClimbing: "Stair Climbing"
    case .pilates: "Pilates"
    case .martialArts: "Martial Arts"
    case .boxing: "Boxing"
    case .jumpRope: "Jump Rope"
    case .tennis: "Tennis"
    case .basketball: "Basketball"
    case .soccer: "Soccer"
    case .baseball: "Baseball"
    case .golf: "Golf"
    case .crossTraining: "Cross Training"
    case .mixedCardio: "Mixed Cardio"
    default: "Workout"
    }
}

// MARK: - HealthKitClient

@DependencyClient
struct HealthKitClient: Sendable {
    var requestAuthorization: @Sendable () async throws -> Void
    var fetchWorkouts: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [Date: Int]
    var fetchWorkoutDetails: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [Date: [WorkoutEntry]]
}

extension HealthKitClient: DependencyKey {
    static let liveValue: HealthKitClient = {
        nonisolated(unsafe) let store = HKHealthStore()

        return HealthKitClient(
            requestAuthorization: {
                guard HKHealthStore.isHealthDataAvailable() else { return }
                try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
            },
            fetchWorkouts: { startDate, endDate in
                let predicate = HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: endDate,
                    options: .strictStartDate
                )

                let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: HKObjectType.workoutType(),
                        predicate: predicate,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: nil
                    ) { _, results, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: results ?? [])
                        }
                    }
                    store.execute(query)
                }

                let calendar = Calendar.current
                var counts: [Date: Int] = [:]
                for sample in samples {
                    let day = calendar.startOfDay(for: sample.startDate)
                    counts[day, default: 0] += 1
                }
                return counts
            },
            fetchWorkoutDetails: { startDate, endDate in
                let predicate = HKQuery.predicateForSamples(
                    withStart: startDate,
                    end: endDate,
                    options: .strictStartDate
                )

                let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                    let query = HKSampleQuery(
                        sampleType: HKObjectType.workoutType(),
                        predicate: predicate,
                        limit: HKObjectQueryNoLimit,
                        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                    ) { _, results, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: results ?? [])
                        }
                    }
                    store.execute(query)
                }

                let calendar = Calendar.current
                var details: [Date: [WorkoutEntry]] = [:]
                for sample in samples {
                    guard let workout = sample as? HKWorkout else { continue }
                    let day = calendar.startOfDay(for: workout.startDate)
                    let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                        .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    let entry = WorkoutEntry(
                        id: workout.uuid,
                        activityType: displayName(for: workout.workoutActivityType),
                        duration: workout.duration,
                        calories: calories,
                        startDate: workout.startDate,
                        endDate: workout.endDate
                    )
                    details[day, default: []].append(entry)
                }
                return details
            }
        )
    }()

    static let previewValue = HealthKitClient(
        requestAuthorization: {},
        fetchWorkouts: { startDate, endDate in
            let calendar = Calendar.current
            var data: [Date: Int] = [:]
            var date = startDate
            while date < endDate {
                if Bool.random() {
                    data[calendar.startOfDay(for: date)] = Int.random(in: 1...4)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return data
        },
        fetchWorkoutDetails: { startDate, endDate in
            let calendar = Calendar.current
            let activities = ["Running", "Walking", "Cycling", "Swimming", "Yoga", "HIIT", "Strength Training"]
            var data: [Date: [WorkoutEntry]] = [:]
            var date = startDate
            while date < endDate {
                let day = calendar.startOfDay(for: date)
                if Bool.random() {
                    let count = Int.random(in: 1...3)
                    var entries: [WorkoutEntry] = []
                    for i in 0..<count {
                        let hour = 7 + i * 4
                        let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
                        let duration = TimeInterval(Int.random(in: 20...90) * 60)
                        entries.append(WorkoutEntry(
                            id: UUID(),
                            activityType: activities.randomElement()!,
                            duration: duration,
                            calories: Double.random(in: 100...500),
                            startDate: start,
                            endDate: start.addingTimeInterval(duration)
                        ))
                    }
                    data[day] = entries
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return data
        }
    )
}

extension DependencyValues {
    var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}
