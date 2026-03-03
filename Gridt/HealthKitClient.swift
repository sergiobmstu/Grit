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
    let distanceMeters: Double?

    var paceSecondsPerKm: Double? {
        guard let distance = distanceMeters, distance > 0, duration > 0 else { return nil }
        return duration / (distance / 1000)
    }

    var paceFormatted: String? {
        guard let pace = paceSecondsPerKm else { return nil }
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    var distanceFormatted: String? {
        guard let distance = distanceMeters else { return nil }
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }
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
    var fetchRunningWorkouts: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [Date: Int]
    var fetchRunningWorkoutDetails: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [Date: [WorkoutEntry]]
}

extension HealthKitClient: DependencyKey {
    static let liveValue: HealthKitClient = {
        nonisolated(unsafe) let store = HKHealthStore()

        func fetchSamples(startDate: Date, endDate: Date, runningOnly: Bool, sortDescriptors: [NSSortDescriptor]?) async throws -> [HKSample] {
            var predicates: [NSPredicate] = [
                HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            ]
            if runningOnly {
                predicates.append(HKQuery.predicateForWorkouts(with: .running))
            }
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: compound,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: sortDescriptors
                ) { _, results, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results ?? [])
                    }
                }
                store.execute(query)
            }
        }

        func buildCounts(from samples: [HKSample]) -> [Date: Int] {
            let calendar = Calendar.current
            var counts: [Date: Int] = [:]
            for sample in samples {
                let day = calendar.startOfDay(for: sample.startDate)
                counts[day, default: 0] += 1
            }
            return counts
        }

        func buildDetails(from samples: [HKSample]) -> [Date: [WorkoutEntry]] {
            let calendar = Calendar.current
            var details: [Date: [WorkoutEntry]] = [:]
            for sample in samples {
                guard let workout = sample as? HKWorkout else { continue }
                let day = calendar.startOfDay(for: workout.startDate)
                let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
                    .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                    .sumQuantity()?.doubleValue(for: .meter())
                let entry = WorkoutEntry(
                    id: workout.uuid,
                    activityType: displayName(for: workout.workoutActivityType),
                    duration: workout.duration,
                    calories: calories,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    distanceMeters: distance
                )
                details[day, default: []].append(entry)
            }
            return details
        }

        return HealthKitClient(
            requestAuthorization: {
                guard HKHealthStore.isHealthDataAvailable() else { return }
                try await store.requestAuthorization(
                    toShare: [],
                    read: [
                        HKObjectType.workoutType(),
                        HKQuantityType(.distanceWalkingRunning),
                    ]
                )
            },
            fetchWorkouts: { startDate, endDate in
                let samples = try await fetchSamples(startDate: startDate, endDate: endDate, runningOnly: false, sortDescriptors: nil)
                return buildCounts(from: samples)
            },
            fetchWorkoutDetails: { startDate, endDate in
                let samples = try await fetchSamples(
                    startDate: startDate, endDate: endDate, runningOnly: false,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                )
                return buildDetails(from: samples)
            },
            fetchRunningWorkouts: { startDate, endDate in
                let samples = try await fetchSamples(startDate: startDate, endDate: endDate, runningOnly: true, sortDescriptors: nil)
                return buildCounts(from: samples)
            },
            fetchRunningWorkoutDetails: { startDate, endDate in
                let samples = try await fetchSamples(
                    startDate: startDate, endDate: endDate, runningOnly: true,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
                )
                return buildDetails(from: samples)
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
                            endDate: start.addingTimeInterval(duration),
                            distanceMeters: Double.random(in: 2000...15000)
                        ))
                    }
                    data[day] = entries
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return data
        },
        fetchRunningWorkouts: { startDate, endDate in
            let calendar = Calendar.current
            var data: [Date: Int] = [:]
            var date = startDate
            while date < endDate {
                if Bool.random() {
                    data[calendar.startOfDay(for: date)] = Int.random(in: 1...2)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }
            return data
        },
        fetchRunningWorkoutDetails: { startDate, endDate in
            let calendar = Calendar.current
            var data: [Date: [WorkoutEntry]] = [:]
            var date = startDate
            while date < endDate {
                let day = calendar.startOfDay(for: date)
                if Bool.random() {
                    let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
                    let duration = TimeInterval(Int.random(in: 20...90) * 60)
                    data[day] = [WorkoutEntry(
                        id: UUID(),
                        activityType: "Running",
                        duration: duration,
                        calories: Double.random(in: 200...600),
                        startDate: start,
                        endDate: start.addingTimeInterval(duration),
                        distanceMeters: Double.random(in: 3000...15000)
                    )]
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
