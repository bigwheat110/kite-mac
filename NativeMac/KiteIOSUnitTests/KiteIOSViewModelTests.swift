import XCTest

@MainActor
final class KiteIOSViewModelTests: XCTestCase {
    private let selectedDate = Date(timeIntervalSince1970: 1_710_720_000)

    func testBasicHabitFlowUsesInjectedCoreDataStore() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let viewModel = KiteIOSViewModel(
            selectedDate: selectedDate,
            syncStore: harness.store,
            syncMode: .local,
            syncStoreURL: harness.storeURL,
            seedsDefaultHabits: false
        )

        XCTAssertEqual(viewModel.snapshot.habits.count, 0)

        viewModel.draftTitle = "Read"
        viewModel.addHabit()

        var habit = try XCTUnwrap(viewModel.snapshot.habits.first)
        XCTAssertEqual(habit.title, "Read")
        XCTAssertFalse(habit.isDone)
        XCTAssertEqual(viewModel.weekItems.first { $0.isSelected }?.totalCount, 1)

        viewModel.toggle(habit)
        habit = try XCTUnwrap(viewModel.snapshot.habits.first)
        XCTAssertTrue(habit.isDone)
        XCTAssertEqual(viewModel.weekItems.first { $0.isSelected }?.doneCount, 1)

        viewModel.renameToday(habit, title: "Read Today")
        habit = try XCTUnwrap(viewModel.snapshot.habits.first)
        XCTAssertEqual(habit.title, "Read Today")

        viewModel.setCustomRepeatWeekdays([3, 2, 3], for: habit)
        habit = try XCTUnwrap(viewModel.snapshot.habits.first)
        XCTAssertEqual(habit.repeatRule, .custom([2, 3]))

        viewModel.draftTitle = "One Day"
        viewModel.addTodayOnlyHabit()
        XCTAssertEqual(viewModel.snapshot.habits.map(\.title), ["Read Today", "One Day"])

        viewModel.hideToday(habit)
        XCTAssertEqual(viewModel.snapshot.habits.map(\.title), ["One Day"])
    }

    func testDeleteFromTodayStopsFutureAppearance() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let viewModel = KiteIOSViewModel(
            selectedDate: selectedDate,
            syncStore: harness.store,
            syncMode: .local,
            syncStoreURL: harness.storeURL,
            seedsDefaultHabits: false
        )

        viewModel.draftTitle = "Future"
        viewModel.addHabit()
        let habit = try XCTUnwrap(viewModel.snapshot.habits.first)

        viewModel.deleteFromToday(habit)
        XCTAssertTrue(viewModel.snapshot.habits.isEmpty)

        viewModel.shiftDay(by: 1)
        XCTAssertTrue(viewModel.snapshot.habits.isEmpty)
    }

    func testEmptyLocalStoreSeedsDefaultHabits() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let viewModel = KiteIOSViewModel(
            selectedDate: selectedDate,
            syncStore: harness.store,
            syncMode: .local,
            syncStoreURL: harness.storeURL
        )

        XCTAssertEqual(viewModel.snapshot.habits.count, AppState.default.habits.count)
        XCTAssertEqual(viewModel.snapshot.habits.first?.title, AppState.default.habits.first?.title)
    }

    private func makeHarness() throws -> CoreDataHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KiteIOSViewModelTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("store.sqlite")
        return CoreDataHarness(
            store: HabitCoreDataStore(storeURL: storeURL),
            storeURL: storeURL,
            directory: directory
        )
    }
}

private struct CoreDataHarness {
    let store: HabitCoreDataStore
    let storeURL: URL
    let directory: URL

    func cleanup() {
        try? store.clearStoreFile()
        try? FileManager.default.removeItem(at: directory)
    }
}
