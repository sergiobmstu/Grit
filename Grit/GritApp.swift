import ComposableArchitecture
import SwiftUI

@main
struct GritApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
