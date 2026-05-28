import AppKit
import Foundation
import UserNotifications

struct WeekDayItem: Identifiable {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let completionCount: Int
    let hasMarker: Bool

    var id: String { HabitDate.key(for: date) }
    var weekdayTitle: String { HabitDate.weekdayTitle(date) }
    var dayLabel: String { HabitDate.dayLabel(date) }
}

struct MonthDayItem: Identifiable {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let completionCount: Int
    let totalCount: Int
    let pendingSummary: String

    var id: String { HabitDate.key(for: date) }
    var dayNumber: String {
        String(HabitDate.calendar.component(.day, from: date))
    }

    var completionSummary: String {
        "✓ \(completionCount)/\(totalCount)"
    }
}

struct ReminderDraft {
    var title = ""
    var hour = 20
    var minute = 0
    var repeatMode: ReminderRepeatMode = .daily
    var linkedHabitId: UUID?
}

struct HabitRepeatDraft: Identifiable {
    let habitId: UUID
    var weekdays: [Int]

    var id: UUID { habitId }
}

struct WeekPlanDay: Identifiable {
    let date: Date
    let habits: [HabitItem]

    var id: String { HabitDate.key(for: date) }
    var weekdayTitle: String { HabitDate.weekdayTitle(date) }
    var dayLabel: String { HabitDate.dayLabel(date) }
}

enum HabitEditMode: String {
    case todayOnly
    case templateFromToday
}

enum HabitDeleteMode: String {
    case todayOnly
    case fromSelectedDate
}

@MainActor
final class HabitViewModel: ObservableObject {
    @Published var state: AppState
    @Published var selectedDate: Date
    @Published var draftTitle = ""
    @Published var activePanel: ToolbarPanel?
    @Published var showingReminderEditor = false
    @Published var reminderDraft = ReminderDraft()
    @Published var statusMessage: String?
    @Published var editingHabitId: UUID?
    @Published var editingHabitText = ""
    @Published var editingMode: HabitEditMode = .todayOnly
    @Published var repeatDraft: HabitRepeatDraft?

    init() {
        let loaded = HabitStore.shared.load()
        state = Self.normalize(loaded)
        selectedDate = HabitDate.date(from: loaded.uiPreferences.lastSelectedDateKey)
    }

    var habits: [HabitItem] { habits(on: selectedDate) }
    var reminders: [ReminderItem] { state.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) } }
    var isFocusModeEnabled: Bool { state.uiPreferences.focusModeEnabled }
    var isAlwaysOnTop: Bool { state.uiPreferences.alwaysOnTop }
    var displayMode: DisplayMode { state.uiPreferences.displayMode }
    var theme: AppTheme { state.uiPreferences.theme }
    var dateKey: String { HabitDate.key(for: selectedDate) }
    var orderedHabits: [HabitItem] {
        let orderMap = Dictionary(uniqueKeysWithValues: state.habits.enumerated().map { ($1.id, $0) })
        return habits.sorted { lhs, rhs in
            let lhsDone = isDone(lhs)
            let rhsDone = isDone(rhs)
            if lhsDone != rhsDone {
                return !lhsDone && rhsDone
            }
            return (orderMap[lhs.id] ?? 0) < (orderMap[rhs.id] ?? 0)
        }
    }

    var pendingHabits: [HabitItem] {
        orderedHabits.filter { !isDone($0) }
    }

    var completedHabits: [HabitItem] {
        orderedHabits.filter { isDone($0) }
    }

    var doneCount: Int {
        habits.filter { isDone($0) }.count
    }

    var pendingCount: Int {
        max(habits.count - doneCount, 0)
    }

    var progressText: String {
        guard !habits.isEmpty else { return "0%" }
        return "\(Int((Double(doneCount) / Double(habits.count)) * 100))%"
    }

    var selectedDateTitle: String {
        HabitDate.monthDayWeekLabel(selectedDate)
    }

    var weekItems: [WeekDayItem] {
        HabitDate.weekDates(containing: selectedDate).map { date in
            let key = HabitDate.key(for: date)
            let dayHabits = habits(on: date)
            let completion = dayHabits.filter { state.entries[key]?[$0.id] == true }.count
            let hasReminder = reminders.contains { reminder in
                reminder.enabled && reminderApplies(reminder, to: date)
            }

            return WeekDayItem(
                date: date,
                isSelected: HabitDate.startOfDay(date) == HabitDate.startOfDay(selectedDate),
                isToday: HabitDate.isToday(date),
                completionCount: completion,
                hasMarker: hasReminder || completion > 0
            )
        }
    }

    var monthTitle: String {
        HabitDate.monthTitle(selectedDate)
    }

    var monthItems: [MonthDayItem] {
        let monthAnchor = HabitDate.startOfMonth(for: selectedDate)
        return HabitDate.monthDates(containing: selectedDate).map { date in
            let key = HabitDate.key(for: date)
            let dayHabits = habits(on: date)
            let completion = dayHabits.filter { state.entries[key]?[$0.id] == true }.count
            let pending = dayHabits
                .filter { state.entries[key]?[$0.id] != true }
                .map { title(for: $0, on: date) }
            let pendingSummary: String
            switch pending.count {
            case 0:
                pendingSummary = "○ 无"
            case 1...2:
                pendingSummary = "○ \(pending.joined(separator: "、"))"
            default:
                pendingSummary = "○ \(pending.prefix(2).joined(separator: "、")) +\(pending.count - 2)"
            }

            return MonthDayItem(
                date: date,
                isCurrentMonth: HabitDate.isInSameMonth(date, as: monthAnchor),
                isSelected: HabitDate.startOfDay(date) == HabitDate.startOfDay(selectedDate),
                isToday: HabitDate.isToday(date),
                completionCount: completion,
                totalCount: dayHabits.count,
                pendingSummary: pendingSummary
            )
        }
    }

    var focusButtonTitle: String {
        state.focusSession.active ? "结束专注" : "开始专注"
    }

    var reminderSummary: String {
        "\(reminders.filter(\.enabled).count) 个提醒"
    }

    var weekPlanDays: [WeekPlanDay] {
        HabitDate.weekDates(containing: selectedDate).map { date in
            WeekPlanDay(date: date, habits: habits(on: date))
        }
    }

    func title(for habit: HabitItem) -> String {
        title(for: habit, on: selectedDate)
    }

    func title(for habit: HabitItem, on date: Date) -> String {
        let key = HabitDate.key(for: date)
        if let override = state.dailyOverrides[key]?[habit.id] {
            return override
        }

        let selected = HabitDate.date(from: key)
        let effective = habit.titleHistory
            .sorted { $0.key < $1.key }
            .last(where: { HabitDate.date(from: $0.key) <= selected })

        return effective?.value ?? habit.baseTitle
    }

    func isDone(_ habit: HabitItem) -> Bool {
        state.entries[dateKey]?[habit.id] == true
    }

    func select(date: Date) {
        selectedDate = HabitDate.startOfDay(date)
        var next = state
        next.uiPreferences.lastSelectedDateKey = HabitDate.key(for: selectedDate)
        state = next
        persist()
    }

    func shiftWeek(by offset: Int) {
        let next = Calendar.current.date(byAdding: .day, value: offset * 7, to: selectedDate) ?? selectedDate
        select(date: next)
    }

    func shiftMonth(by offset: Int) {
        let next = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) ?? selectedDate
        select(date: next)
    }

    func jumpToToday() {
        select(date: .now)
    }

    func toggle(_ habit: HabitItem) {
        var next = state
        var day = next.entries[dateKey] ?? [:]
        day[habit.id] = !(day[habit.id] ?? false)
        next.entries[dateKey] = day
        state = next
        persist()
    }

    func addHabit() {
        addHabit(scope: .templateFromToday)
    }

    func addTodayOnlyHabit() {
        addHabit(scope: .todayOnly)
    }

    private func addHabit(scope: HabitEditMode) {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var next = state
        switch scope {
        case .todayOnly:
            next.habits.append(HabitItem(title: trimmed, startDateKey: dateKey, endDateKey: dateKey))
            statusMessage = "仅今天已新增"
        case .templateFromToday:
            next.habits.append(HabitItem(title: trimmed, startDateKey: dateKey))
            statusMessage = "已加入模板，从这一天起生效"
        }
        state = next
        draftTitle = ""
        persist()
    }

    func removeHabit(_ habit: HabitItem) {
        var next = state
        next.habits.removeAll { $0.id == habit.id }
        for key in next.entries.keys {
            next.entries[key]?[habit.id] = nil
            next.dailyOverrides[key]?[habit.id] = nil
        }
        next.reminders = next.reminders.map { reminder in
            var updated = reminder
            if updated.linkedHabitId == habit.id {
                updated.linkedHabitId = nil
            }
            return updated
        }
        state = next
        persist()
    }

    func hideHabitToday(_ habit: HabitItem) {
        var next = state
        var hidden = next.hiddenHabits[dateKey] ?? []
        if !hidden.contains(habit.id) {
            hidden.append(habit.id)
        }
        next.hiddenHabits[dateKey] = hidden
        state = next
        statusMessage = "仅今天已隐藏"
        persist()
    }

    func removeHabitFromSelectedDate(_ habit: HabitItem) {
        guard let index = state.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        var next = state
        let previousDay = HabitDate.calendar.date(byAdding: .day, value: -1, to: HabitDate.startOfDay(selectedDate)) ?? selectedDate
        next.habits[index].endDateKey = HabitDate.key(for: previousDay)
        next.hiddenHabits[dateKey]?.removeAll { $0 == habit.id }
        state = next
        statusMessage = "已从这一天起删除"
        persist()
    }

    func setRepeatRule(_ rule: HabitRepeatRule, for habit: HabitItem) {
        guard let index = state.habits.firstIndex(where: { $0.id == habit.id }) else { return }
        var next = state
        next.habits[index].repeatRule = normalizedRepeatRule(rule)
        state = next
        statusMessage = "重复规则已设为\(next.habits[index].repeatRule.title)"
        persist()
    }

    func beginCustomRepeatEdit(for habit: HabitItem) {
        let weekdays: [Int]
        if habit.repeatRule.kind == .custom {
            weekdays = habit.repeatRule.weekdays
        } else {
            weekdays = [HabitDate.calendar.component(.weekday, from: selectedDate)]
        }
        repeatDraft = HabitRepeatDraft(habitId: habit.id, weekdays: Self.normalizedWeekdays(weekdays))
    }

    func toggleRepeatDraftWeekday(_ weekday: Int) {
        guard var draft = repeatDraft else { return }
        if draft.weekdays.contains(weekday) {
            draft.weekdays.removeAll { $0 == weekday }
        } else {
            draft.weekdays.append(weekday)
        }
        repeatDraft = draft
    }

    func saveRepeatDraft() {
        guard let draft = repeatDraft,
              let index = state.habits.firstIndex(where: { $0.id == draft.habitId })
        else { return }
        let weekdays = Self.normalizedWeekdays(draft.weekdays)
        guard !weekdays.isEmpty else {
            statusMessage = "至少选择一天"
            return
        }
        var next = state
        next.habits[index].repeatRule = .custom(weekdays)
        state = next
        repeatDraft = nil
        statusMessage = "重复规则已设为\(next.habits[index].repeatRule.title)"
        persist()
    }

    func cancelRepeatDraft() {
        repeatDraft = nil
    }

    func isRepeatRuleSelected(_ kind: HabitRepeatKind, for habit: HabitItem) -> Bool {
        habit.repeatRule.kind == kind
    }

    func isCustomWeekdaySelected(_ weekday: Int, for habit: HabitItem) -> Bool {
        if habit.repeatRule.kind == .custom {
            return habit.repeatRule.weekdays.contains(weekday)
        }
        return weekday == HabitDate.calendar.component(.weekday, from: selectedDate)
    }

    func toggleDisplayMode() {
        var next = state
        next.uiPreferences.displayMode = displayMode == .normal ? .compact : .normal
        state = next
        persist()
    }

    func setTheme(_ theme: AppTheme) {
        var next = state
        next.uiPreferences.theme = theme
        state = next
        persist()
    }

    func toggleFocusMode() {
        var next = state
        next.uiPreferences.focusModeEnabled.toggle()
        next.focusSession.active = next.uiPreferences.focusModeEnabled
        next.focusSession.startedAt = next.uiPreferences.focusModeEnabled ? .now : nil
        state = next
        persist()
    }

    func openOverview() {
        activePanel = .overview
    }

    func openCalendar() {
        activePanel = .calendar
    }

    func openWeekPlan() {
        activePanel = .weekPlan
    }

    func openReminders() {
        reminderDraft = ReminderDraft()
        showingReminderEditor = true
    }

    func beginEdit(_ habit: HabitItem, mode: HabitEditMode) {
        editingHabitId = habit.id
        editingMode = mode
        editingHabitText = mode == .todayOnly ? title(for: habit) : habit.title
    }

    func cancelEdit() {
        editingHabitId = nil
        editingHabitText = ""
    }

    func saveHabitEdit() {
        guard let habitId = editingHabitId,
              let habit = state.habits.first(where: { $0.id == habitId })
        else { return }
        let trimmed = editingHabitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelEdit()
            return
        }

        var next = state

        switch editingMode {
        case .todayOnly:
            var overrides = next.dailyOverrides[dateKey] ?? [:]
            overrides[habit.id] = trimmed
            next.dailyOverrides[dateKey] = overrides
            statusMessage = "仅今天已改名"
        case .templateFromToday:
            if let index = next.habits.firstIndex(where: { $0.id == habit.id }) {
                let oldTitle = title(for: next.habits[index])
                next.habits[index].title = trimmed
                next.habits[index].titleHistory[dateKey] = trimmed
                if next.habits[index].baseTitle.isEmpty {
                    next.habits[index].baseTitle = oldTitle
                }
                next.dailyOverrides[dateKey]?[habit.id] = nil
                statusMessage = "模板名已更新，从这一天起生效"
            }
        }

        state = next
        cancelEdit()
        persist()
    }

    func saveReminder() {
        let trimmed = reminderDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let reminder = ReminderItem(
            title: trimmed,
            hour: reminderDraft.hour,
            minute: reminderDraft.minute,
            repeatMode: reminderDraft.repeatMode,
            linkedHabitId: reminderDraft.linkedHabitId
        )
        var next = state
        next.reminders.append(reminder)
        state = next
        persist()
        showingReminderEditor = false
        Task { await scheduleReminder(reminder) }
    }

    func removeReminder(_ reminder: ReminderItem) {
        var next = state
        next.reminders.removeAll { $0.id == reminder.id }
        state = next
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        persist()
    }

    func toggleReminder(_ reminder: ReminderItem) {
        var next = state
        guard let index = next.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        next.reminders[index].enabled.toggle()
        let updated = next.reminders[index]
        state = next
        persist()

        if updated.enabled {
            Task { await scheduleReminder(updated) }
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [updated.id.uuidString])
        }
    }

    func toggleAlwaysOnTop() {
        var next = state
        next.uiPreferences.alwaysOnTop.toggle()
        state = next
        applyWindowPreferences()
        persist()
    }

    func minimizeWindow() {
        NSApplication.shared.keyWindow?.miniaturize(nil)
    }

    func closeWindow() {
        NSApplication.shared.keyWindow?.close()
    }

    func applyWindowPreferences() {
        guard let window = NSApplication.shared.windows.first else { return }
        window.level = state.uiPreferences.alwaysOnTop ? .floating : .normal
    }

    var weeklyCompletionSummary: String {
        let total = weekItems.reduce(0) { $0 + $1.completionCount }
        return "本周完成 \(total) 项"
    }

    var reminderPanelItems: [ReminderItem] {
        reminders
    }

    private func reminderApplies(_ reminder: ReminderItem, to date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch reminder.repeatMode {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .weekends:
            return weekday == 1 || weekday == 7
        }
    }

    private func scheduleReminder(_ reminder: ReminderItem) async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                statusMessage = "提醒权限未开启"
                return
            }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "Kite 待办提醒你查看今天的事项"
            content.sound = .default

            var components = DateComponents()
            components.hour = reminder.hour
            components.minute = reminder.minute

            switch reminder.repeatMode {
            case .daily:
                break
            case .weekdays:
                components.weekday = 2
            case .weekends:
                components.weekday = 1
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: reminder.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
            statusMessage = "提醒已保存"
        } catch {
            statusMessage = "提醒保存失败"
        }
    }

    private func persist() {
        HabitStore.shared.save(state)
    }

    private func habits(on date: Date) -> [HabitItem] {
        state.habits.filter { habitApplies($0, on: date) }
    }

    private func habitApplies(_ habit: HabitItem, on date: Date) -> Bool {
        let selected = HabitDate.startOfDay(date)
        let key = HabitDate.key(for: selected)
        if state.hiddenHabits[key]?.contains(habit.id) == true {
            return false
        }
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

    private func normalizedRepeatRule(_ rule: HabitRepeatRule) -> HabitRepeatRule {
        if rule.kind == .custom {
            let weekdays = Self.normalizedWeekdays(rule.weekdays)
            if weekdays.isEmpty {
                return .custom([HabitDate.calendar.component(.weekday, from: selectedDate)])
            }
            return .custom(weekdays)
        }
        return rule
    }

    private static func normalizedWeekdays(_ weekdays: [Int]) -> [Int] {
        Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
    }

    private static func normalize(_ state: AppState) -> AppState {
        var normalized = state
        normalized.habits = normalized.habits.map { habit in
            var updated = habit
            if updated.baseTitle.isEmpty {
                updated.baseTitle = updated.title
            }
            updated.repeatRule = normalizedRuleForStoredHabit(updated.repeatRule)
            return updated
        }
        return normalized
    }

    private static func normalizedRuleForStoredHabit(_ rule: HabitRepeatRule) -> HabitRepeatRule {
        if rule.kind == .custom {
            let weekdays = normalizedWeekdays(rule.weekdays)
            return weekdays.isEmpty ? .daily : .custom(weekdays)
        }
        return rule
    }
}
