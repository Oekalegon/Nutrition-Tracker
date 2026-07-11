import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]

    var body: some View {
        NavigationStack {
            Group {
                if summaries.isEmpty {
                    ContentUnavailableView(
                        "No data yet",
                        systemImage: "chart.bar",
                        description: Text("Charts will appear once you've logged a few days.")
                    )
                } else {
                    List(summaries) { summary in
                        Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [DailySummary.self, DailyNutrientTotal.self], inMemory: true)
}
