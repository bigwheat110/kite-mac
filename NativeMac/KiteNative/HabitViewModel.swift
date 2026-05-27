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

struct ReminderDraft {
    var title = ""
    var hour = 20
    var minute = 0
    var repeatMode: ReminderRepeatMode = .daily
    var linkedHabitId: UUID?
}

enum HabitEditMode: String {
    case todayOnly
    case templateFromTomorrow
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
    @Published var editingHabit: HabitItem?
    @Published var editingHabitText = ""
    @Published var editingMode: HabitEditMode = .todayOnly

    init() {
        let loaded = HabitStore.shared.load()
        state = loaded
        selectedDate = HabitDate.date(from: loaded.uiPreferences.lastSelectedDateKey)
    }

    var habits: [HabitItem] { state.habits }
    var reminders: [ReminderItem] { state.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) } }
    var isFocusModeEnabled: Bool { state.uiPreferences.focusModeEnabled }
    var isAlwaysOnTop: Bool { state.uiPreferences.alwaysOnTop }
    var displayMode: DisplayMode { state.uiPreferences.displayMode }
    var dateKey: String { HabitDate.key(for: selectedDate) }

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
            let completion = habits.filter { state.entries[key]?[$0.id] == true }.count
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

    var focusButtonTitle: String {
        state.focusSession.active ? "结束专注" : "开始专注"
    }

    var reminderSummary: String {
        "\(reminders.filter(\.enabled).count) 个提醒"
    }

    func title(for habit: HabitItem) -> String {
        state.dailyOverrides[dateKey]?[habit.id] ?? habit.title
    }

    func isDone(_ habit: HabitItem) -> Bool {
        state.entries[dateKey]?[habit.id] == true
    }

    func select(date: Date) {
        selectedDate = HabitDate.startOfDay(date)
        state.uiPreferences.lastSelectedDateKey = HabitDate.key(for: selectedDate)
        persist()
    }

    func shiftWeek(by offset: Int) {
        let next = Calendar.current.date(byAdding: .day, value: offset * 7, to: selectedDate) ?? selectedDate
        select(date: next)
    }

    func jumpToToday() {
        select(date: .now)
    }

    func toggle(_ habit: HabitItem) {
        var day = state.entries[dateKey] ?? [:]
        day[habit.id] = !(day[habit.id] ?? false)
        state.entries[dateKey] = day
        persist()
    }

    func addHabit() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state.habits.append(HabitItem(title: trimmed))
        draftTitle = ""
        persist()
    }

    func removeHabit(_ habit: HabitItem) {
        state.habits.removeAll { $0.id == habit.id }
        for key in state.entries.keys {
            state.entries[key]?[habit.id] = nil
            state.dailyOverrides[key]?[habit.id] = nil
        }
        state.reminders = state.reminders.map { reminder in
            var updated = reminder
            if updated.linkedHabitId == habit.id {
                updated.linkedHabitId = nil
            }
            return updated
        }
        persist()
    }

    func toggleDisplayMode() {
        state.uiPreferences.displayMode = displayMode == .normal ? .compact : .normal
        persist()
    }

    func toggleFocusMode() {
        state.uiPreferences.focusModeEnabled.toggle()
        state.focusSession.active = state.uiPreferences.focusModeEnabled
        state.focusSession.startedAt = state.uiPreferences.focusModeEnabled ? .now : nil
        persist()
    }

    func openOverview() {
        activePanel = .overview
    }

    func openCalendar() {
        activePanel = .calendar
    }

    func openReminders() {
        reminderDraft = ReminderDraft()
        showingReminderEditor = true
    }

    func beginEdit(_ habit: HabitItem, mode: HabitEditMode) {
        editingHabit = habit
        editingMode = mode
        editingHabitText = mode == .todayOnly ? title(for: habit) : habit.title
    }

    func saveHabitEdit() {
        guard let habit = editingHabit else { return }
        let trimmed = editingHabitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch editingMode {
        case .todayOnly:
            var overrides = state.dailyOverrides[dateKey] ?? [:]
            overrides[habit.id] = trimmed
            state.dailyOverrides[dateKey] = overrides
            statusMessage = "仅今天已改名"
        case .templateFromTomorrow:
            if let index = state.habits.firstIndex(where: { $0.id == habit.id }) {
                state.habits[index].title = trimmed
                statusMessage = "模板名已更新，明天生效"
            }
        }

        editingHabit = nil
        editingHabitText = ""
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
        state.reminders.append(reminder)
        persist()
        showingReminderEditor = false
        Task { await scheduleReminder(reminder) }
    }

    func removeReminder(_ reminder: ReminderItem) {
        state.reminders.removeAll { $0.id == reminder.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        persist()
    }

    func toggleReminder(_ reminder: ReminderItem) {
        guard let index = state.reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        state.reminders[index].enabled.toggle()
        let updated = state.reminders[index]
        persist()

        if updated.enabled {
            Task { await scheduleReminder(updated) }
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [updated.id.uuidString])
        }
    }

    func toggleAlwaysOnTop() {
        state.uiPreferences.alwaysOnTop.toggle()
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
}
