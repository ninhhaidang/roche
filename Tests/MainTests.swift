import Foundation

@main
struct AllTestsRunner {
    static func main() async {
        do {
            print("--- Running SubprocessRunner Tests ---")
            try await runSubprocessRunnerTests()

            print("\n--- Running CleanEngine Tests ---")
            try await runCleanEngineTests()

            print("\n--- Running CleanListParser Tests ---")
            runCleanListParserTests()

            print("\n--- Running CleanEngine Selection Tests ---")
            try await runCleanEngineSelectionTests()

            print("\n===============================")
            print("ALL SUITES PASSED SUCCESSFULLY!")
            print("===============================")
        } catch {
            print("\nTest failed with error: \(error)")
            exit(1)
        }
    }
}
