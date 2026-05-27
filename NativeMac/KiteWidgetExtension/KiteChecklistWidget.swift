import SwiftUI
import WidgetKit

struct KiteEntry: TimelineEntry {
    let date: Date
    let state: AppState
}

struct KiteProvider: TimelineProvider {
    func placeholder(in context: Context) -> KiteEntry {
        KiteEntry(date: .now, state: .default)
    }

    func getSnapshot(in context: Context, completion: @escaping (KiteEntry) -> Void) {
        completion(KiteEntry(date: .now, state: HabitStore.shared.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KiteEntry>) -> Void) {
        let entry = KiteEntry(date: .now, state: HabitStore.shared.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct KiteChecklistWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KiteChecklistWidget", provider: KiteProvider()) { entry in
            KiteChecklistWidgetView(entry: entry)
        }
        .configurationDisplayName("Kite 待办")
        .description("在桌面上查看今天的固定待办完成情况。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct KiteChecklistWidgetView: View {
    let entry: KiteEntry

    private var todayKey: String { HabitDate.key(for: .now) }

    private var topHabits: [HabitItem] {
        Array(entry.state.habits.prefix(6))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.15, blue: 0.26), Color(red: 0.07, green: 0.10, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Kite 待办")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(Date.now.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                ForEach(topHabits) { habit in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isDone(habit) ? Color.green : Color.white.opacity(0.25))
                            .frame(width: 10, height: 10)
                        Text(habit.title)
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(16)
        }
        .containerBackground(.clear, for: .widget)
    }

    private func isDone(_ habit: HabitItem) -> Bool {
        entry.state.entries[todayKey]?[habit.id] == true
    }
}
