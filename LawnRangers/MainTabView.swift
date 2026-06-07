import SwiftUI

/// Tab bar hosting the Lawns home and the Planning screen.
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Lawns", systemImage: "leaf.fill") }
            PlanningView()
                .tabItem { Label("Planning", systemImage: "calendar") }
        }
        .tint(.lawnGreen)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [LawnLog.self, Expense.self], inMemory: true)
}
