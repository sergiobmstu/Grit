import ComposableArchitecture
import FirebaseAppDistribution
import FirebaseCore
import SwiftData
import SwiftUI

@main
struct GridtApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
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
                .task { await checkForUpdate() }
        }
    }

    private func checkForUpdate() async {
        do {
            let release = try await AppDistribution.appDistribution().checkForUpdate()
            guard let release else { return }
            await UIApplication.shared.open(release.downloadURL)
        } catch {
            // Not a Firebase App Distribution build or no update available — ignore
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
