import XCTest

final class HabitCoreDataSharedStoreTests: XCTestCase {
    private let selectedDate = Date(timeIntervalSince1970: 1_710_720_000)

    func testSeparateStoreInstancesShareCoreDataState() throws {
        let harness = try makeHarness()
        defer { harness.cleanup() }

        let macStore = HabitCoreDataStore(storeURL: harness.storeURL)
        let iosLikeStore = HabitCoreDataStore(storeURL: harness.storeURL)

        let firstID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!

        try macStore.addHabit(title: "Mac Seed", startDate: selectedDate, todayOnly: false, id: firstID)
        XCTAssertEqual(try iosLikeStore.daySnapshot(for: selectedDate).habits.map(\.title), ["Mac Seed"])

        try iosLikeStore.toggleDone(habitID: firstID, on: selectedDate)
        XCTAssertEqual(try macStore.daySnapshot(for: selectedDate).doneCount, 1)

        try iosLikeStore.renameHabitForDay(habitID: firstID, title: "iOS Today", on: selectedDate)
        XCTAssertEqual(try macStore.daySnapshot(for: selectedDate).habits.first?.title, "iOS Today")

        try macStore.addHabit(title: "Mac Second", startDate: selectedDate, todayOnly: false, id: secondID)
        XCTAssertEqual(try iosLikeStore.daySnapshot(for: selectedDate).habits.map(\.id), [firstID, secondID])

        try iosLikeStore.reorderHabits(orderedIDs: [secondID, firstID])
        XCTAssertEqual(try macStore.daySnapshot(for: selectedDate).habits.map(\.id), [secondID, firstID])

        try macStore.deleteHabit(habitID: secondID)
        XCTAssertEqual(try iosLikeStore.daySnapshot(for: selectedDate).habits.map(\.id), [firstID])
    }

    private func makeHarness() throws -> CoreDataHarness {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HabitCoreDataSharedStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return CoreDataHarness(
            storeURL: directory.appendingPathComponent("store.sqlite"),
            directory: directory
        )
    }
}

private struct CoreDataHarness {
    let storeURL: URL
    let directory: URL

    func cleanup() {
        try? HabitCoreDataStore(storeURL: storeURL).clearStoreFile()
        try? FileManager.default.removeItem(at: directory)
    }
}
