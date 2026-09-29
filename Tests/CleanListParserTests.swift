import Foundation

func testByteStringParsing() {
    assert(CleanListParser.parseByteString("1 TB") == 1024 * 1024 * 1024 * 1024)
    assert(CleanListParser.parseByteString("2 T") == 2 * 1024 * 1024 * 1024 * 1024)
    assert(CleanListParser.parseByteString("1.5 TB") == UInt64((1.5 * 1024 * 1024 * 1024 * 1024).rounded()))
    assert(CleanListParser.parseByteString("12.4 GB") == UInt64((12.4 * 1024 * 1024 * 1024).rounded()))
    assert(CleanListParser.parseByteString("5 G") == 5 * 1024 * 1024 * 1024)
    assert(CleanListParser.parseByteString("512 MB") == 512 * 1024 * 1024)
    assert(CleanListParser.parseByteString("256 M") == 256 * 1024 * 1024)
    assert(CleanListParser.parseByteString("1024 KB") == 1024 * 1024)
    assert(CleanListParser.parseByteString("128 K") == 128 * 1024)
    assert(CleanListParser.parseByteString("256 B") == 256)
    assert(CleanListParser.parseByteString("500 Bytes") == 500)
    assert(CleanListParser.parseByteString("  0 MB  ") == 0)
    assert(CleanListParser.parseByteString("invalid") == 0)
    assert(CleanListParser.parseByteString("999 UnknownUnit") == 0)
    print("✓ testByteStringParsing passed")
}

func testCleanListManifestParsingWithFixture() {
    let fixture = """
    # Mole Clean List Preview
    # Generated on 2026-09-29

    === Developer tools and environments ===
    /Users/test/Library/Developer/Xcode/DerivedData # 12.4 GB
    /Users/test/.npm/_cacache # 512 MB
    /Users/test/.cargo/registry/cache # 1.2 GB
    /Users/test/.cargo/registry/src, counted under /Users/test/.cargo

    === Application caches and temporary files ===
    /Users/test/Library/Caches/Google/Chrome # 3.5 GB
    /Users/test/Library/Caches/com.apple.Safari # 450 MB
    /Users/test/Library/Logs/DiagnosticReports # 15.2 MB
    /Users/test/Library/Logs/testapp.log # 2.1 MB
    /var/log/system.log.gz # 500 KB

    === Empty section ===
    """

    let parser = CleanListParser()
    let parsed = parser.parse(content: fixture)

    let devItems = parsed[.dev] ?? []
    let cacheItems = parsed[.appCaches] ?? []
    let logItems = parsed[.logs] ?? []

    // Dev items: DerivedData, npm, cargo (sub-counted item ignored)
    assert(devItems.count == 3, "Dev items count should be 3, got \(devItems.count)")
    assert(devItems[0].name == "DerivedData")
    assert(devItems[0].sizeBytes == UInt64((12.4 * 1024 * 1024 * 1024).rounded()))
    assert(devItems[0].details == "Developer tools and environments")

    // Cache items: Chrome, Safari
    assert(cacheItems.count == 2, "Cache items count should be 2, got \(cacheItems.count)")
    assert(cacheItems.contains { $0.name == "Chrome" })
    assert(cacheItems.contains { $0.name == "com.apple.Safari" })

    // Log items: DiagnosticReports, testapp.log, system.log.gz
    assert(logItems.count == 3, "Log items count should be 3, got \(logItems.count)")
    assert(logItems.contains { $0.name == "DiagnosticReports" })
    assert(logItems.contains { $0.name == "testapp.log" })
    assert(logItems.contains { $0.name == "system.log.gz" })

    print("✓ testCleanListManifestParsingWithFixture passed")
}

func testPathWithHashDelimiterAndSectionPriority() {
    let fixture = """
    === Developer tools ===
    /Users/test/workspace/c # sharp/DerivedData # 500 MB
    /Users/test/workspace/project/build.log # 50 MB

    === System logs and crash dumps ===
    /Users/test/Library/Logs/DiagnosticReports # 10 MB
    """

    let parser = CleanListParser()
    let parsed = parser.parse(content: fixture)

    let devItems = parsed[.dev] ?? []
    assert(devItems.count == 2, "Both items should be under dev, including build.log in Developer section")
    assert(devItems[0].path == "/Users/test/workspace/c # sharp/DerivedData")
    assert(devItems[0].sizeBytes == 500 * 1024 * 1024)
    assert(devItems[1].path == "/Users/test/workspace/project/build.log")

    let categories = parser.parseCategories(content: fixture)
    assert(categories.count == 3)
    let devCategory = categories.first { $0.type == .dev }
    assert(devCategory != nil)
    assert(devCategory?.items.count == 2)
    assert(devCategory?.sizeBytes == 550 * 1024 * 1024)
    print("✓ testPathWithHashDelimiterAndSectionPriority passed")
}

func runCleanListParserTests() {
    testByteStringParsing()
    testCleanListManifestParsingWithFixture()
    testPathWithHashDelimiterAndSectionPriority()
    print("All CleanListParser tests passed.")
}
