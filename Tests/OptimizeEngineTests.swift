import Foundation

func runOptimizeEngineTests() async throws {
    testBottleneckParsingWindowServer()
    testBottleneckParsingSyspolicydSevere()
    testNoBottleneckDetected()
    testBottleneckWithANSIEscapeSequences()
    testCategoryMappingFor20Tasks()
    testCanonical20TasksDistribution()
    try await testMockEngineScenarios()
    try testModelCodableAndEquatable()
    testRealDryRunOutputParsing()

    print("All OptimizeEngine tests passed.")
}

// MARK: - 1. Bottleneck Parsing Tests

func testBottleneckParsingWindowServer() {
    let input = "Likely bottleneck: WindowServer (~31.2% CPU sustained)"
    let diagnosis = RealOptimizeEngine.parseDiagnosis(from: input)

    assert(diagnosis.hasBottleneck, "Diagnosis should detect bottleneck")
    assert(diagnosis.component == "WindowServer", "Component should be WindowServer, got: \(diagnosis.component)")
    assert(diagnosis.cpuUsagePercent == 31.2, "CPU percent should be 31.2, got: \(String(describing: diagnosis.cpuUsagePercent))")
    assert(diagnosis.severity == .moderate, "Severity should be moderate for 31.2%, got: \(diagnosis.severity)")
    assert(diagnosis.description.contains("WindowServer"), "Description should reference WindowServer")
    assert(!diagnosis.recommendation.isEmpty, "Recommendation should not be empty")
    print("✓ testBottleneckParsingWindowServer passed")
}

func testBottleneckParsingSyspolicydSevere() {
    let input = """
    Performance diagnosis
      ◎ Likely bottleneck: syspolicyd (~68.5% CPU sustained)
      ⊙ Gatekeeper and code-signature assessment activity is elevated.
    """
    let diagnosis = RealOptimizeEngine.parseDiagnosis(from: input)

    assert(diagnosis.hasBottleneck, "Diagnosis should detect bottleneck")
    assert(diagnosis.component == "syspolicyd", "Component should be syspolicyd")
    assert(diagnosis.cpuUsagePercent == 68.5, "CPU percent should be 68.5")
    assert(diagnosis.severity == .severe, "Severity should be severe for 68.5%")
    print("✓ testBottleneckParsingSyspolicydSevere passed")
}

func testNoBottleneckDetected() {
    let input = """
    Performance diagnosis
      ✔ No sustained high-CPU bottleneck detected
    """
    let diagnosis = RealOptimizeEngine.parseDiagnosis(from: input)

    assert(!diagnosis.hasBottleneck, "Should report no bottleneck")
    assert(diagnosis.severity == .nominal, "Severity should be nominal")
    assert(diagnosis.cpuUsagePercent == nil, "CPU percent should be nil")
    assert(diagnosis.component == "Không có nghẽn", "Component should be Không có nghẽn")
    print("✓ testNoBottleneckDetected passed")
}

func testBottleneckWithANSIEscapeSequences() {
    let input = "\u{001B}[33m◎\u{001B}[0m Likely bottleneck: WindowServer (~38.9% CPU sustained)"
    let diagnosis = RealOptimizeEngine.parseDiagnosis(from: input)

    assert(diagnosis.hasBottleneck, "Should strip ANSI and detect bottleneck")
    assert(diagnosis.component == "WindowServer", "Component should be WindowServer")
    assert(diagnosis.cpuUsagePercent == 38.9, "CPU percent should be 38.9")
    print("✓ testBottleneckWithANSIEscapeSequences passed")
}

// MARK: - 2. Category Mapping Tests

func testCategoryMappingFor20Tasks() {
    let expectedMappings: [(String, OptimizeTaskCategory)] = [
        // Category 1: Hệ thống & Tìm kiếm
        ("system_maintenance", .systemAndSearch),
        ("DNS & Spotlight Check", .systemAndSearch),
        ("spotlight_index_optimize", .systemAndSearch),
        ("Spotlight Optimization", .systemAndSearch),
        ("spotlight_orphan_rules_cleanup", .systemAndSearch),
        ("Spotlight Orphan Rules", .systemAndSearch),
        ("periodic_maintenance", .systemAndSearch),
        ("Periodic Maintenance", .systemAndSearch),
        ("disk_permissions_repair", .systemAndSearch),
        ("Permission Repair", .systemAndSearch),

        // Category 2: Bộ nhớ đệm & Finder
        ("cache_refresh", .cacheAndFinder),
        ("Finder Cache Refresh", .cacheAndFinder),
        ("saved_state_cleanup", .cacheAndFinder),
        ("App State Cleanup", .cacheAndFinder),
        ("prevent_network_dsstore", .cacheAndFinder),
        ("Prevent Finder .DS_Store", .cacheAndFinder),
        ("shared_file_list_repair", .cacheAndFinder),
        ("Shared File Lists", .cacheAndFinder),
        ("notification_cleanup", .cacheAndFinder),
        ("Notifications", .cacheAndFinder),

        // Category 3: Mạng & Dữ liệu
        ("network_optimization", .networkAndData),
        ("Network Cache Refresh", .networkAndData),
        ("network_stack_optimize", .networkAndData),
        ("Network Stack Refresh", .networkAndData),
        ("sqlite_vacuum", .networkAndData),
        ("Database Optimization", .networkAndData),
        ("disk_verify", .networkAndData),
        ("Disk Health", .networkAndData),
        ("coreduet_cleanup", .networkAndData),
        ("Usage Data", .networkAndData),

        // Category 4: Cấu hình & Bảo mật
        ("fix_broken_configs", .configAndSecurity),
        ("Broken Config Repair", .configAndSecurity),
        ("legacy_overrides_audit", .configAndSecurity),
        ("Legacy Overrides", .configAndSecurity),
        ("login_items_audit", .configAndSecurity),
        ("Login Items", .configAndSecurity),
        ("quarantine_cleanup", .configAndSecurity),
        ("Quarantine Database Cleanup", .configAndSecurity),
        ("launch_agents_cleanup", .configAndSecurity),
        ("Launch Agents Cleanup", .configAndSecurity)
    ]

    for (actionOrName, expectedCat) in expectedMappings {
        let mapped = RealOptimizeEngine.category(forActionOrName: actionOrName)
        assert(mapped == expectedCat, "Task '\(actionOrName)' expected category \(expectedCat), but got \(mapped)")
    }
    print("✓ testCategoryMappingFor20Tasks passed")
}

func testCanonical20TasksDistribution() {
    let tasks = RealOptimizeEngine.canonicalTasks20()
    assert(tasks.count == 20, "Must have exactly 20 canonical tasks, found \(tasks.count)")

    let cat1 = tasks.filter { $0.category == .systemAndSearch }
    let cat2 = tasks.filter { $0.category == .cacheAndFinder }
    let cat3 = tasks.filter { $0.category == .networkAndData }
    let cat4 = tasks.filter { $0.category == .configAndSecurity }

    assert(cat1.count == 5, "Hệ thống & Tìm kiếm must have 5 tasks, found \(cat1.count)")
    assert(cat2.count == 5, "Bộ nhớ đệm & Finder must have 5 tasks, found \(cat2.count)")
    assert(cat3.count == 5, "Mạng & Dữ liệu must have 5 tasks, found \(cat3.count)")
    assert(cat4.count == 5, "Cấu hình & Bảo mật must have 5 tasks, found \(cat4.count)")

    print("✓ testCanonical20TasksDistribution passed (5 tasks in each of the 4 categories)")
}

// MARK: - 3. Mock Engine Tests

func testMockEngineScenarios() async throws {
    let mock = MockOptimizeEngine()

    // Default: WindowServer bottleneck
    let diagDefault = try await mock.diagnosePerformance()
    assert(diagDefault.hasBottleneck, "Default mock should detect bottleneck")
    assert(diagDefault.component == "WindowServer", "Default mock should be WindowServer")
    assert(diagDefault.tasks.count == 20, "Mock diagnosis must contain 20 tasks")

    // Syspolicyd scenario
    mock.scenario = .syspolicydBottleneck
    let diagSys = try await mock.diagnosePerformance()
    assert(diagSys.severity == .severe, "Syspolicyd mock should have severe severity")

    // Nominal scenario
    mock.scenario = .nominalHealthy
    let diagNom = try await mock.diagnosePerformance()
    assert(!diagNom.hasBottleneck, "Nominal mock should not have bottleneck")
    assert(diagNom.severity == .nominal, "Nominal mock should have nominal severity")

    // Grouping by category
    let grouped = MockOptimizeEngine.mockTasksByCategory()
    assert(grouped.keys.count == 4, "Must group into 4 categories")
    for (cat, tasks) in grouped {
        assert(tasks.count == 5, "Category \(cat.title) must contain 5 tasks")
    }

    print("✓ testMockEngineScenarios passed")
}

// MARK: - 4. Codable & Equatable Tests

func testModelCodableAndEquatable() throws {
    let diagnosis = MockOptimizeEngine.mockDiagnosis(scenario: .windowServerBottleneck)
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let data = try encoder.encode(diagnosis)
    let decoded = try decoder.decode(SystemDiagnosis.self, from: data)

    assert(decoded == diagnosis, "Decoded diagnosis must equal original diagnosis")
    assert(decoded.tasks.count == 20, "Decoded diagnosis must retain all 20 tasks")
    assert(decoded.severity == .moderate, "Decoded diagnosis severity must match")

    // Test OptimizeTaskCategory Codable
    for cat in OptimizeTaskCategory.allCases {
        let catData = try encoder.encode(cat)
        let decCat = try decoder.decode(OptimizeTaskCategory.self, from: catData)
        assert(decCat == cat, "Category \(cat) roundtrip failed")
    }

    // Test OptimizeTaskOutcome Codable
    for outcome in OptimizeTaskOutcome.allCases {
        let outData = try encoder.encode(outcome)
        let decOut = try decoder.decode(OptimizeTaskOutcome.self, from: outData)
        assert(decOut == outcome, "Outcome \(outcome) roundtrip failed")
    }

    // Test OptimizeTaskStatus Codable
    for status in OptimizeTaskStatus.allCases {
        let stData = try encoder.encode(status)
        let decSt = try decoder.decode(OptimizeTaskStatus.self, from: stData)
        assert(decSt == status, "Status \(status) roundtrip failed")
    }

    print("✓ testModelCodableAndEquatable passed")
}

// MARK: - 5. Real Dry-Run Output Parsing

func testRealDryRunOutputParsing() {
    let sampleMoleOutput = """
    Optimize
    → DRY RUN MODE, No files will be modified

    Performance diagnosis
      ◎ Likely bottleneck: WindowServer (~38.9% CPU sustained)
      ⊙ Desktop composition is busy. When another family is higher, treat this as a likely symptom rather than the root cause.

    ➤ DNS & Spotlight Check
      → DNS cache flushed
      → Spotlight index verified

    ➤ Finder Cache Refresh
      → QuickLook thumbnails refreshed
      → Icon services cache rebuilt

    ➤ Login Items
      ◎ Broken login item: DeadApp (app not found)

    ======================================================================
    Dry Run Complete, No Changes Made
    Would apply 3 optimizations
    14 unchanged | 1 skipped | 1 unavailable | 1 need attention
    ======================================================================
    """

    let diagnosis = RealOptimizeEngine.parseDiagnosis(from: sampleMoleOutput)
    assert(diagnosis.hasBottleneck, "Dry run output should detect bottleneck")
    assert(diagnosis.component == "WindowServer", "Component should be WindowServer")
    assert(diagnosis.cpuUsagePercent == 38.9, "CPU percentage should be 38.9")
    assert(diagnosis.tasks.count == 20, "Must maintain full 20 canonical tasks")

    // Check parsed tasks outcomes
    let dnsTask = diagnosis.tasks.first { $0.id == "system_maintenance" }
    assert(dnsTask?.outcome == .applied, "DNS task should be applied")

    let loginTask = diagnosis.tasks.first { $0.id == "login_items_audit" }
    assert(loginTask?.outcome == .attention, "Login items task should be attention, got: \(String(describing: loginTask?.outcome))")

    print("✓ testRealDryRunOutputParsing passed")
}
