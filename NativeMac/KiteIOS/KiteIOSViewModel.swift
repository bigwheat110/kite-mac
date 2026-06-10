import CloudKit
import Combine
import Foundation
import SwiftUI

struct KiteIOSWeekDayItem: Identifiable {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let doneCount: Int
    let totalCount: Int

    var id: String { HabitDate.key(for: date) }
    var weekdayTitle: String { HabitDate.weekdayTitle(date) }
    var dayLabel: String { HabitDate.dayLabel(date) }
    var countText: String { "\(doneCount)/\(totalCount)" }
    var hasProgress: Bool { doneCount > 0 }
}

struct KiteIOSMonthDayItem: Identifiable {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let doneCount: Int
    let totalCount: Int
    let pendingTitles: [String]

    var id: String { HabitDate.key(for: date) }
    var dayNumber: String {
        String(HabitDate.calendar.component(.day, from: date))
    }
    var completionText: String { "\(doneCount)/\(totalCount)" }
    var pendingText: String {
        if totalCount == 0 { return "无" }
        if pendingTitles.isEmpty { return "已完成" }
        if pendingTitles.count <= 2 { return pendingTitles.joined(separator: "、") }
        return "\(pendingTitles.prefix(2).joined(separator: "、")) +\(pendingTitles.count - 2)"
    }
}

struct KiteIOSWeekPlanDay: Identifiable {
    let date: Date
    let habits: [HabitDaySnapshotItem]

    var id: String { HabitDate.key(for: date) }
    var weekdayTitle: String { HabitDate.weekdayTitle(date) }
    var dayLabel: String { HabitDate.dayLabel(date) }
}

@MainActor
final class KiteIOSViewModel: ObservableObject {
    @Published private(set) var snapshot: HabitDaySnapshot
    @Published private(set) var weekItems: [KiteIOSWeekDayItem] = []
    @Published private(set) var monthItems: [KiteIOSMonthDayItem] = []
    @Published private(set) var weekPlanDays: [KiteIOSWeekPlanDay] = []
    @Published private(set) var loadMessage: String?
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var iCloudAccountStatusText = "尚未检查"
    @Published private(set) var cloudKitEventText = "尚未收到同步事件"
    @Published private(set) var lastSyncMarkerTitle: String?
    @Published private(set) var syncSettingsMessage: String?
    @Published private(set) var selectedDate: Date
    @Published var draftTitle = ""
    private let syncStore: HabitCoreDataStore
    private let syncStoreURL: URL
    private var cloudKitSyncMonitor: HabitCloudKitSyncMonitor?
    let syncMode: HabitSyncStoreMode

    init(
        selectedDate: Date = .now,
        syncStore: HabitCoreDataStore = KiteIOSCoreDataStoreFactory.makeStore(),
        syncMode: HabitSyncStoreMode = KiteIOSCoreDataStoreFactory.mode,
        syncStoreURL: URL = KiteIOSCoreDataStoreFactory.storeURL(),
        seedsDefaultHabits: Bool = true
    ) {
        self.selectedDate = HabitDate.startOfDay(selectedDate)
        self.syncStore = syncStore
        self.syncMode = syncMode
        self.syncStoreURL = syncStoreURL
        self.snapshot = HabitDaySnapshot(dateKey: HabitDate.key(for: selectedDate), habits: [])
        if syncMode == .cloudKit {
            let monitor = HabitCloudKitSyncMonitor { [weak self] summary in
                Task { @MainActor in
                    self?.cloudKitEventText = summary.text
                    if summary.shouldReloadLocalData {
                        self?.loadSnapshot()
                    }
                }
            }
            monitor.start()
            self.cloudKitSyncMonitor = monitor
        }
        loadSnapshot()
        if seedsDefaultHabits {
            seedDefaultHabitsIfNeeded()
        }
    }

    var dateTitle: String {
        HabitDate.monthDayWeekLabel(selectedDate)
    }

    var monthTitle: String {
        HabitDate.monthTitle(selectedDate)
    }

    var progressText: String {
        guard snapshot.totalCount > 0 else { return "0%" }
        return "\(Int((Double(snapshot.doneCount) / Double(snapshot.totalCount)) * 100))%"
    }

    var countText: String {
        "\(snapshot.doneCount)/\(snapshot.totalCount)"
    }

    var syncModeTitle: String {
        syncMode.title
    }

    var syncModeDetail: String {
        syncMode.detail
    }

    var syncStorePath: String {
        syncStoreURL.path
    }

    var cloudKitLaunchArgumentText: String {
        HabitSyncStoreMode.cloudKitLaunchArgument
    }

    var cloudKitContainerIdentifierText: String {
        HabitCoreDataStack.cloudKitContainerIdentifier
    }

    var bundleIdentifierText: String {
        Bundle.main.bundleIdentifier ?? "未知"
    }

    var nextLaunchSyncModeText: String {
        preferredSyncMode.title
    }

    var needsRestartForPreferredSyncMode: Bool {
        preferredSyncMode != syncMode
    }

    var canWriteSyncMarker: Bool {
        syncMode == .cloudKit
    }

    var restartNoticeText: String {
        needsRestartForPreferredSyncMode
            ? "重启后切换到\(preferredSyncMode.title)。当前仍在使用\(syncMode.title)。"
            : "当前启动已使用\(syncMode.title)。"
    }

    func setNextLaunchSyncMode(_ mode: HabitSyncStoreMode) {
        HabitSyncStoreMode.preference = mode
        syncSettingsMessage = "下次启动将使用：\(mode.title)"
        objectWillChange.send()
    }

    private var preferredSyncMode: HabitSyncStoreMode {
        HabitSyncStoreMode.preferredOrCurrent
    }

    var lastRefreshText: String {
        guard let lastRefreshDate else { return "尚未刷新" }
        return Self.refreshFormatter.string(from: lastRefreshDate)
    }

    var lastSyncMarkerText: String {
        lastSyncMarkerTitle ?? "尚未写入"
    }

    var isSelectedDateToday: Bool {
        HabitDate.isToday(selectedDate)
    }

    var defaultHabitCount: Int {
        AppState.default.habits.count
    }

    func reload() {
        loadSnapshot()
        syncSettingsMessage = "已刷新当前日期数据"
    }

    func select(date: Date) {
        selectedDate = HabitDate.startOfDay(date)
        loadSnapshot()
    }

    func refreshICloudAccountStatus() {
        iCloudAccountStatusText = "检查中..."
        Task {
            do {
                let status = try await CKContainer(identifier: HabitCoreDataStack.cloudKitContainerIdentifier)
                    .accountStatus()
                iCloudAccountStatusText = Self.describeICloudAccountStatus(status)
                syncSettingsMessage = status == .available
                    ? "iCloud 账号可用"
                    : "iCloud 账号状态：\(iCloudAccountStatusText)"
            } catch {
                iCloudAccountStatusText = "检查失败：\(error.localizedDescription)"
                syncSettingsMessage = iCloudAccountStatusText
            }
        }
    }

    func shiftDay(by offset: Int) {
        selectedDate = HabitDate.calendar.date(
            byAdding: .day,
            value: offset,
            to: selectedDate
        ) ?? selectedDate
        loadSnapshot()
    }

    func shiftWeek(by offset: Int) {
        selectedDate = HabitDate.calendar.date(
            byAdding: .day,
            value: offset * 7,
            to: selectedDate
        ) ?? selectedDate
        loadSnapshot()
    }

    func shiftMonth(by offset: Int) {
        selectedDate = HabitDate.calendar.date(
            byAdding: .month,
            value: offset,
            to: selectedDate
        ) ?? selectedDate
        loadSnapshot()
    }

    func jumpToToday() {
        selectedDate = HabitDate.startOfDay(.now)
        loadSnapshot()
    }

    func addHabit() {
        addHabit(todayOnly: false)
    }

    func addTodayOnlyHabit() {
        addHabit(todayOnly: true)
    }

    private func addHabit(todayOnly: Bool) {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard hasVisibleHabit(named: trimmed) == false else {
            loadMessage = "今天已有同名事项"
            return
        }
        performWrite("新增失败") {
            try syncStore.addHabit(title: trimmed, startDate: selectedDate, todayOnly: todayOnly)
        }
        draftTitle = ""
    }

    func toggle(_ habit: HabitDaySnapshotItem) {
        performWrite("打卡失败") {
            try syncStore.toggleDone(habitID: habit.id, on: selectedDate)
        }
    }

    func renameToday(_ habit: HabitDaySnapshotItem, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard hasVisibleHabit(named: trimmed, excluding: habit.id) == false else {
            loadMessage = "今天已有同名事项"
            return
        }
        performWrite("改名失败") {
            try syncStore.renameHabitForDay(habitID: habit.id, title: trimmed, on: selectedDate)
        }
    }

    func renameFromToday(_ habit: HabitDaySnapshotItem, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard hasVisibleHabit(named: trimmed, excluding: habit.id) == false else {
            loadMessage = "今天已有同名事项"
            return
        }
        performWrite("改名失败") {
            try syncStore.renameHabitFromDate(habitID: habit.id, title: trimmed, from: selectedDate)
        }
    }

    func hideToday(_ habit: HabitDaySnapshotItem) {
        performWrite("隐藏失败") {
            try syncStore.hideHabitForDay(habitID: habit.id, on: selectedDate)
        }
    }

    func deleteFromToday(_ habit: HabitDaySnapshotItem) {
        performWrite("删除失败") {
            try syncStore.endHabitFromDate(habitID: habit.id, from: selectedDate)
        }
    }

    func deleteEverywhere(_ habit: HabitDaySnapshotItem) {
        performWrite("彻底删除失败") {
            try syncStore.deleteHabit(habitID: habit.id)
        }
    }

    func setRepeatRule(_ rule: HabitRepeatRule, for habit: HabitDaySnapshotItem) {
        let normalized = rule.normalized(fallbackWeekday: HabitDate.calendar.component(.weekday, from: selectedDate))
        performWrite("重复规则保存失败") {
            try syncStore.updateRepeatRule(habitID: habit.id, rule: normalized)
        }
    }

    func setCustomRepeatWeekdays(_ weekdays: [Int], for habit: HabitDaySnapshotItem) {
        let normalized = HabitRepeatRule.normalizedWeekdays(weekdays)
        guard normalized.isEmpty == false else { return }
        setRepeatRule(.custom(normalized), for: habit)
    }

    func moveHabits(from source: IndexSet, to destination: Int) {
        var reordered = snapshot.habits
        reordered.move(fromOffsets: source, toOffset: destination)
        performWrite("排序保存失败") {
            try syncStore.reorderHabits(orderedIDs: reordered.map(\.id))
        }
    }

    func seedDefaultHabits() {
        do {
            let existingState = try syncStore.loadAppState()
            let existingIDs = Set(existingState.habits.map(\.id))
            let missingDefaults = AppState.default.habits.filter { existingIDs.contains($0.id) == false }
            for habit in missingDefaults {
                try syncStore.addHabit(
                    title: habit.title,
                    startDate: selectedDate,
                    todayOnly: false,
                    id: habit.id
                )
            }
            loadSnapshot(
                successMessage: missingDefaults.isEmpty
                    ? "默认习惯已存在"
                    : "已补齐 \(missingDefaults.count) 个默认习惯"
            )
        } catch {
            loadMessage = Self.errorMessage("默认习惯添加失败", error: error)
        }
    }

    private func seedDefaultHabitsIfNeeded() {
        guard syncMode == .local else { return }
        guard (try? syncStore.loadAppState().habits.isEmpty) == true else { return }
        seedDefaultHabits()
    }

    func insertSyncMarker() {
        guard canWriteSyncMarker else {
            let message = "请先切到 iCloud / CloudKit 并重启，再写入同步标记"
            loadMessage = message
            syncSettingsMessage = message
            return
        }

        let dateKey = HabitDate.key(for: selectedDate)
        let timeText = Self.syncMarkerTimeFormatter.string(from: .now)
        let title = "iOS同步标记-\(dateKey)-\(timeText)"
        do {
            try syncStore.addHabit(title: title, startDate: selectedDate, todayOnly: false)
            lastSyncMarkerTitle = title
            let message = "同步标记已写入：\(title)"
            loadSnapshot(successMessage: message)
            syncSettingsMessage = message
        } catch {
            let message = Self.errorMessage("同步标记写入失败", error: error)
            loadMessage = message
            syncSettingsMessage = message
        }
    }

    private func loadSnapshot(successMessage: String? = nil) {
        do {
            snapshot = try syncStore.daySnapshot(for: selectedDate)
            weekItems = makeWeekItems()
            monthItems = makeMonthItems()
            weekPlanDays = makeWeekPlanDays()
            loadMessage = successMessage
            lastRefreshDate = .now
        } catch {
            snapshot = HabitDaySnapshot(dateKey: HabitDate.key(for: selectedDate), habits: [])
            weekItems = []
            monthItems = []
            weekPlanDays = []
            loadMessage = Self.errorMessage("暂时无法读取同步数据", error: error)
        }
    }

    private func makeWeekItems() -> [KiteIOSWeekDayItem] {
        HabitDate.weekDates(containing: selectedDate).map { date in
            let daySnapshot = try? syncStore.daySnapshot(for: date)
            return KiteIOSWeekDayItem(
                date: date,
                isSelected: HabitDate.startOfDay(date) == selectedDate,
                isToday: HabitDate.isToday(date),
                doneCount: daySnapshot?.doneCount ?? 0,
                totalCount: daySnapshot?.totalCount ?? 0
            )
        }
    }

    private func makeMonthItems() -> [KiteIOSMonthDayItem] {
        let monthAnchor = HabitDate.startOfMonth(for: selectedDate)
        return HabitDate.monthDates(containing: selectedDate).map { date in
            let daySnapshot = (try? syncStore.daySnapshot(for: date))
                ?? HabitDaySnapshot(dateKey: HabitDate.key(for: date), habits: [])
            let pendingTitles = daySnapshot.habits
                .filter { $0.isDone == false }
                .map(\.title)

            return KiteIOSMonthDayItem(
                date: date,
                isCurrentMonth: HabitDate.isInSameMonth(date, as: monthAnchor),
                isSelected: HabitDate.startOfDay(date) == selectedDate,
                isToday: HabitDate.isToday(date),
                doneCount: daySnapshot.doneCount,
                totalCount: daySnapshot.totalCount,
                pendingTitles: pendingTitles
            )
        }
    }

    private func makeWeekPlanDays() -> [KiteIOSWeekPlanDay] {
        HabitDate.weekDates(containing: selectedDate).map { date in
            KiteIOSWeekPlanDay(
                date: date,
                habits: (try? syncStore.daySnapshot(for: date).habits) ?? []
            )
        }
    }

    private func performWrite(_ failureMessage: String, operation: () throws -> Void) {
        do {
            try operation()
            loadSnapshot()
        } catch {
            loadMessage = Self.errorMessage(failureMessage, error: error)
        }
    }

    private func hasVisibleHabit(named title: String, excluding habitID: UUID? = nil) -> Bool {
        let candidateKey = HabitTitle.duplicateKey(title)
        let currentSnapshot = (try? syncStore.daySnapshot(for: selectedDate)) ?? snapshot
        return currentSnapshot.habits.contains { habit in
            guard habit.id != habitID else { return false }
            return HabitTitle.duplicateKey(habit.title) == candidateKey
        }
    }

    private static let refreshFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm:ss"
        return formatter
    }()

    private static let syncMarkerTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HHmmss"
        return formatter
    }()

    private static func describeICloudAccountStatus(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "可用"
        case .noAccount:
            return "未登录 iCloud"
        case .restricted:
            return "受限"
        case .couldNotDetermine:
            return "无法确定"
        case .temporarilyUnavailable:
            return "暂时不可用"
        @unknown default:
            return "未知状态"
        }
    }

    private static func errorMessage(_ prefix: String, error: Error) -> String {
        "\(prefix)：\(error.localizedDescription)"
    }
}
