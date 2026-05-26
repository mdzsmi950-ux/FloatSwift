import SwiftUI

@main
struct FloatCashflowApp: App {
    @StateObject private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
