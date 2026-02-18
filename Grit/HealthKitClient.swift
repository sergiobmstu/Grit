import ComposableArchitecture
import HealthKit

@DependencyClient
struct HealthKitClient: Sendable {
    var requestAuthorization: @Sendable () async throws -> Void
    var fetchWorkouts: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [Date: Int]
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
        }
    )
}

extension DependencyValues {
    var healthKitClient: HealthKitClient {
        get { self[HealthKitClient.self] }
        set { self[HealthKitClient.self] = newValue }
    }
}
