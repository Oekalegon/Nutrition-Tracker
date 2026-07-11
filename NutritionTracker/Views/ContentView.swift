import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Diary", systemImage: "book.pages") {
                DiaryView()
            }
            Tab("Log", systemImage: "plus.circle") {
                LogView()
            }
            Tab("Stats", systemImage: "chart.bar") {
                StatsView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Food.self, DiaryEntry.self], inMemory: true)
}
