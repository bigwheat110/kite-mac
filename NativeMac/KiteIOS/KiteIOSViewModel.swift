import CloudKit
import Combine
import Foundation

@MainActor
final class KiteIOSViewModel: ObservableObject {
    @Published private(set) var snapshot: HabitDaySnapshot
    @Published private(set) var loadMessage: String?
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var iCloudAccountStatusText = "尚未检查"
    @Published private(set) var cloudKitEventText = "尚未收到同步事件"
    @Published private(set) var lastSyncMarkerTitle: String?
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
        syncStoreURL: URL = KiteIOSCoreDataStoreFactory.storeURL()
    ) {
        self.selectedDate = HabitDate.startOfDay(selectedDate)
        self.syncStore = syncStore
        self.syncMode = syncMode
        self.syncStoreURL = syncStoreURL
        self.snapshot = HabitDaySnapshot(dateKey: HabitDate.key(for: selectedDate), habits: [])
        if syncMode == .cloudKit {
            let monitor = HabitCloudKitSyncMonitor { [weak self] summary in
                self?.cloudKitEventText = summary.text
                if summary.shouldReloadLocalData {
                    self?.loadSnapshot()
                }
            }
            monitor.start()
            self.cloudKitSyncMonitor = monitor
        }
        loadSnapshot()
    }

    var dateTitle: String {
        HabitDate.monthDayWeekLabel(selectedDate)
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

    #if DEBUG
    var nextLaunchSyncModeText: String {
        (HabitSyncStoreMode.debugPreference ?? .local).title
    }

    func setNextLaunchSyncMode(_ mode: HabitSyncStoreMode) {
        HabitSyncStoreMode.debugPreference = mode
        objectWillChange.send()
    }
    #endif

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

    func reload() {
        loadSnapshot()
    }

    func refreshICloudAccountStatus() {
        iCloudAccountStatusText = "检查中..."
        Task {
            do {
                let status = try await CKContainer(identifier: HabitCoreDataStack.cloudKitContainerIdentifier)
                    .accountStatus()
                iCloudAccountStatusText = Self.describeICloudAccountStatus(status)
            } catch {
                iCloudAccountStatusText = "检查失败：\(error.localizedDescription)"
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
        performWrite("改名失败") {
            try syncStore.renameHabitForDay(habitID: habit.id, title: trimmed, on: selectedDate)
        }
    }

    func renameFromToday(_ habit: HabitDaySnapshotItem, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
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

    func setRepeatRule(_ rule: HabitRepeatRule, for habit: HabitDaySnapshotItem) {
        performWrite("重复规则保存失败") {
            try syncStore.updateRepeatRule(habitID: habit.id, rule: rule)
        }
    }

    func setCustomRepeatWeekdays(_ weekdays: [Int], for habit: HabitDaySnapshotItem) {
        let normalized = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
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
        performWrite("默认习惯添加失败") {
            _ = try syncStore.replaceAll(with: .default)
        }
    }

    func insertSyncMarker() {
        let dateKey = HabitDate.key(for: selectedDate)
        let timeText = Self.syncMarkerTimeFormatter.string(from: .now)
        let title = "iOS同步标记-\(dateKey)-\(timeText)"
        do {
            try syncStore.addHabit(title: title, startDate: selectedDate, todayOnly: false)
            lastSyncMarkerTitle = title
            loadSnapshot()
        } catch {
            loadMessage = "同步标记写入失败"
        }
    }

    private func loadSnapshot() {
        do {
            snapshot = try syncStore.daySnapshot(for: selectedDate)
            loadMessage = nil
            lastRefreshDate = .now
        } catch {
            snapshot = HabitDaySnapshot(dateKey: HabitDate.key(for: selectedDate), habits: [])
            loadMessage = "暂时无法读取同步数据"
        }
    }

    private func performWrite(_ failureMessage: String, operation: () throws -> Void) {
        do {
            try operation()
            loadSnapshot()
        } catch {
            loadMessage = failureMessage
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
}
