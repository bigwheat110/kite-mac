import Foundation

struct HabitDaySnapshot: Equatable {
    let dateKey: String
    let habits: [HabitDaySnapshotItem]

    var totalCount: Int { habits.count }
    var doneCount: Int { habits.filter(\.isDone).count }
}

struct HabitDaySnapshotItem: Equatable, Identifiable {
    let id: UUID
    let title: String
    let isDone: Bool
    let repeatRule: HabitRepeatRule
}

protocol HabitSyncStore {
    func daySnapshot(for date: Date) throws -> HabitDaySnapshot
}

struct HabitSnapshotComparison: Equatable {
    let dateKey: String
    let matches: Bool
    let json: HabitDaySnapshot
    let other: HabitDaySnapshot
    let differences: [String]
}

struct HabitJSONSnapshotStore: HabitSyncStore {
    let state: AppState

    func daySnapshot(for date: Date) throws -> HabitDaySnapshot {
        HabitSnapshotBuilder.snapshot(from: state, on: date)
    }
}

enum HabitSnapshotBuilder {
    static func snapshot(from state: AppState, on date: Date) -> HabitDaySnapshot {
        let dateKey = HabitDate.key(for: date)
        let selected = HabitDate.date(from: dateKey)
        let items = visibleHabits(from: state, on: selected)
            .map { habit in
                HabitDaySnapshotItem(
                    id: habit.id,
                    title: title(for: habit, in: state, on: selected),
                    isDone: state.entries[dateKey]?[habit.id] == true,
                    repeatRule: habit.repeatRule
                )
            }

        return HabitDaySnapshot(dateKey: dateKey, habits: items)
    }

    static func visibleHabits(from state: AppState, on date: Date) -> [HabitItem] {
        let selected = HabitDate.startOfDay(date)
        let dateKey = HabitDate.key(for: selected)

        return state.habits.filter { habit in
            guard state.hiddenHabits[dateKey]?.contains(habit.id) != true else { return false }
            return habitApplies(habit, on: selected)
        }
    }

    static func title(for habit: HabitItem, in state: AppState, on date: Date) -> String {
        let dateKey = HabitDate.key(for: date)
        if let override = state.dailyOverrides[dateKey]?[habit.id] {
            return override
        }

        let selected = HabitDate.date(from: dateKey)
        let effective = habit.titleHistory
            .sorted { $0.key < $1.key }
            .last(where: { HabitDate.date(from: $0.key) <= selected })

        return effective?.value ?? habit.baseTitle
    }

    private static func habitApplies(_ habit: HabitItem, on selected: Date) -> Bool {
        if let startDateKey = habit.startDateKey,
           HabitDate.date(from: startDateKey) > selected {
            return false
        }
        if let endDateKey = habit.endDateKey,
           HabitDate.date(from: endDateKey) < selected {
            return false
        }
        return habit.repeatRule.applies(to: selected)
    }
}

enum HabitSnapshotComparator {
    static func compare(
        json: HabitSyncStore,
        other: HabitSyncStore,
        on date: Date
    ) throws -> HabitSnapshotComparison {
        let jsonSnapshot = try json.daySnapshot(for: date)
        let otherSnapshot = try other.daySnapshot(for: date)
        let differences = differences(between: jsonSnapshot, and: otherSnapshot)

        return HabitSnapshotComparison(
            dateKey: jsonSnapshot.dateKey,
            matches: differences.isEmpty,
            json: jsonSnapshot,
            other: otherSnapshot,
            differences: differences
        )
    }

    private static func differences(
        between json: HabitDaySnapshot,
        and other: HabitDaySnapshot
    ) -> [String] {
        guard json.dateKey == other.dateKey else {
            return ["dateKey 不一致: JSON \(json.dateKey), Core Data \(other.dateKey)"]
        }

        var output: [String] = []
        if json.totalCount != other.totalCount {
            output.append("visible 数量不一致: JSON \(json.totalCount), Core Data \(other.totalCount)")
        }
        if json.doneCount != other.doneCount {
            output.append("done 数量不一致: JSON \(json.doneCount), Core Data \(other.doneCount)")
        }

        let maxCount = max(json.habits.count, other.habits.count)
        for index in 0..<maxCount {
            guard index < json.habits.count else {
                output.append("Core Data 多出: \(other.habits[index].title)")
                continue
            }
            guard index < other.habits.count else {
                output.append("JSON 多出: \(json.habits[index].title)")
                continue
            }

            let jsonItem = json.habits[index]
            let otherItem = other.habits[index]
            guard jsonItem != otherItem else { continue }
            output.append("第 \(index + 1) 项不同: JSON \(describe(jsonItem)), Core Data \(describe(otherItem))")
        }

        return output
    }

    private static func describe(_ item: HabitDaySnapshotItem) -> String {
        "\(item.title) \(item.isDone ? "done" : "open")"
    }
}
