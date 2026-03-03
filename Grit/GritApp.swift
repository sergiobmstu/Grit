import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct GritApp: App {
    let store: StoreOf<AppFeature>

    init() {
        let container = try! ModelContainer(for: RunningGoal.self, TrainingPlan.self, PlannedWorkout.self)
        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.swiftDataClient = .live(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
