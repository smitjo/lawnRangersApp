import SwiftUI

/// Tab bar hosting the Expenses, Lawns, and Planning screens. Expenses sits on
/// the left, but the app opens on Lawns (the middle tab) via the default
/// selection.
struct MainTabView: View {
    private enum Tab { case expenses, lawns, planning }
    @State private var selection: Tab = .lawns   // open on Lawns even though it's in the middle

    var body: some View {
        TabView(selection: $selection) {
            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "dollarsign.circle.fill") }
                .tag(Tab.expenses)
            HomeView()
                .tabItem { Label("Lawns", systemImage: "leaf.fill") }
                .tag(Tab.lawns)
            PlanningView()
                .tabItem { Label("Planning", systemImage: "calendar") }
                .tag(Tab.planning)
        }
        .tint(.lawnGreen)
    }
}

#Preview {
    MainTabView()
}
