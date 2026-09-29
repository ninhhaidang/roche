import Foundation

@MainActor
func testToggleCategoryUpdatesAtomicallyAndRecalculatesBytes() async throws {
    let mockClient = MockTestMoleClient()
    let result = CleanScanResult(
        categories: [
            CleanCategory(kind: .dev, sizeBytes: 1000, itemCount: 2, items: [], isSelected: true),
            CleanCategory(kind: .logs, sizeBytes: 500, itemCount: 1, items: [], isSelected: true),
            CleanCategory(kind: .appCaches, sizeBytes: 0, itemCount: 0, items: [], isSelected: false)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = result

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    assert(engine.selectedCategories.contains(.dev))
    assert(engine.selectedCategories.contains(.logs))
    assert(engine.selectedTotalBytes == 1500)
    assert(engine.canCleanSelected == true)

    // Toggle off .dev
    engine.toggleCategory(.dev)
    assert(!engine.selectedCategories.contains(.dev))
    assert(engine.selectedCategories.contains(.logs))
    assert(engine.selectedTotalBytes == 500)
    assert(engine.canCleanSelected == true)

    // Toggle on .dev
    engine.toggleCategory(.dev)
    assert(engine.selectedCategories.contains(.dev))
    assert(engine.selectedCategories.contains(.logs))
    assert(engine.selectedTotalBytes == 1500)

    print("✓ testToggleCategoryUpdatesAtomicallyAndRecalculatesBytes passed")
}

@MainActor
func testSelectAllSelectsOnlyNonEmptyCategoriesAndDeselectAllClears() async throws {
    let mockClient = MockTestMoleClient()
    let result = CleanScanResult(
        categories: [
            CleanCategory(kind: .dev, sizeBytes: 1000, itemCount: 1, items: [], isSelected: true),
            CleanCategory(kind: .appCaches, sizeBytes: 0, itemCount: 0, items: [], isSelected: false),
            CleanCategory(kind: .logs, sizeBytes: 500, itemCount: 1, items: [], isSelected: true),
            CleanCategory(kind: .trash, sizeBytes: 0, itemCount: 0, items: [], isSelected: false)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = result

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    // Deselect all
    engine.deselectAll()
    assert(engine.selectedCategories.isEmpty, "deselectAll must clear all selections")
    assert(engine.selectedTotalBytes == 0, "selectedTotalBytes must be 0 after deselectAll")
    assert(engine.canCleanSelected == false, "canCleanSelected must be false when no categories are selected")

    // Select all - should ONLY select non-empty categories (.dev and .logs)
    engine.selectAll()
    assert(engine.selectedCategories.count == 2, "selectAll should only select 2 non-empty categories, got \(engine.selectedCategories.count)")
    assert(engine.selectedCategories.contains(.dev))
    assert(engine.selectedCategories.contains(.logs))
    assert(!engine.selectedCategories.contains(.appCaches), "Empty appCaches should not be selected")
    assert(!engine.selectedCategories.contains(.trash), "Empty trash should not be selected")
    assert(engine.selectedTotalBytes == 1500)
    assert(engine.canCleanSelected == true)

    print("✓ testSelectAllSelectsOnlyNonEmptyCategoriesAndDeselectAllClears passed")
}

@MainActor
func testCleanActionDisabledWhenNoSelection() async throws {
    let mockClient = MockTestMoleClient()
    let result = CleanScanResult(
        categories: [
            CleanCategory(kind: .dev, sizeBytes: 1000, itemCount: 1, items: [], isSelected: true)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = result

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    engine.deselectAll()
    assert(engine.canCleanSelected == false)

    // Attempting clean when no categories are selected must be ignored safely
    await engine.cleanSelected()
    assert(engine.state != .cleaning(selectedCategories: []))
    guard case .ready = engine.state else {
        assertionFailure("State should remain .ready")
        return
    }

    print("✓ testCleanActionDisabledWhenNoSelection passed")
}

@MainActor
func testSelectedCategoriesSummaryFormatting() async throws {
    let mockClient = MockTestMoleClient()
    let result = CleanScanResult(
        categories: [
            CleanCategory(kind: .dev, sizeBytes: 1000, itemCount: 1, items: [], isSelected: true),
            CleanCategory(kind: .logs, sizeBytes: 500, itemCount: 1, items: [], isSelected: true)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = result

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    let summary = engine.selectedCategoriesSummary
    assert(!summary.isEmpty)
    assert(summary.contains(CleanCategoryKind.dev.title))
    assert(summary.contains(CleanCategoryKind.logs.title))

    print("✓ testSelectedCategoriesSummaryFormatting passed")
}

@MainActor
func testCleanActionEnabledWhenZeroBytesWithItemsSelected() async throws {
    let mockClient = MockTestMoleClient()
    let result = CleanScanResult(
        categories: [
            CleanCategory(kind: .trash, sizeBytes: 0, itemCount: 5, items: [], isSelected: true)
        ],
        scannedAt: Date()
    )
    mockClient.resultToReturn = result

    let engine = CleanEngine(client: mockClient)
    await engine.scan()

    assert(engine.selectedCategories.contains(.trash))
    assert(engine.canCleanSelected == true, "canCleanSelected should be true when category with items is selected even if 0 bytes")
    print("✓ testCleanActionEnabledWhenZeroBytesWithItemsSelected passed")
}

func runCleanEngineSelectionTests() async throws {
    try await testToggleCategoryUpdatesAtomicallyAndRecalculatesBytes()
    try await testSelectAllSelectsOnlyNonEmptyCategoriesAndDeselectAllClears()
    try await testCleanActionDisabledWhenNoSelection()
    try await testCleanActionEnabledWhenZeroBytesWithItemsSelected()
    try await testSelectedCategoriesSummaryFormatting()
    print("All CleanEngineSelection tests passed.")
}
